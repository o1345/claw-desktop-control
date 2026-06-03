"""local_control.py - 本机桌面控制 Python 包装 (无 SSH)

依赖: Windows + PowerShell 5.1+ (Win11 自带)
所有控制通过 subprocess 调用 PowerShell 模块 LocalControl.psm1
底层使用 Win32 API (SetCursorPos / mouse_event / SendKeys / etc.)
要求: 必须在 Session 1+ 交互会话中运行 (同桌面用户)
"""

from __future__ import annotations
import os
import sys
import json
import time
import shutil
import shlex
import subprocess
from pathlib import Path
from typing import Optional, List, Tuple, Union

HERE = Path(__file__).resolve().parent
PS_MODULE = HERE / "LocalControl.psm1"
PS_EXE = shutil.which("powershell") or shutil.which("pwsh") or "powershell.exe"

DEFAULT_TIMEOUT = 30


def _run_ps(script: str, timeout: int = DEFAULT_TIMEOUT, capture: bool = True) -> Tuple[int, str, str]:
    cmd = [
        PS_EXE,
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy", "Bypass",
        "-Command",
        (
            f"Import-Module '{PS_MODULE}' -Force -DisableNameChecking; "
            f"$ErrorActionPreference = 'Stop'; "
            f"{script}"
        ),
    ]
    result = subprocess.run(
        cmd,
        capture_output=capture,
        text=True,
        timeout=timeout,
        encoding="utf-8",
        errors="replace",
    )
    return result.returncode, result.stdout, result.stderr


def _quote(v) -> str:
    if isinstance(v, str):
        s = v.replace("'", "''")
        return f"'{s}'"
    return str(v)


def mouse_position() -> Tuple[int, int]:
    rc, out, err = _run_ps("$p = Get-CursorPosition; \"$($p.X),$($p.Y)\"")
    if rc != 0:
        raise RuntimeError(f"Get-CursorPosition failed: {err}")
    x, y = out.strip().split(",")
    return int(x), int(y)


def move_mouse(x: int, y: int) -> None:
    script = f"Set-MousePosition -X {int(x)} -Y {int(y)}"
    rc, out, err = _run_ps(script)
    if rc != 0:
        raise RuntimeError(f"Set-MousePosition failed: {err}")


def click(button: str = "left", x: Optional[int] = None, y: Optional[int] = None, hold_ms: int = 30) -> None:
    if button not in ("left", "right", "middle"):
        raise ValueError(f"invalid button: {button}")
    parts = [f"-Button '{button}'", f"-HoldMs {int(hold_ms)}"]
    if x is not None and y is not None:
        parts += [f"-X {int(x)}", f"-Y {int(y)}"]
    rc, out, err = _run_ps(f"Send-MouseClick {' '.join(parts)}")
    if rc != 0:
        raise RuntimeError(f"Send-MouseClick failed: {err}")


def double_click(button: str = "left", x: Optional[int] = None, y: Optional[int] = None) -> None:
    parts = [f"-Button '{button}'"]
    if x is not None and y is not None:
        parts += [f"-X {int(x)}", f"-Y {int(y)}"]
    rc, out, err = _run_ps(f"Send-MouseDoubleClick {' '.join(parts)}")
    if rc != 0:
        raise RuntimeError(f"Send-MouseDoubleClick failed: {err}")


def wheel(delta: int = -120) -> None:
    rc, out, err = _run_ps(f"Send-MouseWheel -Delta {int(delta)}")
    if rc != 0:
        raise RuntimeError(f"Send-MouseWheel failed: {err}")


def send_key(keys: str) -> None:
    rc, out, err = _run_ps(f"Send-Key -Keys {_quote(keys)}")
    if rc != 0:
        raise RuntimeError(f"Send-Key failed: {err}")


def type_text(text: str) -> None:
    rc, out, err = _run_ps(f"Send-Text -Text {_quote(text)}")
    if rc != 0:
        raise RuntimeError(f"Send-Text failed: {err}")


def hotkey(*keys: str) -> None:
    keys_l = [k.lower() for k in keys]
    if len(keys_l) == 1:
        send_key("{" + keys_l[0] + "}")
        return
    if len(keys_l) == 2 and keys_l[0] in ("ctrl", "alt", "shift", "win"):
        rc, out, err = _run_ps(
            f"Send-Hotkey -Modifier {_quote(keys_l[0])} -Key {_quote(keys_l[1])}"
        )
        if rc != 0:
            raise RuntimeError(f"Send-Hotkey failed: {err}")
        return
    parts = ",".join(_quote(k) for k in keys_l)
    rc, out, err = _run_ps(f"Send-KeyCombo -Keys @({parts})")
    if rc != 0:
        raise RuntimeError(f"Send-KeyCombo failed: {err}")


def screenshot(output_path: Union[str, os.PathLike],
               x: int = 0, y: int = 0,
               width: int = 0, height: int = 0) -> Path:
    output_path = Path(output_path)
    parts = [f"-OutputPath {_quote(str(output_path))}"]
    if x:      parts.append(f"-X {x}")
    if y:      parts.append(f"-Y {y}")
    if width:  parts.append(f"-Width {width}")
    if height: parts.append(f"-Height {height}")
    rc, out, err = _run_ps(f"Get-Screenshot {' '.join(parts)}")
    if rc != 0:
        raise RuntimeError(f"Get-Screenshot failed: {err}")
    return output_path


def find_window(title: str, regex: bool = False) -> List[dict]:
    parts = [f"-Title {_quote(title)}"]
    if regex:
        parts.append("-Regex")
    rc, out, err = _run_ps(
        f"$ws = Find-WindowByTitle {' '.join(parts)}; "
        f"$ws | ForEach-Object {{ ConvertTo-Json $_ -Compress }}"
    )
    if rc != 0:
        raise RuntimeError(f"Find-WindowByTitle failed: {err}")
    items = []
    for line in out.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        d["Handle"] = int(d["Handle"])
        d["PID"] = int(d["PID"])
        items.append(d)
    return items


def activate_window(handle: int) -> None:
    rc, out, err = _run_ps(f"Set-WindowForeground -Handle {int(handle)}")
    if rc != 0:
        raise RuntimeError(f"Set-WindowForeground failed: {err}")


def open_program(path: str, arguments: str = "", working_directory: str = "", wait: bool = False) -> int:
    parts = [f"-Path {_quote(path)}"]
    if arguments:        parts.append(f"-Arguments {_quote(arguments)}")
    if working_directory: parts.append(f"-WorkingDirectory {_quote(working_directory)}")
    if wait:             parts.append("-Wait")
    rc, out, err = _run_ps(f"Start-LocalProgram {' '.join(parts)}")
    if rc != 0:
        raise RuntimeError(f"Start-LocalProgram failed: {err}")
    try:
        return int(out.strip().splitlines()[-1].strip())
    except Exception:
        return 0


def open_url(url: str) -> None:
    rc, out, err = _run_ps(f"Open-Url -Url {_quote(url)}")
    if rc != 0:
        raise RuntimeError(f"Open-Url failed: {err}")


def create_shortcut(name: str, target_path: str,
                    arguments: str = "", description: str = "",
                    icon_location: str = "", working_directory: str = "",
                    folder: str = "Desktop") -> Path:
    parts = [
        f"-Name {_quote(name)}",
        f"-TargetPath {_quote(target_path)}",
    ]
    if arguments:        parts.append(f"-Arguments {_quote(arguments)}")
    if description:      parts.append(f"-Description {_quote(description)}")
    if icon_location:    parts.append(f"-IconLocation {_quote(icon_location)}")
    if working_directory: parts.append(f"-WorkingDirectory {_quote(working_directory)}")
    if folder:           parts.append(f"-Folder {_quote(folder)}")
    rc, out, err = _run_ps(f"New-DesktopShortcut {' '.join(parts)}")
    if rc != 0:
        raise RuntimeError(f"New-DesktopShortcut failed: {err}")
    return Path(out.strip().splitlines()[-1].strip())


def is_admin() -> bool:
    rc, out, err = _run_ps("(Test-Admin).IsAdmin")
    if rc != 0:
        raise RuntimeError(f"Test-Admin failed: {err}")
    return out.strip().lower() == "true"


def admin_report() -> dict:
    rc, out, err = _run_ps("Test-Admin | ConvertTo-Json -Compress")
    if rc != 0:
        raise RuntimeError(f"Test-Admin failed: {err}")
    return json.loads(out.strip())


def diagnose() -> dict:
    rc, out, err = _run_ps("Test-ControlCapability | ConvertTo-Json -Compress")
    if rc != 0:
        raise RuntimeError(f"Test-ControlCapability failed: {err}")
    return json.loads(out.strip())


def start_session(base_dir: Union[str, os.PathLike, None] = None,
                  max_screenshots: int = 10, force: bool = False) -> dict:
    parts = [f"-MaxScreenshots {max_screenshots}"]
    if base_dir: parts.append(f"-BaseDir {_quote(str(base_dir))}")
    if force:    parts.append("-Force")
    rc, out, err = _run_ps(f"Start-ScreenshotSession {' '.join(parts)} | ConvertTo-Json -Compress")
    if rc != 0:
        raise RuntimeError(f"Start-ScreenshotSession failed: {err}")
    return json.loads(out.strip())


def step_screenshot(base_dir: Union[str, os.PathLike, None] = None,
                    max_screenshots: int = 10) -> Path:
    parts = [f"-MaxScreenshots {max_screenshots}"]
    if base_dir: parts.append(f"-ScreenshotDir {_quote(str(base_dir / '_screenshots' if isinstance(base_dir, Path) else Path(base_dir) / '_screenshots'))}")
    rc, out, err = _run_ps(f"Save-StepScreenshot {' '.join(parts)}")
    if rc != 0:
        raise RuntimeError(f"Save-StepScreenshot failed: {err}")
    return Path(out.strip().splitlines()[-1].strip())


def add_observation(observation: List[str],
                    log_path: Union[str, os.PathLike, None] = None,
                    screenshot_name: str = "") -> None:
    parts = [f"-Observation @({','.join(_quote(s) for s in observation)})"]
    if log_path:       parts.append(f"-LogPath {_quote(str(log_path))}")
    if screenshot_name: parts.append(f"-ScreenshotName {_quote(screenshot_name)}")
    rc, out, err = _run_ps(f"Add-StepObservation {' '.join(parts)}")
    if rc != 0:
        raise RuntimeError(f"Add-StepObservation failed: {err}")


def get_observation_log(log_path: Union[str, os.PathLike, None] = None,
                        tail: int = 0) -> str:
    parts = []
    if log_path: parts.append(f"-LogPath {_quote(str(log_path))}")
    if tail > 0: parts.append(f"-Tail {tail}")
    rc, out, err = _run_ps(f"Get-StepObservationLog {' '.join(parts)}")
    if rc != 0:
        raise RuntimeError(f"Get-StepObservationLog failed: {err}")
    return out.strip()


def stop_session(base_dir: Union[str, os.PathLike, None] = None,
                 keep_log: bool = False) -> None:
    parts = []
    if base_dir:  parts.append(f"-BaseDir {_quote(str(base_dir))}")
    if keep_log:  parts.append("-KeepLog")
    _run_ps(f"Stop-ScreenshotSession {' '.join(parts)}")


if __name__ == "__main__":
    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    import argparse
    ap = argparse.ArgumentParser(description="本机桌面控制 CLI")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("diag");         p.add_argument("--json", action="store_true")
    p = sub.add_parser("admin")
    p = sub.add_parser("pos")
    p = sub.add_parser("move");         p.add_argument("x", type=int); p.add_argument("y", type=int)
    p = sub.add_parser("click");        p.add_argument("--button", default="left")
    p.add_argument("--x", type=int)
    p.add_argument("--y", type=int)
    p = sub.add_parser("dblclick");     p.add_argument("--button", default="left")
    p.add_argument("--x", type=int)
    p.add_argument("--y", type=int)
    p = sub.add_parser("type");         p.add_argument("text")
    p = sub.add_parser("key");          p.add_argument("keys")
    p = sub.add_parser("hotkey");       p.add_argument("keys", nargs="+")
    p = sub.add_parser("shot");         p.add_argument("output")
    p.add_argument("--x", type=int, default=0)
    p.add_argument("--y", type=int, default=0)
    p.add_argument("--w", type=int, default=0)
    p.add_argument("--h", type=int, default=0)
    p = sub.add_parser("find");         p.add_argument("title"); p.add_argument("--regex", action="store_true")
    p = sub.add_parser("activate");     p.add_argument("handle", type=lambda v: int(v, 0))
    p = sub.add_parser("open");         p.add_argument("path"); p.add_argument("--args", default="")
    p = sub.add_parser("url");          p.add_argument("url")
    p = sub.add_parser("shortcut");     p.add_argument("name"); p.add_argument("target")
    p.add_argument("--args", default="")
    p.add_argument("--desc", default="")

    p = sub.add_parser("start-session"); p.add_argument("--dir", default="")
    p.add_argument("--max", type=int, default=10); p.add_argument("--force", action="store_true")
    p = sub.add_parser("step-shot");     p.add_argument("--dir", default="")
    p.add_argument("--max", type=int, default=10)
    p = sub.add_parser("observe");       p.add_argument("text", nargs="+")
    p.add_argument("--snapshot", default=""); p.add_argument("--log", default="")
    p = sub.add_parser("observe-log");   p.add_argument("--log", default="")
    p.add_argument("--tail", type=int, default=0)
    p = sub.add_parser("end-session");   p.add_argument("--dir", default="")
    p.add_argument("--keep-log", action="store_true")

    args = ap.parse_args()
    try:
        if args.cmd == "diag":
            r = diagnose()
            print(json.dumps(r, indent=2, ensure_ascii=False))
        elif args.cmd == "admin":
            r = admin_report()
            print(json.dumps(r, indent=2, ensure_ascii=False))
        elif args.cmd == "pos":
            print(mouse_position())
        elif args.cmd == "move":
            move_mouse(args.x, args.y)
        elif args.cmd == "click":
            click(args.button, args.x, args.y)
        elif args.cmd == "dblclick":
            double_click(args.button, args.x, args.y)
        elif args.cmd == "type":
            type_text(args.text)
        elif args.cmd == "key":
            send_key(args.keys)
        elif args.cmd == "hotkey":
            hotkey(*args.keys)
        elif args.cmd == "shot":
            p = screenshot(args.output, args.x, args.y, args.w, args.h)
            print(p)
        elif args.cmd == "find":
            for w in find_window(args.title, args.regex):
                print(f"{w['Handle']:>10}  pid={w['PID']:>6}  {w['X']},{w['Y']} {w['Width']}x{w['Height']}  {w['Title']}")
        elif args.cmd == "activate":
            activate_window(args.handle)
        elif args.cmd == "open":
            open_program(args.path, args.args)
        elif args.cmd == "url":
            open_url(args.url)
        elif args.cmd == "shortcut":
            create_shortcut(args.name, args.target, args.args, args.desc)
        elif args.cmd == "start-session":
            r = start_session(args.dir or None, args.max, args.force)
            print(json.dumps(r, indent=2, ensure_ascii=False))
        elif args.cmd == "step-shot":
            p = step_screenshot(args.dir or None, args.max)
            print(p)
        elif args.cmd == "observe":
            add_observation(args.text, args.log or None, args.snapshot)
        elif args.cmd == "observe-log":
            print(get_observation_log(args.log or None, args.tail))
        elif args.cmd == "end-session":
            stop_session(args.dir or None, args.keep_log)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
