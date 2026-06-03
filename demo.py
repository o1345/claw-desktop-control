"""demo.py - 本机桌面控制演示
示例: 打开记事本, 输入文字, 截图, 关闭
"""
import time
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import local_control as lc


def main():
    print("=== LocalControl 演示 ===\n")

    print("1) 自检:")
    diag = lc.diagnose()
    print(f"   SessionId={diag['SessionId']}  User={diag['User']}  "
          f"Interactive={diag['IsInteractive']}  "
          f"Screen={diag['ScreenBounds']['Width']}x{diag['ScreenBounds']['Height']}")
    print(f"   MouseMove={diag['CursorMoveTest']}")
    print(f"   Screenshot={diag['ScreenshotTest']}\n")

    out_dir = Path(HERE) / "demo_out"
    out_dir.mkdir(exist_ok=True)

    print("2) 打开记事本...")
    p = lc.open_program("notepad.exe")
    time.sleep(0.8)
    print(f"   pid={p}")

    print("3) 等待并查找窗口...")
    time.sleep(0.5)
    windows = lc.find_window("Notepad")
    if not windows:
        print("   ERROR: 找不到记事本窗口, 退出")
        return 1
    h = windows[0]["Handle"]
    print(f"   handle={h}  title='{windows[0]['Title']}'  pos=({windows[0]['X']},{windows[0]['Y']})  "
          f"size={windows[0]['Width']}x{windows[0]['Height']}")

    print("4) 移动并调整记事本窗口大小...")
    import subprocess
    subprocess.run([
        "powershell", "-NoProfile", "-Command",
        f"Import-Module '{HERE / 'LocalControl.psm1'}' -Force; "
        f"Move-Window -Handle {h} -X 50 -Y 50 -Width 700 -Height 500"
    ], check=True)

    print("5) 激活记事本窗口...")
    lc.activate_window(h)
    time.sleep(0.3)

    print("6) 输入文字...")
    lc.type_text("Hello from claw local_control.py\n")
    lc.type_text("Second line at " + time.strftime("%H:%M:%S") + "\n")
    time.sleep(0.3)

    print("7) 演示组合键 Ctrl+End (跳到末尾)...")
    lc.hotkey("ctrl", "End")
    time.sleep(0.2)
    lc.type_text("\n--- End of demo ---\n")

    print("8) 截图保存...")
    shot = lc.screenshot(out_dir / "demo_notepad.png")
    print(f"   {shot}  ({shot.stat().st_size} bytes)")

    print("9) 移动鼠标演示 (从中心向外)...")
    cx, cy = 640, 512
    for r in (0, 50, 100, 150, 100, 50, 0):
        lc.move_mouse(cx + r, cy)
        time.sleep(0.05)
    print(f"   鼠标位置: {lc.mouse_position()}")

    print("10) 关闭记事本 (保存对话框可能弹出)...")
    p.CloseMainWindow()
    time.sleep(0.5)
    if not p.HasExited:
        p.Kill()
    print("    done\n")

    print("=== 演示完成 ===")
    print(f"输出: {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
