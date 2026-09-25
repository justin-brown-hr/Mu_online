# Make Lorencia green, matching the customer's reference server.
#
# This client ships a DRY Lorencia: data\World1\TileGrass01.OZJ is sandy,
# TileGrass02.OZJ is straw, and the 3D grass tufts (data\Object1\grass_01.OZT)
# are beige. The reference server shows the same Lorencia field in green.
#
# Rather than swap in another map's textures (Noria's are blurry moss), this
# recolours Lorencia's OWN textures: every pixel keeps its brightness, so all
# the original grass-blade detail survives and only the hue moves to green.
# Originals are backed up and -Restore puts them back.
#
# OZJ = 24-byte header + JPEG.   OZT = 4-byte header + TGA (32bpp BGRA).

param(
    [string]$ClientDir = "C:\work\Mu_online\m1\host\Client\play-safe",
    # Per-channel multipliers applied to each pixel's brightness.
    # Defaults chosen by sampling the customer's reference video: its Lorencia
    # grass measures about R=45 G=43 B=15 on screen, i.e. a dark olive-green,
    # and the render is ~0.77x the texture value.
    [double]$TintR = 0.45,
    [double]$TintG = 0.60,
    [double]$TintB = 0.20,
    # Pushes light/dark apart so the grass-blade detail stays visible after
    # the brightness is pulled down. 1.0 = off.
    [double]$Contrast = 1.30,
    # The reference's 3D grass tufts are lighter than its ground, so the
    # sprite gets a brighter version of the same tint.
    [double]$SpriteBoost = 1.45,
    # Fall back to bare ground with no grass blades at all (the smooth look).
    [switch]$HideBlades,
    # Use the client's 256x128 "tall grass" billboard instead of the 256x64 one,
    # recoloured green - closer to the dense, tall grass on the character-select
    # screen that the customer pointed at. Source art is World4's TileGrass03.
    [switch]$TallBlades,
    # How many shifted copies of the blade texture to overlay. Blade HEIGHT is
    # fixed by the client's billboard size (a taller texture just gets stretched
    # into giant streaks), so density is the only lever for a fuller field.
    [int]$Density = 3,
    [switch]$Restore
)

function Convert-Luma {
    # Brightness with contrast applied around mid-grey.
    param([double]$Luma, [double]$K)
    $v = 128 + (($Luma - 128) * $K)
    if ($v -lt 0) { return 0.0 }
    if ($v -gt 255) { return 255.0 }
    return $v
}

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$data   = Join-Path $ClientDir 'data'
$world1 = Join-Path $data 'World1'
$world4 = Join-Path $data 'World4'      # Noria - source of the green grass blades
$obj1   = Join-Path $data 'Object1'
$bakT   = Join-Path $world1 '_orig-terrain-backup'
$bakO   = Join-Path $obj1   '_orig-terrain-backup'

$tiles  = 'TileGrass01.OZJ', 'TileGrass02.OZJ'

if ($Restore) {
    foreach ($t in ($tiles + 'TileGrass01.OZT')) {
        $b = Join-Path $bakT $t
        if (Test-Path $b) { Copy-Item $b (Join-Path $world1 $t) -Force; Write-Host "restored $t" }
    }
    $b = Join-Path $bakO 'grass_01.OZT'
    if (Test-Path $b) { Copy-Item $b (Join-Path $obj1 'grass_01.OZT') -Force; Write-Host "restored grass_01.OZT" }
    Write-Host "Lorencia restored to the original dry textures." -ForegroundColor Yellow
    return
}

New-Item -ItemType Directory -Force $bakT | Out-Null
New-Item -ItemType Directory -Force $bakO | Out-Null

function Get-Pristine {
    # Always work from the untouched original so re-running never compounds.
    param([string]$Live, [string]$BackupDir)
    $name = Split-Path $Live -Leaf
    $bak  = Join-Path $BackupDir $name
    if (-not (Test-Path $bak)) { Copy-Item $Live $bak }
    return [IO.File]::ReadAllBytes($bak)
}

# --- terrain tiles (OZJ: 24-byte header + JPEG) ----------------------------
$jpegCodec = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object Drawing.Imaging.EncoderParameters 1
$encParams.Param[0] = New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality, [int64]95)

foreach ($t in $tiles) {
    $live = Join-Path $world1 $t
    $raw  = Get-Pristine $live $bakT
    $hdr  = $raw[0..23]
    $ms   = New-Object IO.MemoryStream($raw[24..($raw.Length - 1)], $false)
    $bmp  = [Drawing.Image]::FromStream($ms)

    $rect = New-Object Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
    $bd   = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadWrite, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $len  = [Math]::Abs($bd.Stride) * $bmp.Height
    $buf  = New-Object byte[] $len
    [Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $buf, 0, $len)
    for ($i = 0; $i -lt $len; $i += 3) {
        $luma = (0.114 * $buf[$i]) + (0.587 * $buf[$i + 1]) + (0.299 * $buf[$i + 2])   # BGR order
        $luma = Convert-Luma $luma $Contrast
        $buf[$i]     = [byte][Math]::Min(255, [Math]::Round($luma * $TintB))
        $buf[$i + 1] = [byte][Math]::Min(255, [Math]::Round($luma * $TintG))
        $buf[$i + 2] = [byte][Math]::Min(255, [Math]::Round($luma * $TintR))
    }
    [Runtime.InteropServices.Marshal]::Copy($buf, 0, $bd.Scan0, $len)
    $bmp.UnlockBits($bd)

    $dims = "{0}x{1}" -f $bmp.Width, $bmp.Height
    $out = New-Object IO.MemoryStream
    $bmp.Save($out, $jpegCodec, $encParams)
    $bmp.Dispose(); $ms.Dispose()
    [IO.File]::WriteAllBytes($live, ($hdr + $out.ToArray()))
    $out.Dispose()
    Write-Host ("{0} greened ({1})" -f $t, $dims) -ForegroundColor Green
}

# --- the grass blades themselves -------------------------------------------
# Lorencia's billboard grass (World1\TileGrass01.OZT) is pale straw SPIKES -
# that is what read as dry stubble. Noria's equivalent is lush green blades at
# exactly the same size (256x64), and it is the same grass seen on the
# character-select screen. Both are original MU art, so use Noria's here.
$bladeSrc = Join-Path $world4 'TileGrass01.OZT'
$bladeDst = Join-Path $world1 'TileGrass01.OZT'
if ((Test-Path $bladeSrc) -and (Test-Path $bladeDst)) {
    if (-not (Test-Path (Join-Path $bakT 'TileGrass01.OZT'))) {
        Copy-Item $bladeDst (Join-Path $bakT 'TileGrass01.OZT')
    }
    if ($HideBlades) {
        $bytes = Get-Pristine $bladeDst $bakT
        $px = 4 + 18
        $w = [BitConverter]::ToUInt16($bytes, 16); $h = [BitConverter]::ToUInt16($bytes, 18)
        for ($i = 0; $i -lt ($w * $h); $i++) { $bytes[$px + $i * 4 + 3] = 0 }
        [IO.File]::WriteAllBytes($bladeDst, $bytes)
        Write-Host "TileGrass01.OZT blades hidden" -ForegroundColor Green
    }
    elseif ($TallBlades) {
        # TileGrass03 is 256x128 (twice as tall) but orange, so recolour it.
        $tall = Join-Path $world4 'TileGrass03.OZT'
        if (-not (Test-Path $tall)) { throw "missing $tall" }
        $bytes = [IO.File]::ReadAllBytes($tall)
        $tga = 4
        $w = [BitConverter]::ToUInt16($bytes, $tga + 12)
        $h = [BitConverter]::ToUInt16($bytes, $tga + 14)
        $px = $tga + 18
        for ($i = 0; $i -lt ($w * $h); $i++) {
            $o = $px + $i * 4
            if ($bytes[$o + 3] -eq 0) { continue }
            $luma = (0.114 * $bytes[$o]) + (0.587 * $bytes[$o + 1]) + (0.299 * $bytes[$o + 2])
            $luma = (Convert-Luma $luma $Contrast) * $SpriteBoost
            $bytes[$o]     = [byte][Math]::Min(255, [Math]::Round($luma * $TintB))
            $bytes[$o + 1] = [byte][Math]::Min(255, [Math]::Round($luma * $TintG))
            $bytes[$o + 2] = [byte][Math]::Min(255, [Math]::Round($luma * $TintR))
        }
        [IO.File]::WriteAllBytes($bladeDst, $bytes)
        Write-Host ("TileGrass01.OZT <- World4 TileGrass03 greened ({0}x{1}, tall)" -f $w, $h) -ForegroundColor Green
    }
    else {
        Copy-Item $bladeSrc $bladeDst -Force
        Write-Host "TileGrass01.OZT <- World4 (lush green blades)" -ForegroundColor Green

        # Density: the blade height is fixed by the client's billboard, so the
        # only way to get a fuller field is more blades inside the texture.
        # Overlay horizontally-shifted copies of itself (alpha-over, keeping the
        # most opaque sample) so coverage multiplies without changing height.
        if ($Density -gt 1) {
            $bytes = [IO.File]::ReadAllBytes($bladeDst)
            $tga = 4
            $w = [BitConverter]::ToUInt16($bytes, $tga + 12)
            $h = [BitConverter]::ToUInt16($bytes, $tga + 14)
            $px = $tga + 18
            $src = New-Object byte[] ($w * $h * 4)
            [Array]::Copy($bytes, $px, $src, 0, $src.Length)
            for ($y = 0; $y -lt $h; $y++) {
                $row = $y * $w * 4
                for ($x = 0; $x -lt $w; $x++) {
                    $bestA = -1; $bo = 0
                    for ($k = 0; $k -lt $Density; $k++) {
                        $sx = ($x + [int]($k * $w / $Density)) % $w
                        $o = $row + $sx * 4
                        if ($src[$o + 3] -gt $bestA) { $bestA = $src[$o + 3]; $bo = $o }
                    }
                    $d = $px + $row + $x * 4
                    $bytes[$d]     = $src[$bo]
                    $bytes[$d + 1] = $src[$bo + 1]
                    $bytes[$d + 2] = $src[$bo + 2]
                    $bytes[$d + 3] = $src[$bo + 3]
                }
            }
            [IO.File]::WriteAllBytes($bladeDst, $bytes)
            Write-Host ("  density x{0} applied ({1}x{2})" -f $Density, $w, $h) -ForegroundColor Green
        }
    }
}

# The scattered grass tuft object keeps the same straw colouring, so recolour
# it to match the ground instead of leaving beige stubble behind.
$tuft = Join-Path $obj1 'grass_01.OZT'
if (Test-Path $tuft) {
    $bytes = Get-Pristine $tuft $bakO
    $tga = 4
    $w   = [BitConverter]::ToUInt16($bytes, $tga + 12)
    $h   = [BitConverter]::ToUInt16($bytes, $tga + 14)
    if ($bytes[$tga + 16] -ne 32) { Write-Warning "grass_01.OZT not 32bpp, skipped" }
    else {
        $px = $tga + 18
        for ($i = 0; $i -lt ($w * $h); $i++) {
            $o = $px + $i * 4
            if ($bytes[$o + 3] -eq 0) { continue }
            $luma = (0.114 * $bytes[$o]) + (0.587 * $bytes[$o + 1]) + (0.299 * $bytes[$o + 2])
            $luma = (Convert-Luma $luma $Contrast) * $SpriteBoost
            $bytes[$o]     = [byte][Math]::Min(255, [Math]::Round($luma * $TintB))
            $bytes[$o + 1] = [byte][Math]::Min(255, [Math]::Round($luma * $TintG))
            $bytes[$o + 2] = [byte][Math]::Min(255, [Math]::Round($luma * $TintR))
        }
        [IO.File]::WriteAllBytes($tuft, $bytes)
        Write-Host ("grass_01.OZT greened ({0}x{1})" -f $w, $h) -ForegroundColor Green
    }
}

Write-Host ("tint R={0} G={1} B={2} - restart the client to see it" -f $TintR, $TintG, $TintB) -ForegroundColor Cyan
