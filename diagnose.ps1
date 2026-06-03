# diagnose.ps1 - Session 与控制能力自检
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\LocalControl.psm1" -Force -DisableNameChecking

Write-Host "=== LocalControl 自检 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "进程信息:"
Write-Host "  PID=$($PID)  SessionId=$((Get-Process -Id $PID).SessionId)  User=$([Environment]::UserName)"
Write-Host "  IsInteractive=$([Environment]::UserInteractive)"
Write-Host "  OS=$([Environment]::OSVersion.VersionString)"
Write-Host ""

Write-Host "屏幕:"
$screens = Get-AllScreens
foreach ($s in $screens) {
    $tag = if ($s.Primary) { ' (主)' } else { '' }
    Write-Host "  $($s.DeviceName)$tag - $($s.Bounds.Width)x$($s.Bounds.Height) @ ($($s.Bounds.X),$($s.Bounds.Y))"
}
Write-Host ""

Write-Host "当前光标:"
$pos = Get-CursorPosition
Write-Host "  ($($pos.X), $($pos.Y))"
Write-Host ""

Write-Host "鼠标移动测试 (50,50)..."
Set-MousePosition -X 50 -Y 50
Start-Sleep -Milliseconds 50
$after = Get-CursorPosition
if ($after.X -eq 50 -and $after.Y -eq 50) {
    Write-Host "  OK -> ($($after.X),$($after.Y))" -ForegroundColor Green
} else {
    Write-Host "  FAIL -> ($($after.X),$($after.Y))" -ForegroundColor Red
}
Write-Host ""

Write-Host "截图测试 (200x100)..."
try {
    $tmp = Join-Path $env:TEMP "lc_diag_$([guid]::NewGuid()).png"
    $f = Get-Screenshot -OutputPath $tmp -Width 200 -Height 100
    Write-Host "  OK -> $($f.FullName) ($((Get-Item $f.FullName).Length) bytes)" -ForegroundColor Green
    Remove-Item $f.FullName -Force
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "SendKeys 加载测试..."
try {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait('')
    Write-Host "  OK" -ForegroundColor Green
} catch {
    Write-Host "  FAIL: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "可见顶层窗口 (前10):"
Get-Process | Where-Object { $_.MainWindowTitle -ne '' -and $_.MainWindowHandle -ne 0 } |
    Select-Object -First 10 Id, ProcessName, MainWindowTitle, MainWindowHandle |
    Format-Table -AutoSize

Write-Host "=== 自检完成 ===" -ForegroundColor Cyan
