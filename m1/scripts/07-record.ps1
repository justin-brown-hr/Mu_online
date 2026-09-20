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
    [int]$Fps = 15
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
              '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '26', '-pix_fmt', 'yuv420p',
              $mkv)
    $p = Start-Process -FilePath $ffmpeg -ArgumentList $args -WindowStyle Hidden -PassThru
    Set-Content $state "$($p.Id)`n$mkv"
    Write-Host "recording pid=$($p.Id) -> $mkv  (${w}x${ht} @ $($o.X),$($o.Y), $Fps fps)"
}
elseif ($Stop) {
    if (-not (Test-Path $state)) { throw "no recording in progress" }
    $lines = Get-Content $state
    $procId = [int]$lines[0]; $mkv = $lines[1]
    Stop-Process -Id $procId -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item $state
    $mp4 = [IO.Path]::ChangeExtension($mkv, ".mp4")
    & $ffmpeg -hide_banner -loglevel error -y -i $mkv -c copy -movflags +faststart $mp4
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
