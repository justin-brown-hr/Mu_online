using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

// Minimal Win32 debugger for main.exe: logs module loads, thread starts
// (incl. NULL start addresses), debug strings and exceptions with a
// module-resolved stack walk.
class MuTrace
{
    const uint DEBUG_ONLY_THIS_PROCESS = 0x00000002;
    const uint CREATE_NEW_CONSOLE = 0x00000010;
    const uint DBG_CONTINUE = 0x00010002;
    const uint DBG_EXCEPTION_NOT_HANDLED = 0x80010001;
    const uint INFINITE = 0xFFFFFFFF;

    [StructLayout(LayoutKind.Sequential)]
    struct STARTUPINFO { public int cb; public string a, b, c; public int dx, dy, xs, ys, xc, yc, fill, flags; public short sw, cbR; public IntPtr lpR, hIn, hOut, hErr; }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public uint dwProcessId, dwThreadId; }
    [StructLayout(LayoutKind.Sequential)]
    struct MODULEINFO { public IntPtr lpBaseOfDll; public uint SizeOfImage; public IntPtr EntryPoint; }

    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Ansi)]
    static extern bool CreateProcess(string app, string cmd, IntPtr pa, IntPtr ta, bool inh, uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32", SetLastError = true)] static extern bool WaitForDebugEvent(IntPtr ev, uint ms);
    [DllImport("kernel32", SetLastError = true)] static extern bool ContinueDebugEvent(uint pid, uint tid, uint status);
    [DllImport("kernel32", SetLastError = true)] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, uint size, out uint read);
    [DllImport("kernel32", SetLastError = true)] static extern bool GetThreadContext(IntPtr h, byte[] ctx);
    [DllImport("kernel32", SetLastError = true)] static extern uint GetFinalPathNameByHandle(IntPtr h, StringBuilder sb, uint len, uint flags);
    [DllImport("kernel32", SetLastError = true)] static extern bool TerminateProcess(IntPtr h, uint code);
    [DllImport("kernel32", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
    [DllImport("psapi", SetLastError = true)] static extern bool EnumProcessModules(IntPtr h, IntPtr[] mods, uint cb, out uint needed);
    [DllImport("psapi", SetLastError = true)] static extern bool GetModuleInformation(IntPtr h, IntPtr mod, out MODULEINFO mi, uint cb);
    [DllImport("psapi", SetLastError = true, CharSet = CharSet.Ansi)] static extern uint GetModuleBaseName(IntPtr h, IntPtr mod, StringBuilder sb, uint size);

    static DateTime t0 = DateTime.Now;
    static void L(string s) { Console.WriteLine("[{0,7:0.000}] {1}", (DateTime.Now - t0).TotalSeconds, s); }

    static Dictionary<uint, IntPtr> threads = new Dictionary<uint, IntPtr>();
    static IntPtr hProc = IntPtr.Zero;

    static string NameOf(IntPtr h)
    {
        if (h == IntPtr.Zero) return "?";
        var sb = new StringBuilder(600);
        uint n = GetFinalPathNameByHandle(h, sb, 600, 0);
        if (n == 0) return "?";
        string s = sb.ToString();
        int i = s.LastIndexOf('\\');
        return i >= 0 ? s.Substring(i + 1) : s;
    }

    // Resolve an address to module!offset using the live module list.
    static string Resolve(uint addr)
    {
        if (addr == 0) return "NULL";
        IntPtr[] mods = new IntPtr[512]; uint need;
        if (!EnumProcessModules(hProc, mods, (uint)(mods.Length * IntPtr.Size), out need)) return "0x" + addr.ToString("X8");
        int count = (int)(need / IntPtr.Size);
        for (int i = 0; i < count && i < mods.Length; i++)
        {
            MODULEINFO mi;
            if (!GetModuleInformation(hProc, mods[i], out mi, (uint)Marshal.SizeOf(typeof(MODULEINFO)))) continue;
            uint b = (uint)mi.lpBaseOfDll.ToInt64();
            if (addr >= b && addr < b + mi.SizeOfImage)
            {
                var sb = new StringBuilder(260);
                GetModuleBaseName(hProc, mods[i], sb, 260);
                return string.Format("{0}+0x{1:X}", sb, addr - b);
            }
        }
        return "0x" + addr.ToString("X8") + " (unmapped/heap)";
    }

    static void Main(string[] argv)
    {
        string exe = argv.Length > 0 ? argv[0] : @"C:\work\Mu_online\m1\host\Client\play-safe\main.exe";
        string dir = exe.Substring(0, exe.LastIndexOf('\\'));
        var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
        PROCESS_INFORMATION pi;
        if (!CreateProcess(exe, "\"" + exe + "\"", IntPtr.Zero, IntPtr.Zero, false,
                           DEBUG_ONLY_THIS_PROCESS | CREATE_NEW_CONSOLE, IntPtr.Zero, dir, ref si, out pi))
        { L("CreateProcess failed " + Marshal.GetLastWin32Error()); return; }
        L("started pid=" + pi.dwProcessId);

        IntPtr ev = Marshal.AllocHGlobal(256);
        int exceptions = 0;
        bool running = true;
        while (running)
        {
            if (!WaitForDebugEvent(ev, 60000)) { L("WaitForDebugEvent timeout/err"); break; }
            uint code = (uint)Marshal.ReadInt32(ev, 0);
            uint pid = (uint)Marshal.ReadInt32(ev, 4);
            uint tid = (uint)Marshal.ReadInt32(ev, 8);
            uint cont = DBG_CONTINUE;

            switch (code)
            {
                case 3: // CREATE_PROCESS
                {
                    hProc = (IntPtr)Marshal.ReadInt32(ev, 12 + 4);
                    IntPtr hThr = (IntPtr)Marshal.ReadInt32(ev, 12 + 8);
                    uint baseImg = (uint)Marshal.ReadInt32(ev, 12 + 12);
                    uint start = (uint)Marshal.ReadInt32(ev, 12 + 28);
                    threads[tid] = hThr;
                    L(string.Format("PROCESS base=0x{0:X8} mainThreadStart=0x{1:X8} tid={2}", baseImg, start, tid));
                    break;
                }
                case 6: // LOAD_DLL
                {
                    IntPtr hFile = (IntPtr)Marshal.ReadInt32(ev, 12 + 0);
                    uint b = (uint)Marshal.ReadInt32(ev, 12 + 4);
                    L(string.Format("LOAD  0x{0:X8}  {1}", b, NameOf(hFile)));
                    if (hFile != IntPtr.Zero) CloseHandle(hFile);
                    break;
                }
                case 7:
                    L(string.Format("UNLOAD 0x{0:X8}", (uint)Marshal.ReadInt32(ev, 12)));
                    break;
                case 2: // CREATE_THREAD
                {
                    IntPtr hThr = (IntPtr)Marshal.ReadInt32(ev, 12 + 0);
                    uint start = (uint)Marshal.ReadInt32(ev, 12 + 8);
                    threads[tid] = hThr;
                    L(string.Format("THREAD tid={0} start=0x{1:X8} {2}{3}", tid, start, Resolve(start),
                        start == 0 ? "   <<<<<< NULL START ADDRESS" : ""));
                    break;
                }
                case 4:
                    threads.Remove(tid);
                    break;
                case 8: // OUTPUT_DEBUG_STRING
                {
                    uint p = (uint)Marshal.ReadInt32(ev, 12 + 0);
                    ushort isUni = (ushort)Marshal.ReadInt16(ev, 12 + 4);
                    ushort len = (ushort)Marshal.ReadInt16(ev, 12 + 6);
                    byte[] buf = new byte[Math.Min((int)len, 1024)]; uint rd;
                    if (ReadProcessMemory(hProc, (IntPtr)p, buf, (uint)buf.Length, out rd))
                        L("DBGSTR " + (isUni != 0 ? Encoding.Unicode.GetString(buf, 0, (int)rd) : Encoding.ASCII.GetString(buf, 0, (int)rd)).TrimEnd('\0', '\r', '\n'));
                    break;
                }
                case 5: // EXIT_PROCESS
                    L("EXIT_PROCESS code=0x" + ((uint)Marshal.ReadInt32(ev, 12)).ToString("X8"));
                    running = false;
                    break;
                case 1: // EXCEPTION
                {
                    uint exCode = (uint)Marshal.ReadInt32(ev, 12 + 0);
                    uint exAddr = (uint)Marshal.ReadInt32(ev, 12 + 12);
                    uint nParm = (uint)Marshal.ReadInt32(ev, 12 + 16);
                    uint p0 = (uint)Marshal.ReadInt32(ev, 12 + 20);
                    uint p1 = (uint)Marshal.ReadInt32(ev, 12 + 24);
                    uint firstChance = (uint)Marshal.ReadInt32(ev, 12 + 80);
                    if (exCode == 0x80000003 && exceptions == 0) { exceptions++; cont = DBG_CONTINUE; break; } // initial bp
                    string kind = exCode == 0xC0000005
                        ? string.Format("ACCESS_VIOLATION {0} at 0x{1:X8}", p0 == 0 ? "reading" : (p0 == 1 ? "writing" : "EXECUTING"), p1)
                        : "0x" + exCode.ToString("X8");
                    L(string.Format("EXCEPTION {0} at 0x{1:X8} [{2}] tid={3} firstChance={4}",
                        kind, exAddr, Resolve(exAddr), tid, firstChance));

                    if (firstChance == 0 || exCode == 0xC0000005)
                    {
                        // Dump context + stack for the faulting thread
                        IntPtr hThr;
                        if (threads.TryGetValue(tid, out hThr))
                        {
                            byte[] ctx = new byte[716];
                            BitConverter.GetBytes((uint)0x10007).CopyTo(ctx, 0); // CONTEXT_FULL
                            if (GetThreadContext(hThr, ctx))
                            {
                                uint edi = BitConverter.ToUInt32(ctx, 156), esi = BitConverter.ToUInt32(ctx, 160);
                                uint ebx = BitConverter.ToUInt32(ctx, 164), edx = BitConverter.ToUInt32(ctx, 168);
                                uint ecx = BitConverter.ToUInt32(ctx, 172), eax = BitConverter.ToUInt32(ctx, 176);
                                uint ebp = BitConverter.ToUInt32(ctx, 180), eip = BitConverter.ToUInt32(ctx, 184);
                                uint esp = BitConverter.ToUInt32(ctx, 196);
                                L(string.Format("  eip={0:X8} esp={1:X8} ebp={2:X8} eax={3:X8} ebx={4:X8} ecx={5:X8} edx={6:X8} esi={7:X8} edi={8:X8}",
                                    eip, esp, ebp, eax, ebx, ecx, edx, esi, edi));
                                L("  esi -> " + Resolve(esi));
                                byte[] stk = new byte[256]; uint rd;
                                if (ReadProcessMemory(hProc, (IntPtr)esp, stk, 256, out rd))
                                    for (int i = 0; i < rd / 4 && i < 20; i++)
                                    {
                                        uint v = BitConverter.ToUInt32(stk, i * 4);
                                        string r = Resolve(v);
                                        if (!r.Contains("unmapped") && r != "NULL")
                                            L(string.Format("  stack[+{0,2}] 0x{1:X8}  {2}", i * 4, v, r));
                                    }
                            }
                        }
                        if (firstChance == 0) { L("  -> second chance, terminating"); TerminateProcess(hProc, 1); }
                    }
                    cont = DBG_EXCEPTION_NOT_HANDLED;
                    break;
                }
            }
            ContinueDebugEvent(pid, tid, cont);
        }
        L("done");
    }
}
