using System;
using System.Runtime.InteropServices;

// Switch current thread to MuM1Desktop so you can see the game window.
class SwitchMuDesktop {
  [DllImport("user32", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern IntPtr OpenDesktop(string name, int flags, bool inherit, uint access);
  [DllImport("user32", SetLastError = true)] static extern bool SetThreadDesktop(IntPtr h);
  [DllImport("user32", SetLastError = true)] static extern bool SwitchDesktop(IntPtr h);
  [DllImport("user32")] static extern bool CloseDesktop(IntPtr h);
  const uint DESKTOP_ALL = 0x1FF;

  static int Main(string[] args) {
    string name = args.Length > 0 ? args[0] : "MuM1Desktop";
    IntPtr d = OpenDesktop(name, 0, false, DESKTOP_ALL);
    if (d == IntPtr.Zero) {
      Console.WriteLine("OpenDesktop(" + name + ") err=" + Marshal.GetLastWin32Error());
      return 1;
    }
    if (!SetThreadDesktop(d)) Console.WriteLine("SetThreadDesktop err=" + Marshal.GetLastWin32Error());
    if (!SwitchDesktop(d)) {
      Console.WriteLine("SwitchDesktop err=" + Marshal.GetLastWin32Error() + " (need interactive session rights)");
      Console.WriteLine("Desktop opened — windows on " + name + " exist; SwitchDesktop may require Winlogon.");
    } else {
      Console.WriteLine("Switched to " + name + ". Press Enter to return to Default...");
      Console.ReadLine();
      IntPtr def = OpenDesktop("Default", 0, false, DESKTOP_ALL);
      if (def != IntPtr.Zero) { SwitchDesktop(def); CloseDesktop(def); }
    }
    CloseDesktop(d);
    return 0;
  }
}
