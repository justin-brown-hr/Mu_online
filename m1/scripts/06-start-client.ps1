# Start the MU Season 2 client on this VPS (no GPU required).
#
# Rendering: MU 1.02c is an OpenGL game (wglCreateContext/glu32) - NOT DirectX.
# Mesa3D llvmpipe (opengl32.dll + libgallium_wgl.dll in the client folder)
# provides software OpenGL, so a discrete GPU / RDP 3D adapter is not needed.
#
# Requirements already applied to play-safe\main.exe:
#   * PE AddressOfEntryPoint repointed 0x0845C200 -> 0x084569E9
#     (skips the SuZaNa "CLtDLL.dll" LibHook loader stub)
#   * hack.dll MUST be present - the entry stub does
#     LoadLibraryA("hack.dll") / GetProcAddress("Inicio") / call eax,
#     and its failure branch is "jz 0x00000000" (jumps to NULL).
#   * dgVoodoo D3D8/D3D9/DDraw wrappers must NOT be in the folder
#     (they hijack DDraw and crash Mesa). Kept in _dgvoodoo-disabled\.

param(
    [string]$ClientDir = "C:\work\Mu_online\m1\host\Client\play-safe",
    [switch]$Restart
)

$ErrorActionPreference = 'Stop'

if ($Restart) {
    Get-Process main -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# --- preflight -------------------------------------------------------------
$exe = Join-Path $ClientDir 'main.exe'
if (-not (Test-Path $exe)) { throw "main.exe not found in $ClientDir" }

$required = @('hack.dll', 'opengl32.dll', 'libgallium_wgl.dll', 'Main.dll')
foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $ClientDir $f))) {
        throw "MISSING required file: $f  (client will crash without it)"
    }
}

$mustNotExist = @('D3D8.dll', 'D3D9.dll', 'D3DImm.dll', 'DDraw.dll')
foreach ($f in $mustNotExist) {
    if (Test-Path (Join-Path $ClientDir $f)) {
        throw "dgVoodoo wrapper present: $f - move it to _dgvoodoo-disabled\ first"
    }
}

# Verify the entry point is the patched one, not the SuZaNa LibHook stub.
$b     = [IO.File]::ReadAllBytes($exe)
$peOff = [BitConverter]::ToUInt32($b, 0x3c)
$ep    = [BitConverter]::ToUInt32($b, $peOff + 4 + 20 + 16)
if ($ep -ne 0x084569E9) {
    throw ("main.exe AddressOfEntryPoint is 0x{0:X8}, expected 0x084569E9 - re-apply the entry-point patch" -f $ep)
}
Write-Host ("preflight OK  (entry point 0x{0:X8}, hack.dll present, no dgVoodoo)" -f $ep) -ForegroundColor Green

# --- software OpenGL -------------------------------------------------------
$env:GALLIUM_DRIVER           = 'llvmpipe'
$env:LIBGL_ALWAYS_SOFTWARE    = '1'
$env:MESA_GL_VERSION_OVERRIDE = '2.1'

$p = Start-Process -FilePath $exe -WorkingDirectory $ClientDir -PassThru
Write-Host "launched main.exe pid=$($p.Id)" -ForegroundColor Cyan

Start-Sleep -Seconds 20
$p.Refresh()
if ($p.HasExited) {
    Write-Warning "client exited early, code=$($p.ExitCode)"
    exit 1
}

Write-Host ("ALIVE  threads={0}  ws={1}MB" -f $p.Threads.Count, [int]($p.WorkingSet64 / 1MB)) -ForegroundColor Green
$conn = Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Established' }
if ($conn) {
    $conn | Select-Object LocalPort, RemoteAddress, RemotePort, State | Format-Table -AutoSize
} else {
    Write-Warning "no established TCP connection yet - check ConnectServer is running (05-probe-cs.ps1)"
}
