using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class LC {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT lpPoint);
    [DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    public const int MOUSEEVENTF_LEFTDOWN   = 0x0002;
    public const int MOUSEEVENTF_LEFTUP     = 0x0004;
    public const int MOUSEEVENTF_RIGHTDOWN  = 0x0008;
    public const int MOUSEEVENTF_RIGHTUP    = 0x0010;
    public const int MOUSEEVENTF_MIDDLEDOWN = 0x0020;
    public const int MOUSEEVENTF_MIDDLEUP   = 0x0040;
    public const int MOUSEEVENTF_WHEEL      = 0x0800;
    public const int MOUSEEVENTF_ABSOLUTE   = 0x8000;

    public const int SW_SHOW       = 5;
    public const int SW_RESTORE    = 9;
    public const int SW_MAXIMIZE   = 3;
    public const int SW_MINIMIZE   = 6;

    public const uint SWP_NOSIZE       = 0x0001;
    public const uint SWP_NOMOVE       = 0x0002;
    public const uint SWP_NOZORDER     = 0x0004;
    public const uint SWP_SHOWWINDOW   = 0x0040;
    public const uint SWP_NOACTIVATE   = 0x0010;

    public static IntPtr HWND_TOP       = new IntPtr(0);
    public static IntPtr HWND_TOPMOST   = new IntPtr(-1);
    public static IntPtr HWND_NOTOPMOST = new IntPtr(-2);

    public static POINT GetPos() {
        POINT p; GetCursorPos(out p); return p;
    }
}
