# Record the MU client window on this VPS with ffmpeg (gdigrab).
#
#   07-record.ps1 -Start              # begins recording the MU window region
#   07-record.ps1 -Stop               # stops and remuxes to MP4
#
# Records to MKV first (safe if ffmpeg is killed), then remuxes to MP4.
# Captures the window's screen rectangle from the desktop - OpenGL windows
# often capture black when grabbed by window title.

param(
    [switch]$Start,
    [switch]$Stop,
    [string]$OutDir = "C:\work\Mu_online\m1\evidence",
    [int]$Fps = 30,
    # Lower CRF = better picture, bigger file. 18 is visually near-lossless
    # for this content; 26 (the old default) left the textures looking soft.
    [int]$Crf = 18
)

$ffmpeg = "C:\tools\ffmpeg\ffmpeg.exe"
$state  = Join-Path $OutDir ".recording"

if ($Start) {
    . "$PSScriptRoot\MuUI.ps1"
    $h = Get-MuWindow
    if (-not $h) { throw "MU window not found - start the client first (06-start-client.ps1)" }
    [MuUI]::Focus($h)

    $r = New-Object MuUI+RECT; [MuUI]::GetClientRect($h, [ref]$r) | Out-Null
    $o = New-Object MuUI+POINT; [MuUI]::ClientToScreen($h, [ref]$o) | Out-Null
    $w = $r.R - ($r.R % 2); $ht = $r.B - ($r.B % 2)   # x264 needs even sizes

    $name = "m1-run-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    $mkv  = Join-Path $OutDir "$name.mkv"
    $args = @('-hide_banner', '-loglevel', 'error', '-y',
              '-f', 'gdigrab', '-framerate', $Fps,
              '-offset_x', $o.X, '-offset_y', $o.Y, '-video_size', "${w}x${ht}",
              '-draw_mouse', '1', '-i', 'desktop',
              '-c:v', 'libx264', '-preset', 'veryfast', '-crf', $Crf,
              '-pix_fmt', 'yuv420p', '-tune', 'stillimage',
              $mkv)
    # Screen capture needs a rendering desktop: if the RDP window on the
    # operator's PC is minimised, the session stops rendering and gdigrab
    # fails with "error 5". Fail loudly instead of writing an empty file.
    $probe = Join-Path $env:TEMP "m1-capture-probe.png"
    Remove-Item $probe -ErrorAction SilentlyContinue
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $ffmpeg -hide_banner -loglevel error -y -f gdigrab -framerate 5 `
              -offset_x $o.X -offset_y $o.Y -video_size "32x32" -i desktop `
              -frames:v 1 $probe | Out-Null
    $ErrorActionPreference = $prevEap
    if (-not (Test-Path $probe)) {
        throw "screen capture is unavailable (gdigrab error 5). Keep the RDP window open and NOT minimised on your PC, then retry."
    }
    Remove-Item $probe -ErrorAction SilentlyContinue

    $p = Start-Process -FilePath $ffmpeg -ArgumentList $args -WindowStyle Hidden -PassThru
    Set-Content $state "$($p.Id)`n$mkv"
    Write-Host "recording pid=$($p.Id) -> $mkv  (${w}x${ht} @ $($o.X),$($o.Y), $Fps fps, crf $Crf)"
}
elseif ($Stop) {
    if (-not (Test-Path $state)) { throw "no recording in progress" }
    $lines = Get-Content $state
    $procId = [int]$lines[0]; $mkv = $lines[1]
    Stop-Process -Id $procId -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item $state
    if (-not (Test-Path $mkv)) {
        # ffmpeg died on startup (usually capture became unavailable). Say so
        # instead of failing the whole run on the remux.
        Write-Warning "no recording was produced ($mkv missing) - screen capture was unavailable"
        return
    }
    $mp4 = [IO.Path]::ChangeExtension($mkv, ".mp4")
    # Stopping the MKV mid-write always leaves a truncated final cluster, so
    # ffmpeg warns "File ended prematurely" on stderr. It still remuxes fine.
    # In PowerShell 5.1 any stderr from a native exe becomes a NativeCommandError,
    # which is fatal when the caller uses ErrorActionPreference=Stop - and using
    # 2>&1 makes that worse, not better. So relax the preference around the call
    # and judge success by the exit code.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $ffmpeg -hide_banner -loglevel error -y -i $mkv -c copy -movflags +faststart $mp4
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($rc -ne 0) { Write-Warning "ffmpeg remux exit code $rc" }
    if (Test-Path $mp4) {
        Remove-Item $mkv
        $info = Get-Item $mp4
        Write-Host ("saved {0}  ({1:N1} MB)" -f $info.FullName, ($info.Length / 1MB))
    } else {
        Write-Warning "remux failed - raw recording kept at $mkv"
    }
}
else {
    Write-Host "usage: 07-record.ps1 -Start | -Stop"
}
