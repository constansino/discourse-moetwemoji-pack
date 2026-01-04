\
    <#
    Copies your prepared emoji assets into the plugin repo.

    Usage (PowerShell):
      $gifSrc     = "C:\Users\1\love\moetwemoji72x72gif"
      $avifSrc    = "C:\Users\1\love\moetwemoji72x72avif"
      $fakePngSrc = "C:\Users\1\love\moetwemoji72x72fakepng(avif)"

      .\scripts\prepare-assets.ps1 -GifSource $gifSrc -AvifSource $avifSrc -FakePngSource $fakePngSrc

    Notes:
    - GIFs:   copy as-is into emoji\gif
    - AVIFs:  copy as-is into emoji\avif
    - FakePNG: copy as-is into emoji\fakepng (these are AVIF content named *.png)
    #>

    param(
      [Parameter(Mandatory=$true)][string]$GifSource,
      [Parameter(Mandatory=$true)][string]$AvifSource,
      [Parameter(Mandatory=$true)][string]$FakePngSource
    )

    $ErrorActionPreference = "Stop"

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $gifDst     = Join-Path $repoRoot "emoji\gif"
    $avifDst    = Join-Path $repoRoot "emoji\avif"
    $fakePngDst = Join-Path $repoRoot "emoji\fakepng"

    New-Item -ItemType Directory -Force -Path $gifDst     | Out-Null
    New-Item -ItemType Directory -Force -Path $avifDst    | Out-Null
    New-Item -ItemType Directory -Force -Path $fakePngDst | Out-Null

    Write-Host "Copying GIFs from $GifSource -> $gifDst"
    Get-ChildItem -Path $GifSource -Filter *.gif -File | ForEach-Object {
      Copy-Item -Force $_.FullName (Join-Path $gifDst $_.Name)
    }

    Write-Host "Copying AVIFs from $AvifSource -> $avifDst"
    Get-ChildItem -Path $AvifSource -Filter *.avif -File | ForEach-Object {
      Copy-Item -Force $_.FullName (Join-Path $avifDst $_.Name)
    }

    Write-Host "Copying FakePNG (AVIF content named .png) from $FakePngSource -> $fakePngDst"
    Get-ChildItem -Path $FakePngSource -Filter *.png -File | ForEach-Object {
      Copy-Item -Force $_.FullName (Join-Path $fakePngDst $_.Name)
    }

    $gifCount     = (Get-ChildItem -Path $gifDst     -Filter *.gif  -File).Count
    $avifCount    = (Get-ChildItem -Path $avifDst    -Filter *.avif -File).Count
    $fakePngCount = (Get-ChildItem -Path $fakePngDst -Filter *.png  -File).Count

    Write-Host "Done. gif=$gifCount, avif=$avifCount, fakepng=$fakePngCount"
    Write-Host "Next: git add / commit / push, then install plugin on Discourse and run: rake moetwemoji:import"
