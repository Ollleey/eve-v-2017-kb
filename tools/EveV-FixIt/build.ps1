<#
  build.ps1  -  compiles EveVFixIt.ps1 into the portable EveV-FixIt.exe

  Needs: Windows PowerShell 5.1, .NET Framework 4.x, internet (first run, to fetch ps2exe).
  No Visual Studio / .NET SDK / MSBuild required.

  Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
          powershell ... -File build.ps1 -Arch x64      # if Defender flags the AnyCPU build
#>
param(
    [ValidateSet('AnyCPU','x64','x86')] [string]$Arch = 'AnyCPU'
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

$src  = Join-Path $here 'EveVFixIt.ps1'
$exe  = Join-Path $here 'EveV-FixIt.exe'
$ico  = Join-Path $here 'app.ico'
$ps2  = Join-Path $env:LOCALAPPDATA 'EveV-FixIt-build\PS2EXE'

Write-Host "== Eve V Fix-It build ==" -ForegroundColor Cyan

# ---------------------------------------------------------------- 1. icon
if (-not (Test-Path $ico)) {
    Write-Host "generating app.ico ..."
    Add-Type -AssemblyName System.Drawing
    $png = New-Object System.Drawing.Bitmap 256,256
    $g   = [System.Drawing.Graphics]::FromImage($png)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    $bg  = New-Object System.Drawing.Drawing2D.GraphicsPath
    $rad = 44; $r = [System.Drawing.Rectangle]::new(8,8,240,240)
    $bg.AddArc($r.X,$r.Y,$rad,$rad,180,90)
    $bg.AddArc($r.Right-$rad,$r.Y,$rad,$rad,270,90)
    $bg.AddArc($r.Right-$rad,$r.Bottom-$rad,$rad,$rad,0,90)
    $bg.AddArc($r.X,$r.Bottom-$rad,$rad,$rad,90,90)
    $bg.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(59,130,246))), $bg)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 26
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $g.DrawLines($pen, ([System.Drawing.Point[]]@(
        (New-Object System.Drawing.Point 78,132),
        (New-Object System.Drawing.Point 116,172),
        (New-Object System.Drawing.Point 184,86))))
    $g.Dispose()

    # wrap the PNG in a minimal .ico container (PNG-compressed icon, Vista+)
    $ms = New-Object System.IO.MemoryStream
    $png.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $ms.ToArray(); $png.Dispose()
    $fs = [System.IO.File]::Create($ico)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)          # ICONDIR
    $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$bytes.Length); $bw.Write([uint32]22)                   # size, offset
    $bw.Write($bytes)
    $bw.Flush(); $fs.Close()
    Write-Host "  app.ico written ($($bytes.Length) bytes)"
}

# ---------------------------------------------------------------- 2. ps2exe
function Find-Ps2Exe {
    foreach ($p in @((Join-Path $ps2 'Module\ps2exe.psd1'), (Join-Path $ps2 'Module\ps2exe.ps1'), (Join-Path $ps2 'ps2exe.ps1'))) {
        if (Test-Path $p) { return $p }
    }
    $null
}

$found = Find-Ps2Exe
if (-not $found) {
    Write-Host "fetching ps2exe (MScholtes/PS2EXE) ..."
    $null = New-Item -ItemType Directory -Force -Path (Split-Path $ps2)
    if (Test-Path $ps2) { Remove-Item $ps2 -Recurse -Force }
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $ep = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & git clone --depth 1 --quiet https://github.com/MScholtes/PS2EXE "$ps2" 2>&1 | Out-Null
        $ErrorActionPreference = $ep
    }
    $found = Find-Ps2Exe
    if (-not $found) {
        Write-Host "  git route failed - trying PSGallery ..."
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
            Install-Module ps2exe -Scope CurrentUser -Force
        } catch { throw "Could not obtain ps2exe. Install it manually:  Install-Module ps2exe -Scope CurrentUser" }
    }
}

if ($found) {
    if ($found -match '\.psd1$') { Import-Module $found -Force }
    elseif ($found -match '\.psm1$') { Import-Module $found -Force }
    else { . $found }
} else {
    Import-Module ps2exe
}

# ---------------------------------------------------------------- 3. compile
if (Test-Path $exe) { Remove-Item $exe -Force }
Write-Host "compiling ($Arch) ..."
$common = @{
    inputFile   = $src
    outputFile  = $exe
    iconFile    = $ico
    noConsole   = $true
    STA         = $true
    requireAdmin = $true
    title       = 'Eve V Fix-It'
    product     = 'Eve V Fix-It'
    description = 'Software repair assistant for the Eve V (2017) - eve-v-2017-kb'
    company     = 'eve-v-2017-kb (community)'
    version     = '1.0.0.0'
}
if ($Arch -eq 'x64') { $common.x64 = $true } elseif ($Arch -eq 'x86') { $common.x86 = $true }

if (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue) { Invoke-ps2exe @common }
else { ps2exe @common }

if (-not (Test-Path $exe)) { throw "build failed - no exe produced" }

$fi = Get-Item $exe
$sha = (Get-FileHash $exe -Algorithm SHA256).Hash
Write-Host ""
Write-Host "OK  $exe" -ForegroundColor Green
Write-Host ("    {0:N0} bytes" -f $fi.Length)
Write-Host "    SHA-256  $sha"
Write-Host ""
Write-Host "Note: an unsigned exe may be flagged by Windows Defender / SmartScreen." -ForegroundColor Yellow
Write-Host "      Run the .ps1 via Start-EveV-FixIt.bat instead, or 'More info -> Run anyway'."
