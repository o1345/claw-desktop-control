# smoke_test.ps1 - 端到端烟雾测试 (不会破坏系统,仅验证能力)
$ErrorActionPreference = 'Continue'
Import-Module "$PSScriptRoot\LocalControl.psm1" -Force -DisableNameChecking

$outDir = Join-Path $env:TEMP "lc_smoke_$((Get-Date).ToString('HHmmss'))"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Write-Host "输出目录: $outDir" -ForegroundColor Cyan
$pass = 0; $fail = 0

function Test-Name {
    param([string]$Name, [scriptblock]$Block)
    Write-Host ""
    Write-Host "TEST: $Name" -ForegroundColor Yellow
    try {
        & $Block
        Write-Host "  PASS" -ForegroundColor Green
        $script:pass++
    } catch {
        Write-Host "  FAIL: $_" -ForegroundColor Red
        $script:fail++
    }
}

Test-Name "Get-CursorPosition" {
    $p = Get-CursorPosition
    if ($null -eq $p) { throw "no position" }
    Write-Host "  -> ($($p.X),$($p.Y))"
}

Test-Name "Set-MousePosition" {
    Set-MousePosition -X 100 -Y 100
    Start-Sleep -Milliseconds 50
    $p = Get-CursorPosition
    if ($p.X -ne 100 -or $p.Y -ne 100) { throw "expected (100,100), got ($($p.X),$($p.Y))" }
    Write-Host "  -> ($($p.X),$($p.Y))"
}

Test-Name "Move along square" {
    foreach ($pt in @(@(200,200), @(400,200), @(400,400), @(200,400), @(200,200))) {
        Set-MousePosition -X $pt[0] -Y $pt[1]
        Start-Sleep -Milliseconds 40
    }
    $p = Get-CursorPosition
    if ($p.X -ne 200 -or $p.Y -ne 200) { throw "final position wrong" }
}

Test-Name "Get-Screenshot" {
    $f = Get-Screenshot -OutputPath (Join-Path $outDir "shot1.png")
    $size = (Get-Item $f).Length
    if ($size -lt 100) { throw "screenshot too small: $size bytes" }
    Write-Host "  -> $f ($size bytes)"
}

Test-Name "Get-Screenshot region" {
    $f = Get-Screenshot -OutputPath (Join-Path $outDir "shot_region.png") -X 0 -Y 0 -Width 50 -Height 50
    $size = (Get-Item $f).Length
    if ($size -lt 50) { throw "region screenshot too small: $size bytes" }
    Write-Host "  -> $f ($size bytes)"
}

Test-Name "Find-WindowByTitle (powershell)" {
    $ws = Find-WindowByTitle -Title "Windows PowerShell"
    if (-not $ws -or $ws.Count -eq 0) { Write-Host "  (no match, but call ok)" }
    else { Write-Host "  -> found $($ws.Count) window(s)" }
}

Test-Name "Open notepad" {
    $p = Start-LocalProgram -Path "notepad.exe"
    Start-Sleep -Milliseconds 800
    if ($p.HasExited) { throw "notepad exited immediately" }
    Write-Host "  -> pid=$($p.Id)"
    $script:notepad = $p
}

if ($script:notepad) {
    Test-Name "Find notepad window" {
        $ws = Find-WindowByTitle -Title "Notepad"
        if (-not $ws -or $ws.Count -eq 0) { throw "notepad window not found" }
        $script:notepadHandle = $ws[0].Handle
        Write-Host "  -> handle=$($script:notepadHandle) title='$($ws[0].Title)'"
    }

    Test-Name "Activate notepad" {
        Set-WindowForeground -Handle $script:notepadHandle
        Start-Sleep -Milliseconds 300
        Write-Host "  -> activated"
    }

    Test-Name "Move notepad window" {
        Move-Window -Handle $script:notepadHandle -X 50 -Y 50 -Width 600 -Height 400
        Start-Sleep -Milliseconds 200
        Write-Host "  -> moved/resized"
    }

    Test-Name "Type into notepad" {
        $text = "Hello from claw local control at $(Get-Date -Format 'HH:mm:ss')"
        Send-Text -Text $text
        Start-Sleep -Milliseconds 200
        Write-Host "  -> typed: $text"
    }

    Test-Name "Send-Key Enter" {
        Send-Key -Keys "{ENTER}"
        Send-Text -Text "Second line via Send-Key"
        Start-Sleep -Milliseconds 200
    }

    Test-Name "Screenshot of notepad" {
        $f = Get-Screenshot -OutputPath (Join-Path $outDir "notepad.png")
        Write-Host "  -> $f"
    }

    Test-Name "Close notepad" {
        $script:notepad.CloseMainWindow() | Out-Null
        if (-not $script:notepad.WaitForExit(2000)) {
            $script:notepad.Kill()
        }
        Write-Host "  -> closed"
    }
}

Test-Name "Create desktop shortcut" {
    $name = "LCTestCalc_$((Get-Date).ToString('HHmmss'))"
    $s = New-DesktopShortcut -Name $name -TargetPath "C:\Windows\System32\calc.exe" -Description "LocalControl smoke test"
    if (-not (Test-Path $s.FullName)) { throw "shortcut not created" }
    Write-Host "  -> $($s.FullName)"
    Remove-Item $s.FullName -Force
}

Write-Host ""
Write-Host "=== 烟雾测试结果: PASS=$pass  FAIL=$fail ===" -ForegroundColor $(if($fail -eq 0){'Green'}else{'Red'})
Write-Host "产物目录: $outDir"
exit $fail
