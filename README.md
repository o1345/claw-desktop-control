# claw-desktop-control

**Windows desktop control skill for OpenCode AI agents**

Drive the real mouse, keyboard, and screen using PowerShell + Win32 APIs — zero external dependencies, no pip install, no npm, no SSH.

## Features

- **Mouse**: move, click (left/right/middle), double-click, scroll wheel
- **Keyboard**: type text, send keys, hotkeys (ctrl+c, alt+tab, win+r, etc.)
- **Screen**: full/region screenshots, multi-monitor detection
- **Windows**: find by title (fuzzy or regex), activate, move, resize
- **Launch**: programs, URLs, desktop shortcuts
- **Screenshot session**: auto-rotating numbered screenshots + observation log (avoids LLM context overflow)
- **Admin-aware**: auto-detects elevated/standard user, warns when escalation is needed

## Files

| File | Description |
|------|-------------|
| `SKILL.md` | OpenCode skill definition (load via `skill` tool) |
| `LocalControl.psm1` | PowerShell module (23 exported cmdlets) |
| `LCNative.cs` | Win32 API C# wrapper — `SetCursorPos`, `mouse_event`, `FindWindow`, etc. |
| `local_control.py` | Python wrapper + CLI |
| `diagnose.ps1` | Session / capability / admin self-check |
| `smoke_test.ps1` | 15-step end-to-end validation |
| `demo.py` | Example: open Notepad → type → screenshot → close |

## Quick start for OpenCode

1. Copy this folder to `~/.config/opencode/skills/claw-desktop-control/`
2. Restart opencode
3. Ask: "检查桌面控制能力" → AI auto-loads the skill and runs `diagnose.ps1`

## Requirements

- Windows 10/11 (tested on Win11 23H2)
- PowerShell 5.1+ (built-in)
- Python 3.x (optional — Python wrapper is a convenience layer over PS)
- Session 1+ (interactive desktop)

## License

MIT
