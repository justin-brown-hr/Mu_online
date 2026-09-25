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

  // MU draws its own cursor from DirectInput relative deltas, which drift away
  // from the real pointer - menu rows then swallow clicks because the game
  // thinks the cursor is 20-30px elsewhere. Parking at the screen corner first
  // clamps both cursors to the same place, so the following move re-syncs them.
  public static void MoveToSync(IntPtr h, int cx, int cy) {
    mouse_event(0x0001 | 0x8000, 0, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(220);
    MoveTo(h, cx, cy);
  }

  public static void ClickSync(IntPtr h, int cx, int cy) {
    MoveToSync(h, cx, cy);
    mouse_event(0x0002, 0, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(90);
    mouse_event(0x0004, 0, 0, 0, IntPtr.Zero);
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

# --- calibrated screen tests ------------------------------------------------
# Pixel probes verified at 1280x1024 (2026-09-22). Bands are expressed as
# fractions of the client area so other resolutions degrade gracefully.

function Get-MuShot {
    param([IntPtr]$H)
    $p = Join-Path $env:TEMP 'm1-probe.png'
    try { [MuUI]::Shot($H, $p) | Out-Null } catch { return $null }
    Add-Type -AssemblyName System.Drawing
    return [System.Drawing.Bitmap]::FromFile($p)
}

# The expanded sub-server row ("...(Non-PVP) Conectar") is drawn in bright
# yellow text; when the group is collapsed that band is just sky.
function Test-MuSubServerRow {
    param([IntPtr]$H)
    $bmp = Get-MuShot $H
    if (-not $bmp) { return $false }
    try {
        $r = New-Object MuUI+RECT; [MuUI]::GetClientRect($H, [ref]$r) | Out-Null
        $n = 0
        for ($y = [int]($r.B * 0.410); $y -lt [int]($r.B * 0.430); $y += 2) {
            for ($x = [int]($r.R * 0.425); $x -lt [int]($r.R * 0.582); $x += 2) {
                $c = $bmp.GetPixel($x, $y)
                if ($c.R -gt 200 -and $c.G -gt 200 -and $c.B -lt 170) { $n++ }
            }
        }
        return ($n -gt 12)
    } finally { $bmp.Dispose() }
}

# The login dialog's frame is neutral grey; the scene behind it never is.
function Test-MuLoginDialog {
    param([IntPtr]$H)
    $bmp = Get-MuShot $H
    if (-not $bmp) { return $false }
    try {
        $r = New-Object MuUI+RECT; [MuUI]::GetClientRect($H, [ref]$r) | Out-Null
        foreach ($fx in 0.406, 0.500) {
            $c = $bmp.GetPixel([int]($r.R * $fx), [int]($r.B * 0.684))
            $b = ($c.R + $c.G + $c.B) / 3
            if ([Math]::Abs($c.R - $c.G) -lt 8 -and [Math]::Abs($c.G - $c.B) -lt 8 -and $b -gt 25 -and $b -lt 95) { return $true }
        }
        return $false
    } finally { $bmp.Dispose() }
}

# The chat frame's scrollbar column is a bright tan strip; the 3D view is not.
function Test-MuChatVisible {
    param([IntPtr]$H)
    $bmp = Get-MuShot $H
    if (-not $bmp) { return $false }
    try {
        $r = New-Object MuUI+RECT; [MuUI]::GetClientRect($H, [ref]$r) | Out-Null
        $n = 0; $tot = 0
        for ($y = [int]($r.B * 0.625); $y -lt [int]($r.B * 0.879); $y += 2) {
            for ($x = [int]($r.R * 0.677); $x -lt [int]($r.R * 0.695); $x += 2) {
                $c = $bmp.GetPixel($x, $y); $tot++
                if ($c.R -gt 150 -and $c.G -gt 140 -and $c.B -gt 90 -and [Math]::Abs($c.R - $c.G) -lt 40) { $n++ }
            }
        }
        if ($tot -eq 0) { return $false }
        return (($n / $tot) -gt 0.04)
    } finally { $bmp.Dispose() }
}

function Hide-MuChat {
    param([IntPtr]$H)
    # F4 cycles hidden -> small -> medium -> full and the size is never saved.
    for ($i = 0; $i -lt 4; $i++) {
        if (-not (Test-MuChatVisible $H)) { return }
        [MuUI]::Key(0x73); Start-Sleep -Milliseconds 900
    }
}

# GameServer keeps the player object for a while after the socket closes, so a
# login too soon after killing the client is answered with "disconnected".
function Wait-MuAccountFree {
    param([string]$Account = 'test', [int]$TimeoutSec = 45)
    $cs = "Server=.\SQLEXPRESS;Database=MuOnline;Integrated Security=True"
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
            $cmd = $cn.CreateCommand()
            $cmd.CommandText = "SELECT ISNULL(ConnectStat,0) FROM MEMB_STAT WHERE memb___id=@a"
            [void]$cmd.Parameters.AddWithValue('@a', $Account)
            $v = $cmd.ExecuteScalar(); $cn.Close()
            if ([int]$v -eq 0) { return $true }
        } catch { }
        Start-Sleep -Seconds 5
    }
    # Killing the client leaves JoinServer thinking the account is still online,
    # and the next login is answered with "Você foi desconectado do servidor".
    # Clearing the flag directly is the usual fix for a stuck account.
    try {
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = "UPDATE MEMB_STAT SET ConnectStat=0 WHERE memb___id=@a"
        [void]$cmd.Parameters.AddWithValue('@a', $Account)
        [void]$cmd.ExecuteNonQuery(); $cn.Close()
        Write-Host "cleared stale online flag for '$Account'" -ForegroundColor Yellow
        return $true
    } catch { return $false }
}

# "Você foi desconectado do servidor" - a grey box ABOVE the login form.
# Distinguishes a refused login from a working one.
function Test-MuDisconnectDialog {
    param([IntPtr]$H)
    $bmp = Get-MuShot $H
    if (-not $bmp) { return $false }
    try {
        $r = New-Object MuUI+RECT; [MuUI]::GetClientRect($H, [ref]$r) | Out-Null
        $n = 0; $tot = 0
        for ($y = [int]($r.B * 0.465); $y -lt [int]($r.B * 0.52); $y += 3) {
            for ($x = [int]($r.R * 0.40); $x -lt [int]($r.R * 0.60); $x += 3) {
                $c = $bmp.GetPixel($x, $y); $tot++
                $b = ($c.R + $c.G + $c.B) / 3
                if ([Math]::Abs($c.R - $c.G) -lt 10 -and [Math]::Abs($c.G - $c.B) -lt 10 -and $b -gt 25 -and $b -lt 110) { $n++ }
            }
        }
        if ($tot -eq 0) { return $false }
        return (($n / $tot) -gt 0.6)
    } finally { $bmp.Dispose() }
}

# Full path from title screen to in-game. Hit-boxes move with the client
# resolution, so coordinates are per-resolution; each step is verified with a
# pixel probe and retried, because the server-list rows swallow single clicks.
function Enter-MuWorld {
    param(
        [string]$User = 'test',
        [string]$Pass = 'test123',
        [int]$WaitWorld = 16,
        [switch]$HideChat
    )
    $h = Get-MuWindow
    if (-not $h) { throw "MU window not found" }
    [MuUI]::Pin($h, $true); [MuUI]::Focus($h); Start-Sleep -Seconds 2

    $r = New-Object MuUI+RECT; [MuUI]::GetClientRect($h, [ref]$r) | Out-Null
    $c = switch ("$($r.R)x$($r.B)") {
        '1280x1024' { @{ Group = @(458, 428); Sub = @(660, 431); Acct = @(660, 620); Ok = @(652, 712); Slot = @(245, 700); Connect = @(1183, 927) } }
        '1024x768'  { @{ Group = @(330, 298); Sub = @(505, 299); Acct = @(532, 465); Ok = @(523, 541); Slot = @(195, 540); Connect = @(915, 684) } }
        '800x600'   { @{ Group = @(218, 217); Sub = @(400, 216); Acct = @(420, 352); Ok = @(411, 428); Slot = @(155, 420); Connect = @(695, 526) } }
        default     { throw "no UI coordinates for $($r.R)x$($r.B) - add them (see SESSION-HANDOFF.md)" }
    }

    Wait-MuAccountFree -Account $User | Out-Null
    Wait-MuServerIdle | Out-Null            # GameServer must have dropped the old session

    # expand the server group
    for ($i = 0; $i -lt 4; $i++) {
        if (Test-MuSubServerRow $h) { break }
        [MuUI]::ClickSync($h, $c.Group[0], $c.Group[1]); Start-Sleep -Seconds 3
    }
    if (-not (Test-MuSubServerRow $h)) { throw "server group would not expand" }

    # pick the sub-server -> login dialog
    for ($i = 0; $i -lt 4; $i++) {
        if (Test-MuLoginDialog $h) { break }
        [MuUI]::ClickSync($h, $c.Sub[0], $c.Sub[1]); Start-Sleep -Seconds 4
    }
    if (-not (Test-MuLoginDialog $h)) { throw "login dialog would not open" }

    [MuUI]::ClickSync($h, $c.Acct[0], $c.Acct[1]); Start-Sleep -Milliseconds 500
    for ($i = 0; $i -lt 12; $i++) { [MuUI]::Key(0x08) }
    [MuUI]::TypeText($User)
    [MuUI]::Key(0x09); Start-Sleep -Milliseconds 400
    for ($i = 0; $i -lt 12; $i++) { [MuUI]::Key(0x08) }
    [MuUI]::TypeText($Pass)
    [MuUI]::Key(0x0D); Start-Sleep -Seconds 3
    [MuUI]::ClickSync($h, $c.Ok[0], $c.Ok[1]); Start-Sleep -Seconds 8

    if (Test-MuDisconnectDialog $h) {
        throw "server refused the login ('desconectado') - account still registered as online"
    }

    [MuUI]::ClickSync($h, $c.Slot[0], $c.Slot[1]); Start-Sleep -Seconds 3
    [MuUI]::ClickSync($h, $c.Connect[0], $c.Connect[1]); Start-Sleep -Seconds $WaitWorld

    if ($HideChat) { Hide-MuChat $h }
    return $h
}

# GameServer's window title carries its live player count, e.g.
# "[PREMIUM] MuEMU (PlayerCount : 1/1000) (MonsterCount : 4150/8000)".
# MEMB_STAT clears before GameServer drops the player object, so a login can
# still be answered with "disconnected"; this is the reliable signal.
function Get-MuServerPlayerCount {
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    $p = Get-Process GameServer -ErrorAction SilentlyContinue
    if (-not $p) { return -1 }
    $t = $p.MainWindowTitle
    if ($t -match 'PlayerCount\s*:\s*(\d+)') { return [int]$Matches[1] }
    return -1
}

function Wait-MuServerIdle {
    param([int]$TimeoutSec = 150)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $n = Get-MuServerPlayerCount
        if ($n -le 0) { return $true }
        Start-Sleep -Seconds 5
    }
    return $false
}
