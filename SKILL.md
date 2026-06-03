---
name: claw-desktop-control
description: Use when the user asks to control the Windows desktop on this PC - moving/clicking the mouse, typing text, pressing keys, taking screenshots, finding/activating/moving/resizing windows, launching programs, opening URLs, or creating desktop shortcuts. Triggers include (Chinese) 鼠标, 键盘, 截图, 屏幕, 点击, 输入文字, 自动化, 桌面控制, 窗口, 操作屏幕, 控制电脑, 虚拟鼠标, 虚拟键盘, GUI 自动化, RPA, 模拟点击, 模拟输入, 移动窗口, 启动程序, 桌面快捷方式, 打开应用, 自动填表, 自动点击; and (English) screenshot, click, type text, move window, open program, automate GUI, desktop automation, virtual mouse, virtual keyboard, send keys, find window, activate window, RPA, UI automation. Drive the user's actual screen via PowerShell + Win32 APIs. Self-contained: module, Python wrapper, scripts, and tests all live in this skill folder. Requires Session 1+ (an interactive desktop). Auto-detects admin/standard user and warns when elevation is needed.
---

# claw-desktop-control

Control the Windows desktop of the current user from inside opencode.
Drives the real mouse, keyboard, and screen using PowerShell + Win32 APIs
(`SetCursorPos`, `mouse_event`, `SendKeys`, `CopyFromScreen`, `FindWindow`,
`SetForegroundWindow`, `MoveWindow`).

## Skill layout (self-contained)

```
C:\Users\zkics\.config\opencode\skills\claw-desktop-control\
  SKILL.md              <- this file
  LocalControl.psm1     <- PowerShell module (17 exported cmdlets)
  LCNative.cs           <- Win32 API C# wrapper
  local_control.py      <- Python wrapper + CLI
  diagnose.ps1          <- session / capability / admin self-check
  smoke_test.ps1        <- 15-step end-to-end smoke test
  demo.py               <- open notepad -> type -> screenshot -> close
```

Source of truth is also mirrored at `E:\AI\claw\local\` for the user's own
edits. Update both if you change the API surface.

## Step 0 - Always start with the self-check

Before doing anything destructive, run the diagnostic. It reports the session
id, admin/standard status, screen geometry, mouse/test result, screenshot
test, and a hint about elevation.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\opencode\skills\claw-desktop-control\diagnose.ps1"
```

```python
import sys; sys.path.insert(0, r"C:\Users\zkics\.config\opencode\skills\claw-desktop-control")
import local_control as lc
print(lc.diagnose())
print(lc.admin_report())
```

```bash
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" diag
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" admin
```

Stop and tell the user to relaunch opencode as Administrator (right-click
PowerShell -> "Run as administrator" -> run `opencode`) if the diagnostic
shows `IsAdmin = false` AND the upcoming task needs to:

- write to `C:\Program Files\*`, `C:\Windows\System32\*`, `HKLM:\`
- start / stop / configure Windows services
- drive another user's session or a UAC-elevated window via `SendInput`
- install / uninstall software

For ordinary desktop GUI automation (browsers, Office, Notepad, file
explorers, custom apps running as the current user) `IsAdmin = false` is
**fine** - do not escalate unnecessarily.

## API surface (PowerShell module `LocalControl`)

```powershell
Import-Module "$env:USERPROFILE\.config\opencode\skills\claw-desktop-control\LocalControl.psm1" -Force -DisableNameChecking

# Mouse
Get-CursorPosition                                       # -> { X, Y }
Set-MousePosition -X 500 -Y 300
Send-MouseClick   -Button left|right|middle [-X .. -Y ..] [-HoldMs 30]
Send-MouseDoubleClick -Button left -X 100 -Y 100
Send-MouseWheel   -Delta -120                            # negative = scroll down

# Keyboard
Send-Text     -Text "Hello world"                        # literal text, braces escaped
Send-Key      -Keys "{ENTER}"                            # single named key
Send-KeyCombo -Keys ctrl,c                                # uses {} wrapping internally
Send-Hotkey   -Modifier ctrl|alt|shift|win -Key c        # canonical ctrl/alt/shift/win+key

# Screen
Get-Screenshot -OutputPath "C:\path\out.png" [-X 0 -Y 0 -Width 0 -Height 0]
Get-AllScreens

# Windows
Find-WindowByTitle -Title "Notepad" [-Regex]              # returns Handle, Title, PID, X/Y/W/H
Set-WindowForeground -Handle 12345
Move-Window  -Handle 12345 -X 50 -Y 50 -Width 800 -Height 600 [-TopMost]

# Programs / URLs
Start-LocalProgram -Path "notepad.exe" [-Arguments "..."] [-WorkingDirectory "..."] [-Wait]
Open-Url -Url "https://example.com"
New-DesktopShortcut -Name "MyApp" -TargetPath "C:\...\app.exe" [-Arguments ...] [-Description ...] [-IconLocation ...] [-WorkingDirectory ...] [-Folder Desktop|StartMenu|...]

# Diagnostics
Test-Admin             # IsAdmin, User, UAC, hint
Test-ControlCapability # SessionId, IsAdmin, screen, mouse/screenshot test, foreground

# Screenshot Session (managed rotation + observation log)
Start-ScreenshotSession     [-BaseDir D:\AI] [-MaxScreenshots 10] [-Force]
Save-StepScreenshot         [-ScreenshotDir D:\AI\_screenshots] [-MaxScreenshots 10]
Add-StepObservation         [-LogPath _screenshots\_log.md] [-ScreenshotName "_step_001.png"] [-Observation "..."]
Get-StepObservationLog      [-LogPath _screenshots\_log.md] [-Tail 5]
Stop-ScreenshotSession      [-BaseDir D:\AI] [-KeepLog]
```

## API surface (Python `local_control.py`)

```python
import sys; sys.path.insert(0, r"C:\Users\zkics\.config\opencode\skills\claw-desktop-control")
import local_control as lc

# Diagnostics
lc.diagnose()        # dict - everything Test-ControlCapability returns
lc.admin_report()    # dict - Test-Admin output
lc.is_admin()        # bool

# Mouse
lc.mouse_position()                          # (x, y)
lc.move_mouse(500, 300)
lc.click("left", x=500, y=300, hold_ms=30)
lc.double_click("left", x=100, y=100)
lc.wheel(-120)                               # scroll down 1 notch

# Keyboard
lc.type_text("Hello world")
lc.send_key("{ENTER}")
lc.hotkey("ctrl", "c")                       # canonical modifier+key
lc.hotkey("ctrl", "shift", "esc")            # 3-key combo

# Screen
lc.screenshot(r"C:\path\out.png")            # full screen
lc.screenshot(r"C:\path\r.png", x=0, y=0, width=400, height=300)  # region

# Windows
for w in lc.find_window("Notepad"):          # fuzzy
    print(w["Handle"], w["Title"], w["X"], w["Y"], w["Width"], w["Height"])
for w in lc.find_window(r"^PowerShell.*$", regex=True):
    ...
lc.activate_window(w["Handle"])

# Programs / URLs / shortcuts
lc.open_program("notepad.exe", arguments=r"C:\readme.txt")
lc.open_url("https://example.com")
lc.create_shortcut("MyApp", r"C:\Windows\System32\calc.exe",
                   arguments="", description="calc shortcut")

# Screenshot session (managed rotation + observation log)
lc.start_session(base_dir="D:\\AI", max_screenshots=10, force=True)
p = lc.step_screenshot()                    # _step_001.png _step_002.png ...
lc.add_observation(["Notepad window open.", "Text: Hello."], screenshot_name=p.name)
log = lc.get_observation_log(tail=5)         # read log (NOT old screenshots)
lc.stop_session(keep_log=False)              # or keep_log=True to preserve log
```

CLI (handy from bash for one-shot commands):

```bash
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" move 500 300
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" click --x 500 --y 300
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" type "hello"
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" hotkey ctrl c
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" shot out.png
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" find Notepad
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" activate 198132
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" open notepad.exe
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" start-session --dir D:\AI --force
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" step-shot --dir D:\AI
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" observe "Button text: OK" "Position: (500,400)" --snapshot _step_001.png
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" observe-log --tail 5
python "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\local_control.py" end-session --dir D:\AI
```

## Golden rule: screenshot → observe → log → forget

**Screenshots are for your eyes only.** Reading a PNG image loads it into the
LLM context as base64 — one 1280×1024 screenshot costs ~170K tokens, nearly
filling the entire 200K context window. If you keep old screenshots in the
conversation, you will run out of room for instructions, tool results, and
planning.

**The observation log is your memory, not old images.** After you read a
screenshot:

1. Extract **everything relevant** into text — window title, visible buttons,
   input contents, error messages, cursor position, menu items, progress bars.
   Be thorough; if you miss it now, you will not see it again.
2. Write the observations to `_log.md` via `Add-StepObservation`.
3. You are done with that image. **Do not keep it in your context.** The
   observation log is all you need to reference later.

### Workflow loop

```
  ┌─ Start-ScreenshotSession  (dir, max=10)
  │
  │  ┌──────────────────────────────────────────────┐
  │  │ LOOP: do one step of "do X in <app>"         │
  │  │                                              │
  │  │ 1. Save-StepScreenshot  (auto-numbered,      │
  │  │    rotation deletes oldest beyond max)        │
  │  │ 2. Read the .png with the `read` tool         │
  │  │ 3. Add-StepObservation of what you see        │
  │  │ 4. If you need previous context, read the     │
  │  │    observation log (Get-StepObservationLog)   │
  │  │    — do NOT re-read old .png files            │
  │  │ 5. Drive the UI (move / click / type)         │
  │  │ 6. Repeat                                    │
  │  └──────────────────────────────────────────────┘
  │
  └─ Stop-ScreenshotSession  (or let rotation handle
       cleanup next session)
```

When the user says "do X in <app>":

1. **Diagnose first** — `IsInteractive=True`, `SessionId>=1`, `IsAdmin`.
2. **Start-ScreenshotSession** — creates `_screenshots/` dir and `_log.md`.
3. **Find / launch / activate the target window.**
4. **Enter the loop:**
   a. `Save-StepScreenshot` (one new numbered file; oldest auto-deleted).
   b. Read the .png with the `read` tool.
   c. Teletype what you see into `Add-StepObservation`. Cover: window title,
      text fields, button labels, checked/unchecked state, error messages,
      cursor position, any element relevant to the task. Write enough that you
      will not need the image again.
   d. If you need prior context, read `Get-StepObservationLog` with `-Tail`.
   e. Act (mouse, keyboard) + `Start-Sleep -Milliseconds 100-300`.
   f. Repeat from (a) until the task is done or the user stops you.
5. **Stop-ScreenshotSession** (or skip — next run's `-Force` cleans old files).

### What NOT to do

- **Do NOT** keep 2+ screenshots in your context. Keep at most the very latest
  one while you are reading it. After writing the observation, it is done.
- **Do NOT** re-read old `.png` files. Read the observation log instead. If
  the log is not detailed enough, write a better observation next time.
- **Do NOT** call `Get-Screenshot` directly — always use `Save-StepScreenshot`
  so rotation kicks in and old files are automatically deleted.

## Hard constraints

- **Session 1+ required.** If the diagnostic reports `SessionId=0`, the
  current shell is a service/background process and cannot drive the
  interactive desktop. Tell the user to re-run opencode from a normal
  PowerShell window or via RDP.
- **SendKeys needs the target window in the foreground.** If typed text
  goes to the wrong window, you forgot to activate it. Always
  `Set-WindowForeground` first and `Start-Sleep -Milliseconds 300`.
- **Mouse move uses `SetCursorPos`** (not `Cursor.Position`); this is what
  gets around UIPI for same-session targets.
- **Screenshot is screen-only.** It does not capture the Win11 screen
  recorder's protected content (DRM video, secure desktop, etc.). If the
  user needs that, say so up front.
- **Do not** use `SendInput` for keystrokes from this skill - the
  `System.Windows.Forms.SendKeys` path is simpler and more than enough for
  ordinary automation; if you need Unicode beyond the keyboard layout, ask
  the user.
- **Do not** invent extra Python deps. `subprocess` + PowerShell is the
  whole transport. No `pip install`.

## Failure modes & fixes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `MouseMoveTest` shows wrong coords | cursor is locked by another app | release with click, or have the user click somewhere first |
| `ScreenshotTest = FAIL` | screen is locked or DPI changed | tell user to unlock / check display settings |
| `SendKeysLoad = FAIL` | `System.Windows.Forms` not loadable | rare; check `$PSVersionTable.PSVersion` (need 5.1+) |
| typed text goes to wrong window | forgot `Set-WindowForeground` | activate then sleep 300 ms |
| `Open xxx` does nothing | UAC prompt blocking | run elevated, or pick an app that does not need elevation |
| `Find-WindowByTitle` returns nothing | title is in a different language/code page | try `--regex` with a partial pattern |
| powershell exits with 0 but no effect | module not loaded | check `-Force -DisableNameChecking` is in the import line |

## End-to-end validation

If the user asks "is this thing working", run:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.config\opencode\skills\claw-desktop-control\smoke_test.ps1"
```

15-step smoke test: mouse position, mouse move, square path, full screenshot,
region screenshot, window enumeration, notepad launch, window find, window
activation, window move/resize, type text, send Enter, screenshot, close
notepad, desktop shortcut create. Should print `PASS=15 FAIL=0`.

It will pop a real notepad window on the user's screen for ~2 seconds.
Warn the user before running it.

## When NOT to use this skill

- The user is on a different machine (this skill drives **this** PC only).
- The user wants browser automation specifically - use the Playwright MCP
  server (`mcp.playwright`) instead; it is faster and does not fight the
  foreground window.
- The task is pure file / shell work with no GUI - use the regular `bash`
  tool.
- The user only wants to *talk about* automation, not run it.
