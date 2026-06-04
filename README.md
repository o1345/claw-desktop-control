# claw-desktop-control

**Windows desktop control skill for OpenCode AI agents**

> 🤖 This project was entirely AI-generated. The human author (o1345) does not write code — every line was produced by AI agents during interactive sessions.  
> If you find issues or want improvements, please open an issue rather than contacting the author directly — the AI can fix anything.

Drive the real mouse, keyboard, and screen using PowerShell + Win32 APIs — zero external dependencies, no pip install, no npm, no SSH.

## Story

This project started as a casual chat about Python's advantages. The AI mentioned that **Microsoft had built virtual mouse and keyboard APIs into Windows decades ago** (`SetCursorPos`, `mouse_event`, `SendKeys` — dating back to the Windows 95 era). The human author immediately realized: *if an AI can call these APIs, the AI gains hands — it can see the screen, move the cursor, click buttons, and type text, just like a human operating a computer.*

The original prototype (`E:\AI\claw\`) was SSH-based, designed to remote-control Windows from Linux. But the real breakthrough was realizing the same techniques could work **locally with zero dependencies** — every Windows machine already has PowerShell and the Win32 APIs built in. No Python package, no Node.js module, no SSH tunnel. Just an AI agent talking directly to Windows.

The entire codebase was produced through interactive AI chat sessions. The human author never wrote a single line of code manually.

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
