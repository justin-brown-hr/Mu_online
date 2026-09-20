# Helper: find / focus / click / screenshot the MU client window.
# Dot-source this:  . C:\work\Mu_online\m1\scripts\MuUI.ps1

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing, System.Windows.Forms @'
using System;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class MuUI {
  [DllImport("user32")] static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32")] static extern int  GetWindowThreadProcessId(IntPtr h, out int p);
  [DllImport("user32")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32")] public static extern void mouse_event(uint f, int x, int y, uint d, IntPtr e);
  [DllImport("user32")] public static extern void keybd_event(byte vk, byte sc, uint f, IntPtr e);
  [DllImport("user32")] public static extern short VkKeyScanW(char c);

  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
  delegate bool EnumProc(IntPtr h, IntPtr l);

  [DllImport("user32")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32")] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);

  // The game window has class "M". A minimized window reports a 0x0 client
  // rect, so accept it by class and let Focus() restore it.
  public static IntPtr Find(int pid) {
    IntPtr best = IntPtr.Zero;
    EnumWindows((h, l) => {
      int p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) {
        RECT r; GetClientRect(h, out r);
        var cls = new StringBuilder(64); GetClassNameW(h, cls, 64);
        if ((r.R > 300 && r.B > 300) || (IsIconic(h) && cls.ToString() == "M")) best = h;
      }
      return true;
    }, IntPtr.Zero);
    return best;
  }

  [DllImport("user32")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);

  public static void Focus(IntPtr h) {
    if (IsIconic(h)) {
      PostMessage(h, 0x0112, new IntPtr(0xF120), IntPtr.Zero);  // WM_SYSCOMMAND SC_RESTORE
      ShowWindow(h, 9);
      System.Threading.Thread.Sleep(2000);
    }
    BringWindowToTop(h); SetForegroundWindow(h);
    System.Threading.Thread.Sleep(600);
  }

  // Keep the game above other windows (e.g. while recording).
  public static void Pin(IntPtr h, bool on) {
    SetWindowPos(h, on ? new IntPtr(-1) : new IntPtr(-2), 0, 0, 0, 0, 0x0013);
  }

  [DllImport("user32")] public static extern int GetSystemMetrics(int i);

  // Move the pointer using an absolute MOUSEEVENTF_MOVE so that DirectInput
  // (which MU uses via dinput8) actually sees the motion. SetCursorPos alone
  // does not generate the motion events the game reads, so its internal
  // cursor would stay put and clicks would land in the wrong place.
  public static void MoveTo(IntPtr h, int cx, int cy) {
    POINT pt = new POINT(); pt.X = cx; pt.Y = cy;
    ClientToScreen(h, ref pt);
    int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
    int ax = (int)((pt.X * 65535L) / (sw - 1));
    int ay = (int)((pt.Y * 65535L) / (sh - 1));
    // nudge first so relative-delta consumers register a change
    mouse_event(0x0001 | 0x8000, ax, ay, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(120);
    mouse_event(0x0001 | 0x8000, ax, ay, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(250);
  }

  // Click at client-area coordinates.
  public static void Click(IntPtr h, int cx, int cy) {
    MoveTo(h, cx, cy);
    mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);   // LEFTDOWN
    System.Threading.Thread.Sleep(90);
    mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);   // LEFTUP
    System.Threading.Thread.Sleep(400);
  }

  public static void Key(byte vk) {
    keybd_event(vk, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(60);
    keybd_event(vk, 0, 2, IntPtr.Zero);
    System.Threading.Thread.Sleep(120);
  }

  public static void TypeText(string s) {
    foreach (char c in s) {
      short vs = VkKeyScanW(c);
      byte vk = (byte)(vs & 0xFF);
      bool shift = (vs & 0x100) != 0;
      if (shift) keybd_event(0x10, 0, 0, IntPtr.Zero);
      Key(vk);
      if (shift) keybd_event(0x10, 0, 2, IntPtr.Zero);
      System.Threading.Thread.Sleep(60);
    }
  }

  public static string Shot(IntPtr h, string path) {
    RECT r; GetClientRect(h, out r);
    POINT o = new POINT();
    ClientToScreen(h, ref o);
    if (r.R <= 0 || r.B <= 0) return "empty rect";
    using (Bitmap bmp = new Bitmap(r.R, r.B)) {
      using (Graphics g = Graphics.FromImage(bmp))
        g.CopyFromScreen(o.X, o.Y, 0, 0, new Size(r.R, r.B));
      bmp.Save(path, ImageFormat.Png);
    }
    return string.Format("{0} ({1}x{2})", path, r.R, r.B);
  }
}
'@

function Get-MuWindow {
    $p = Get-Process main -ErrorAction SilentlyContinue
    if (-not $p) { return $null }
    $h = [MuUI]::Find($p.Id)
    if ($h -eq [IntPtr]::Zero) { return $null }
    return $h
}

# Full path from title screen to in-game (800x600 client, coords verified 2026-09-19):
# server group -> sub-server -> login -> select first character -> Connect.
function Enter-MuWorld {
    param([string]$User = 'test', [string]$Pass = 'test123', [int]$WaitWorld = 12)
    $h = Get-MuWindow
    if (-not $h) { throw "MU window not found" }
    [MuUI]::Pin($h, $true)                                        # stay above the editor while driving input
    [MuUI]::Focus($h)
    Start-Sleep -Seconds 1
    [MuUI]::Click($h, 218, 217); Start-Sleep -Seconds 2      # server group "Ajuda em MuOnline"
    [MuUI]::Click($h, 400, 216); Start-Sleep -Seconds 4      # "(Non-PVP) Conectar"
    [MuUI]::Click($h, 420, 352); Start-Sleep -Milliseconds 400      # account field
    for ($i = 0; $i -lt 12; $i++) { [MuUI]::Key(0x08) }              # clear
    [MuUI]::TypeText($User)
    [MuUI]::Key(0x09); Start-Sleep -Milliseconds 300                  # Tab -> password
    for ($i = 0; $i -lt 12; $i++) { [MuUI]::Key(0x08) }
    [MuUI]::TypeText($Pass)
    [MuUI]::Key(0x0D); Start-Sleep -Seconds 6                         # Enter = OK
    [MuUI]::Click($h, 155, 420); Start-Sleep -Seconds 2               # first character slot
    [MuUI]::Click($h, 695, 526); Start-Sleep -Seconds $WaitWorld      # Connect
    return $h
}
