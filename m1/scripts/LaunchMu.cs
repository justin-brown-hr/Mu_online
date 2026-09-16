using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

class LaunchMu {
  const uint PROCESS_ALL_ACCESS = 0x1F0FFF;
  const uint MEM_COMMIT = 0x1000, MEM_RESERVE = 0x2000, PAGE_READWRITE = 4;
  [DllImport("kernel32", SetLastError=true)] static extern IntPtr OpenProcess(uint a, bool b, int c);
  [DllImport("kernel32", SetLastError=true)] static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
  [DllImport("kernel32", SetLastError=true)] static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint s, out uint w);
  [DllImport("kernel32", SetLastError=true)] static extern IntPtr GetProcAddress(IntPtr h, string n);
  [DllImport("kernel32", SetLastError=true)] static extern IntPtr GetModuleHandle(string n);
  [DllImport("kernel32", SetLastError=true)] static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr a, uint s, IntPtr start, IntPtr p, uint f, out uint id);
  [DllImport("kernel32", SetLastError=true)] static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32", SetLastError=true)] static extern bool CloseHandle(IntPtr h);

  static bool Inject(int pid, string dllPath) {
    IntPtr h = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
    if (h == IntPtr.Zero) { Console.WriteLine("OpenProcess err=" + Marshal.GetLastWin32Error()); return false; }
    byte[] path = Encoding.ASCII.GetBytes(dllPath + "\0");
    IntPtr mem = VirtualAllocEx(h, IntPtr.Zero, (uint)path.Length, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (mem == IntPtr.Zero) { Console.WriteLine("VirtualAllocEx err=" + Marshal.GetLastWin32Error()); CloseHandle(h); return false; }
    uint written;
    WriteProcessMemory(h, mem, path, (uint)path.Length, out written);
    IntPtr load = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
    uint tid;
    IntPtr th = CreateRemoteThread(h, IntPtr.Zero, 0, load, mem, 0, out tid);
    if (th == IntPtr.Zero) { Console.WriteLine("CreateRemoteThread err=" + Marshal.GetLastWin32Error()); CloseHandle(h); return false; }
    WaitForSingleObject(th, 15000);
    CloseHandle(th); CloseHandle(h);
    return true;
  }

  static int Main() {
    string dir = Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName);
    string exe = Path.Combine(dir, "main.exe");
    string dll = Path.Combine(dir, "Main.dll");
    if (!File.Exists(exe) || !File.Exists(dll)) { Console.WriteLine("Need main.exe + Main.dll beside LaunchMu.exe"); return 1; }
    // Ensure Release CRT Main.dll
    Console.WriteLine("Starting " + exe);
    var p = Process.Start(new ProcessStartInfo(exe) { WorkingDirectory = dir });
    // Wait for ASPack unpack + window
    for (int i = 0; i < 40; i++) {
      Thread.Sleep(500);
      p.Refresh();
      if (p.HasExited) { Console.WriteLine("main exited early"); return 3; }
      if (p.MainWindowHandle != IntPtr.Zero) break;
    }
    Thread.Sleep(2000); // unpack settle
    Console.WriteLine("Injecting Main.dll into PID " + p.Id);
    bool ok = Inject(p.Id, dll);
    Console.WriteLine(ok ? "Inject OK ? Main.dll EntryProc should patch live IP/serial" : "Inject FAILED");
    // Verify module loaded
    Thread.Sleep(1000);
    try {
      foreach (ProcessModule m in Process.GetProcessById(p.Id).Modules) {
        if (m.ModuleName.Equals("Main.dll", StringComparison.OrdinalIgnoreCase)) {
          Console.WriteLine("Confirmed loaded: " + m.FileName);
          return 0;
        }
      }
      Console.WriteLine("Main.dll NOT in module list");
      return 4;
    } catch (Exception ex) { Console.WriteLine(ex.Message); return 5; }
  }
}
