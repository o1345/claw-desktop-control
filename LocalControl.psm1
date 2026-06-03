# LocalControl.psm1 - 本机桌面控制 PowerShell 模块
# 直接调用 Win32 API, 无 SSH 层, 适用于同 Session 1+ 交互会话
# 用法: Import-Module "$PSScriptRoot\LocalControl.psm1" -Force

$script:NativeSrc = Join-Path (Split-Path -Parent $PSCommandPath) 'LCNative.cs'
if (-not $script:NativeSrc -or -not (Test-Path -LiteralPath $script:NativeSrc)) {
    $script:NativeSrc = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'LCNative.cs'
}
if (-not ('LC' -as [type])) {
    Add-Type -TypeDefinition (Get-Content -Raw -LiteralPath $script:NativeSrc) -Language CSharp -ReferencedAssemblies 'System.Drawing','System.Windows.Forms'
}
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Drawing    -ErrorAction SilentlyContinue

function Get-CursorPosition {
    [CmdletBinding()]
    param()
    $p = [LC]::GetPos()
    [pscustomobject]@{ X = $p.X; Y = $p.Y }
}

function Set-MousePosition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y
    )
    [LC]::SetCursorPos($X, $Y) | Out-Null
}

function Send-MouseClick {
    [CmdletBinding()]
    param(
        [ValidateSet('left','right','middle')][string]$Button = 'left',
        [int]$X,
        [int]$Y,
        [int]$HoldMs = 30
    )
    if ($PSBoundParameters.ContainsKey('X') -and $PSBoundParameters.ContainsKey('Y')) {
        [LC]::SetCursorPos($X, $Y) | Out-Null
        Start-Sleep -Milliseconds 20
    }
    $down, $up = switch ($Button) {
        'left'   { [LC]::MOUSEEVENTF_LEFTDOWN,   [LC]::MOUSEEVENTF_LEFTUP }
        'right'  { [LC]::MOUSEEVENTF_RIGHTDOWN,  [LC]::MOUSEEVENTF_RIGHTUP }
        'middle' { [LC]::MOUSEEVENTF_MIDDLEDOWN, [LC]::MOUSEEVENTF_MIDDLEUP }
    }
    [LC]::mouse_event($down, 0, 0, 0, 0)
    if ($HoldMs -gt 0) { Start-Sleep -Milliseconds $HoldMs }
    [LC]::mouse_event($up,   0, 0, 0, 0)
}

function Send-MouseDoubleClick {
    [CmdletBinding()]
    param(
        [ValidateSet('left','right','middle')][string]$Button = 'left',
        [int]$X,
        [int]$Y,
        [int]$GapMs = 80
    )
    Send-MouseClick -Button $Button -X $X -Y $Y
    Start-Sleep -Milliseconds $GapMs
    Send-MouseClick -Button $Button -X $X -Y $Y
}

function Send-MouseWheel {
    [CmdletBinding()]
    param([int]$Delta = -120)
    [LC]::mouse_event([LC]::MOUSEEVENTF_WHEEL, 0, 0, $Delta, 0)
}

function Send-Key {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Keys)
    [System.Windows.Forms.SendKeys]::SendWait($Keys)
}

function Send-Text {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)
    Add-Type -AssemblyName System.Windows.Forms
    $escaped = $Text.Replace('{','{{}').Replace('}','{}}')
    [System.Windows.Forms.SendKeys]::SendWait($escaped)
}

function Send-KeyCombo {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Keys)
    $combo = ($Keys | ForEach-Object { "{$_}" }) -join ''
    [System.Windows.Forms.SendKeys]::SendWait($combo)
}

function Send-Hotkey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Modifier,
        [Parameter(Mandatory)][string]$Key
    )
    $modChar = switch ($Modifier.ToLower()) {
        'ctrl'  { '^' }
        'alt'   { '%' }
        'shift' { '+' }
        'win'   { '^{ESC}'; break }
    }
    if ($Modifier.ToLower() -eq 'win') {
        [System.Windows.Forms.SendKeys]::SendWait($modChar)
        return
    }
    [System.Windows.Forms.SendKeys]::SendWait("$modChar{$Key}")
}

function Get-Screenshot {
    [CmdletBinding()]
    param(
        [string]$OutputPath = (Join-Path (Get-Location).Path 'screenshot.png'),
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 0,
        [int]$Height = 0
    )
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    if ($Width  -le 0) { $Width  = $screen.Width  - $X }
    if ($Height -le 0) { $Height = $screen.Height - $Y }
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($X, $Y, 0, 0, (New-Object System.Drawing.Size $Width, $Height))
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Get-Item -LiteralPath $OutputPath
}

function Get-AllScreens {
    [System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
        [pscustomobject]@{
            DeviceName = $_.DeviceName
            Primary    = $_.Primary
            Bounds     = $_.Bounds
        }
    }
}

function Find-WindowByTitle {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Title, [switch]$Regex)
    $results = @()
    $signature = @'
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
[DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
'@
    if (-not ('WinEnum' -as [type])) {
        Add-Type -Name WinEnum -Namespace LC -MemberDefinition $signature
    }
    $found = New-Object 'System.Collections.Generic.List[object]'
    $callback = {
        param([IntPtr]$hWnd, [IntPtr]$lParam)
        if ([LC.WinEnum]::IsWindowVisible($hWnd)) {
            $len = [LC.WinEnum]::GetWindowTextLength($hWnd)
            if ($len -gt 0) {
                $sb = New-Object System.Text.StringBuilder ($len + 1)
                [LC.WinEnum]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
                $title = $sb.ToString()
                $match = if ($Regex) { $title -match $Title } else { $title -like "*$Title*" }
                if ($match) {
                    $rect = New-Object LC+RECT
                    [LC]::GetWindowRect($hWnd, [ref]$rect) | Out-Null
                    $pid = 0
                    [LC]::GetWindowThreadProcessId($hWnd, [ref]$pid) | Out-Null
                    $found.Add([pscustomobject]@{
                        Handle  = $hWnd
                        Title   = $title
                        PID     = $pid
                        X       = $rect.Left
                        Y       = $rect.Top
                        Width   = $rect.Right - $rect.Left
                        Height  = $rect.Bottom - $rect.Top
                    })
                }
            }
        }
        return $true
    }
    $del = [LC.WinEnum+EnumWindowsProc]$callback
    [LC.WinEnum]::EnumWindows($del, [IntPtr]::Zero) | Out-Null
    $found
}

function Set-WindowForeground {
    [CmdletBinding()]
    param([Parameter(Mandatory)][IntPtr]$Handle)
    [LC]::ShowWindow($Handle, [LC]::SW_RESTORE) | Out-Null
    [LC]::SetForegroundWindow($Handle) | Out-Null
}

function Move-Window {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][IntPtr]$Handle,
        [int]$X,
        [int]$Y,
        [int]$Width = 0,
        [int]$Height = 0,
        [switch]$TopMost
    )
    $flags = [LC]::SWP_NOZORDER
    if ($Width -le 0 -or $Height -le 0) { $flags = $flags -bor [LC]::SWP_NOSIZE }
    if ($TopMost) {
        [LC]::SetWindowPos($Handle, [LC]::HWND_TOPMOST, $X, $Y, $Width, $Height, $flags) | Out-Null
    } else {
        [LC]::MoveWindow($Handle, $X, $Y, $Width, $Height, $true) | Out-Null
    }
}

function Start-LocalProgram {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Arguments = '',
        [string]$WorkingDirectory = '',
        [switch]$Wait
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Path
    if ($Arguments) { $psi.Arguments = $Arguments }
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
    $psi.UseShellExecute = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    if ($Wait) { $p.WaitForExit() }
    $p
}

function Open-Url {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Url)
    Start-Process $Url
}

function New-DesktopShortcut {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$TargetPath,
        [string]$Arguments = '',
        [string]$Description = '',
        [string]$IconLocation = '',
        [string]$WorkingDirectory = '',
        [string]$Folder = 'Desktop'
    )
    $shell = New-Object -ComObject WScript.Shell
    $dir = if ($Folder -eq 'Desktop' -or $Folder -eq '') {
        $shell.SpecialFolders('Desktop')
    } else {
        $Folder
    }
    $shortcutPath = Join-Path $dir "$Name.lnk"
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $TargetPath
    if ($Arguments)        { $shortcut.Arguments        = $Arguments }
    if ($Description)      { $shortcut.Description      = $Description }
    if ($IconLocation)     { $shortcut.IconLocation     = $IconLocation }
    if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
    $shortcut.Save()
    Get-Item -LiteralPath $shortcutPath
}

function Test-Admin {
    [CmdletBinding()]
    param()
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
    $isAdmin = $principal.IsInRole($adminRole)
    $elevation = 'Unknown'
    try {
        $proc = Get-Process -Id $PID -ErrorAction Stop
        if ($proc.Handle -ne [IntPtr]::Zero) {
            $tok = [IntPtr]::Zero
            $type = [Type]::GetType('System.Diagnostics.ProcessTokenAccess, System.Diagnostics.Process')
            $open = $type.GetMethod('OpenProcessToken', [Type[]]@([IntPtr], [System.Diagnostics.TokenAccessLevels]))
            $tokInfoPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal([System.IntPtr]::Size)
            try {
                $open.Invoke($proc, @($proc.Handle, [System.Diagnostics.TokenAccessLevels]::Query))
                $elevation = 'Unknown'
            } finally {
                if ($tokInfoPtr -ne [IntPtr]::Zero) {
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($tokInfoPtr)
                }
            }
        }
    } catch {}
    try {
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        $val = (Get-ItemProperty -Path $key -Name 'EnableLUA' -ErrorAction Stop).EnableLUA
        $reportUac = "LUA=$val"
    } catch {
        $reportUac = "LUA=?"
    }
    [pscustomobject]@{
        IsAdmin           = $isAdmin
        User              = $id.Name
        BuiltInRoleCheck  = 'WindowsBuiltInRole.Administrator'
        Uac               = $reportUac
        Hint              = if ($isAdmin) {
            'Full control. Can drive elevated / cross-session tasks. (Re-launch opencode as Administrator if you need to control windows of other users or services.)'
        } else {
            'Standard user. Cannot write to HKLM / Program Files / protected paths, cannot start/stop services, cannot SendInput to elevated windows. To escalate, quit opencode and re-launch it from an elevated PowerShell or right-click -> Run as administrator.'
        }
    }
}

function Start-ScreenshotSession {
    [CmdletBinding()]
    param(
        [string]$BaseDir = (Get-Location).Path,
        [int]$MaxScreenshots = 10,
        [switch]$Force
    )
    $screenDir = Join-Path $BaseDir '_screenshots'
    $logFile   = Join-Path $screenDir '_log.md'

    if ($Force -and (Test-Path $screenDir)) {
        Get-ChildItem $screenDir -Filter '_step_*.png' | Remove-Item -Force
        if (Test-Path $logFile) { Remove-Item $logFile -Force }
    }
    if (-not (Test-Path $screenDir)) {
        New-Item -ItemType Directory -Path $screenDir -Force | Out-Null
    }

    $sessionId = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    if (-not (Test-Path $logFile)) {
        @"
# Screenshot Observations
_Session: $sessionId | Dir: $screenDir | Max: $($MaxScreenshots)_

"@ | Set-Content -Path $logFile -Encoding UTF8
    }

    [pscustomobject]@{
        SessionId     = $sessionId
        ScreenshotDir = $screenDir
        LogFile       = $logFile
        Max           = $MaxScreenshots
        ExistingSteps = @(Get-ChildItem $screenDir -Filter '_step_*.png').Count
    }
}

function Save-StepScreenshot {
    [CmdletBinding()]
    param(
        [string]$ScreenshotDir = (Join-Path (Get-Location).Path '_screenshots'),
        [int]$MaxScreenshots = 10,
        [int]$X = 0,
        [int]$Y = 0,
        [int]$Width = 0,
        [int]$Height = 0
    )
    if (-not (Test-Path $ScreenshotDir)) {
        New-Item -ItemType Directory -Path $ScreenshotDir -Force | Out-Null
    }

    $existing = @(Get-ChildItem $ScreenshotDir -Filter '_step_*.png' | Sort-Object Name)
    $next = 1
    if ($existing.Count -gt 0) {
        $lastNum = ($existing[-1].BaseName -replace '_step_','') -as [int]
        if ($lastNum -gt 0) { $next = $lastNum + 1 }
    }

    $name = '_step_{0:D3}.png' -f $next
    $path = Join-Path $ScreenshotDir $name
    Get-Screenshot -OutputPath $path -X $X -Y $Y -Width $Width -Height $Height | Out-Null

    $files = @(Get-ChildItem $ScreenshotDir -Filter '_step_*.png' | Sort-Object Name)
    while ($files.Count -gt $MaxScreenshots) {
        Remove-Item $files[0].FullName -Force
        $files = @(Get-ChildItem $ScreenshotDir -Filter '_step_*.png' | Sort-Object Name)
    }

    Get-Item -LiteralPath $path
}

function Add-StepObservation {
    [CmdletBinding()]
    param(
        [string]$LogPath = '',
        [string]$ScreenshotName = '',
        [string[]]$Observation
    )
    if (-not $LogPath) { $LogPath = Join-Path (Join-Path (Get-Location).Path '_screenshots') '_log.md' }
    $dir = Split-Path -Parent $LogPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $LogPath)) {
        @"
# Screenshot Observations
_Session: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') | Dir: $($dir)_

"@ | Set-Content -Path $LogPath -Encoding UTF8
    }

    $count = 0
    foreach ($line in (Get-Content -Path $LogPath -Encoding UTF8)) {
        if ($line -match '^## Step (\d+)') { $count = [int]$Matches[1] }
    }
    $step = $count + 1

    $timestamp = Get-Date -Format 'HH:mm:ss'
    $lines = @("`n## Step $step", "**File:** $ScreenshotName | **Time:** $timestamp")
    foreach ($o in $Observation) {
        $lines += $o.Trim()
    }
    Add-Content -Path $LogPath -Value $lines -Encoding UTF8
}

function Get-StepObservationLog {
    [CmdletBinding()]
    param(
        [string]$LogPath = '',
        [int]$Tail = 0
    )
    if (-not $LogPath) { $LogPath = Join-Path (Join-Path (Get-Location).Path '_screenshots') '_log.md' }
    if (-not (Test-Path $LogPath)) {
        Write-Warning "No observation log. Run Start-ScreenshotSession first."
        return
    }
    $content = Get-Content -LiteralPath $LogPath -Encoding UTF8
    if ($Tail -gt 0 -and $content.Count -gt $Tail) { $content[-$Tail..-1] } else { $content }
}

function Stop-ScreenshotSession {
    [CmdletBinding()]
    param(
        [string]$BaseDir = (Get-Location).Path,
        [switch]$KeepLog
    )
    $screenDir = Join-Path $BaseDir '_screenshots'
    if (-not (Test-Path $screenDir)) {
        Write-Warning "No screenshot session at $screenDir"
        return
    }
    if ($KeepLog) {
        Get-ChildItem $screenDir -Filter '_step_*.png' | Remove-Item -Force
    } else {
        Remove-Item -LiteralPath $screenDir -Recurse -Force
    }
}

function Test-ControlCapability {
    [CmdletBinding()]
    param()
    $report = [ordered]@{}
    $report['SessionId']   = (Get-Process -Id $PID).SessionId
    $report['User']        = [Environment]::UserName
    $report['IsInteractive'] = [Environment]::UserInteractive
    $report['IsAdmin']     = (Test-Admin).IsAdmin
    $report['ScreenCount'] = [System.Windows.Forms.Screen]::AllScreens.Count
    $report['ScreenBounds'] = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $report['Foreground']  = (Get-Process | Where-Object { $_.MainWindowTitle -ne '' } | Select-Object -First 3).MainWindowTitle -join ' | '

    $p = [LC]::GetPos()
    $report['CursorInitial'] = "($($p.X),$($p.Y))"

    [LC]::SetCursorPos(50, 50) | Out-Null
    Start-Sleep -Milliseconds 30
    $p2 = [LC]::GetPos()
    $report['CursorMoveTest'] = "50,50 -> actual ($($p2.X),$($p2.Y)) | ok=$($p2.X -eq 50 -and $p2.Y -eq 50)"

    try {
        $tmp = Join-Path $env:TEMP "lc_test_$([guid]::NewGuid()).png"
        Get-Screenshot -OutputPath $tmp -Width 32 -Height 32 | Out-Null
        $report['ScreenshotTest'] = "ok | size=$((Get-Item $tmp).Length) bytes"
        Remove-Item $tmp -Force
    } catch {
        $report['ScreenshotTest'] = "FAIL: $_"
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SendKeys]::SendWait('')
        $report['SendKeysLoad'] = 'ok'
    } catch {
        $report['SendKeysLoad'] = "FAIL: $_"
    }

    [pscustomobject]$report
}

Export-ModuleMember -Function @(
    'Get-CursorPosition','Set-MousePosition','Send-MouseClick','Send-MouseDoubleClick','Send-MouseWheel',
    'Send-Key','Send-Text','Send-KeyCombo','Send-Hotkey',
    'Get-Screenshot','Get-AllScreens',
    'Find-WindowByTitle','Set-WindowForeground','Move-Window',
    'Start-LocalProgram','Open-Url','New-DesktopShortcut',
    'Test-Admin','Test-ControlCapability',
    'Start-ScreenshotSession','Save-StepScreenshot','Add-StepObservation','Get-StepObservationLog','Stop-ScreenshotSession'
)
