# One-pass M1 demo recording at 1280x1024:
#   title -> login -> Lorencia -> field -> combat -> relog -> back in game,
# joined into a single MP4.
#
# Runs start to finish with no operator input and a short, even click cadence,
# so the character keeps moving instead of standing still between steps.
#
# Recording is split at each world entry: the chat window always opens at full
# screen height (its frame looks like two long vertical lines) and the size is
# never saved, so we pause, hide it with F4, then resume.
#
# REQUIREMENT: the session must be drawing. On the console session that is
# always true; over RDP the window must stay open and NOT minimised, or
# gdigrab fails with "error 5".

param(
    [string]$OutDir = "C:\work\Mu_online\m1\evidence",
    [string]$User   = 'test',
    [string]$Pass   = 'test123',
    [int]   $StepMs = 1100          # gap between walk clicks
)

$ErrorActionPreference = 'Stop'
$scripts = $PSScriptRoot
. (Join-Path $scripts 'MuUI.ps1')

$ffmpeg = "C:\tools\ffmpeg\ffmpeg.exe"
$shots  = Join-Path $env:TEMP 'm1-demo-shots'
New-Item -ItemType Directory -Force $shots | Out-Null

Add-Type @'
using System;using System.Runtime.InteropServices;
public class DemoWin {
  [DllImport("user32")] public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int cx,int cy,uint f);
}
'@

function Assert-Capture {
    $probe = Join-Path $env:TEMP 'm1-cap-probe.png'
    Remove-Item $probe -ErrorAction SilentlyContinue
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & $ffmpeg -hide_banner -loglevel error -y -f gdigrab -framerate 5 `
        -offset_x 0 -offset_y 0 -video_size 64x64 -i desktop -frames:v 1 $probe | Out-Null
    $ErrorActionPreference = $prev
    if (-not (Test-Path $probe)) {
        throw "Screen capture unavailable (gdigrab error 5). The session is not drawing - open the RDP window and do not minimise it."
    }
}

function Start-Rec { & (Join-Path $scripts '07-record.ps1') -Start -OutDir $OutDir | Out-Null }
function Stop-Rec  { & (Join-Path $scripts '07-record.ps1') -Stop  -OutDir $OutDir | Out-Null }

# Walk by clicking an offset from the character, which is always screen centre.
function Walk { param([IntPtr]$H,[int]$Dx,[int]$Dy,[int]$Times)
    for ($i = 0; $i -lt $Times; $i++) {
        [MuUI]::Click($H, (640 + $Dx), (512 + $Dy))
        Start-Sleep -Milliseconds $StepMs
    }
}

# Attack whatever is adjacent: sweep a ring of points around the character.
# Aggressive monsters walk right up to us, so most of these land on one.
function Fight { param([IntPtr]$H,[int]$Rounds)
    $ring = @(@(-110,-40),@(-60,-80),@(60,-80),@(110,-40),@(120,40),@(60,90),@(-60,90),@(-120,40))
    for ($r = 0; $r -lt $Rounds; $r++) {
        foreach ($o in $ring) {
            [MuUI]::Click($H, (640 + $o[0]), (512 + $o[1]))
            Start-Sleep -Milliseconds 400
        }
    }
}

# ---------------------------------------------------------------- run --------
Assert-Capture
# A previous aborted run can leave an ffmpeg holding its .mkv open.
Get-Process ffmpeg -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Set-ItemProperty "HKCU:\Software\Webzen\Mu\Config" -Name Resolution -Value 3   # 1280x1024
Get-ChildItem (Join-Path $OutDir 'm1-run-*.mp4'), (Join-Path $OutDir 'm1-run-*.mkv') -ErrorAction SilentlyContinue | Remove-Item -Force
Remove-Item (Join-Path $OutDir '.recording') -ErrorAction SilentlyContinue

& (Join-Path $scripts '06-start-client.ps1') -Restart | Out-Null
$h = Get-MuWindow
if (-not $h) { throw "client window not found" }
[DemoWin]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, 0, 0, (0x0001 -bor 0x0004)) | Out-Null   # move to 0,0
[MuUI]::Pin($h, $true); [MuUI]::Focus($h); Start-Sleep 2

# --- segment 1: title -> login -> character select ---------------------------
# Enter-MuWorld waits for the server to release the account, expands the server
# group and opens the login dialog with pixel-verified retries.
Write-Host "segment 1: login" -ForegroundColor Cyan
Start-Rec
Start-Sleep 3
$h = Enter-MuWorld -User $User -Pass $Pass -WaitWorld 16
[MuUI]::Shot($h, (Join-Path $shots '1-inworld.png')) | Out-Null
Stop-Rec

# Hide the chat between segments so its frame never appears in the video.
Hide-MuChat $h
[MuUI]::Shot($h, (Join-Path $shots '2-chathidden.png')) | Out-Null

# --- segment 2: town -> field -> combat -> relog -----------------------------
Write-Host "segment 2: gameplay" -ForegroundColor Cyan
Start-Rec
Start-Sleep 2
Walk $h  256  218 5      # east through town
Walk $h  460   48 4      # toward the east gate
Walk $h  260  130 12     # across the bridge into the green field
[MuUI]::Shot($h, (Join-Path $shots '3-field.png')) | Out-Null
Fight $h 3               # monsters come to us
Walk $h  260  130 3
Fight $h 3
Walk $h -260 -130 3
Fight $h 2
[MuUI]::Shot($h, (Join-Path $shots '4-afterfight.png')) | Out-Null
[MuUI]::MoveTo($h, 1250, 30); Start-Sleep 2
[MuUI]::Key(0x1B); Start-Sleep 2                           # Esc menu
[MuUI]::Shot($h, (Join-Path $shots '5-menu.png')) | Out-Null
[MuUI]::Click($h, 640, 273); Start-Sleep 12                # "Trocar de personagem"
[MuUI]::Shot($h, (Join-Path $shots '6-charselect.png')) | Out-Null
[MuUI]::Click($h, 245, 700); Start-Sleep 3                 # pick the character
Stop-Rec

# --- re-enter, hide chat, short closing segment ------------------------------
[MuUI]::Click($h, 1183, 927); Start-Sleep 16               # Connect
Hide-MuChat $h
Write-Host "segment 3: back in game" -ForegroundColor Cyan
Start-Rec
Start-Sleep 2
Walk $h  200  120 3
Walk $h -200  -60 2
[MuUI]::MoveTo($h, 1250, 30); Start-Sleep 2
[MuUI]::Shot($h, (Join-Path $shots '7-final.png')) | Out-Null
Stop-Rec
[MuUI]::Pin($h, $false)

# --- join the segments ------------------------------------------------------
$parts = @(Get-ChildItem (Join-Path $OutDir 'm1-run-*.mp4') | Sort-Object Name)
if ($parts.Count -eq 0) { throw "no recorded segments" }
$list = Join-Path $OutDir 'concat.txt'
($parts | ForEach-Object { "file '" + ($_.FullName.Replace('\', '/')) + "'" }) | Set-Content -Encoding ascii $list
$final = Join-Path $OutDir 'M1-full-run.mp4'
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i $list -c copy -movflags +faststart $final
$ErrorActionPreference = $prev
Remove-Item $list -Force
$parts | Remove-Item -Force

$info = Get-Item $final
Write-Host ("DONE: {0}  ({1:N1} MB)" -f $info.FullName, ($info.Length / 1MB)) -ForegroundColor Green
Write-Host ("step screenshots: {0}" -f $shots)
