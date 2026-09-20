# Rebuild GameServer (Release, VS2022 v143 toolset) and hot-swap it.
# The project targets v142 (VS2019); only VS2022 Build Tools are installed,
# so the toolset is overridden on the command line.
# Stops the MU client (it would be disconnected anyway) and GameServer,
# keeps a one-time backup GameServer.exe.pre-m1move, then restarts GS.

$ErrorActionPreference = 'Stop'
$root  = "C:\work\Mu_online\m1\host\Server\xMuPP-src"
$sln   = "$root\Source\Server Side\"
$proj  = "$sln\GameServer\GameServer.vcxproj"
$built = "$sln\GameServer\Build\Release\GameServer.exe"
$gsDir = "$root\Server Files\GameServer"
$mb    = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"

$before = (Get-Item $built -ErrorAction SilentlyContinue).LastWriteTime
# Post-build copy fails while GS runs; we copy ourselves below.
$out = & $mb $proj /p:Configuration=Release /p:Platform=Win32 /p:PlatformToolset=v143 "/p:SolutionDir=$sln\" /m /nologo /v:minimal 2>&1
$errors = $out | Where-Object { $_ -match ' error C| error LNK' }
if ($errors) { $errors | Select-Object -First 10; throw "GameServer build failed" }
if ((Get-Item $built).LastWriteTime -eq $before) { Write-Host "(no changes compiled)" }

Get-Process main -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process GameServer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
if (-not (Test-Path "$gsDir\GameServer.exe.pre-m1move")) {
    Copy-Item "$gsDir\GameServer.exe" "$gsDir\GameServer.exe.pre-m1move"
}
Copy-Item $built "$gsDir\GameServer.exe" -Force
Start-Process -FilePath "$gsDir\GameServer.exe" -WorkingDirectory $gsDir
Start-Sleep -Seconds 25
$gs = Get-Process GameServer -ErrorAction SilentlyContinue
if (-not $gs) { throw "GameServer did not stay up" }
Write-Host "GameServer rebuilt and running (pid $($gs.Id))" -ForegroundColor Green
