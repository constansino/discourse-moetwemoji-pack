\
    <#
    Quick sanity checks: duplicates, missing pairs, and file size stats.
    Run from repo root:
      .\scripts\verify-assets.ps1
    #>

    $ErrorActionPreference = "Stop"
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $gifDir     = Join-Path $repoRoot "emoji\gif"
    $avifDir    = Join-Path $repoRoot "emoji\avif"
    $fakePngDir = Join-Path $repoRoot "emoji\fakepng"

    foreach ($d in @($gifDir, $avifDir, $fakePngDir)) {
      if (!(Test-Path $d)) { throw "Missing $d" }
    }

    $gifBases     = Get-ChildItem $gifDir     -Filter *.gif  -File | ForEach-Object { $_.BaseName }
    $avifBases    = Get-ChildItem $avifDir    -Filter *.avif -File | ForEach-Object { $_.BaseName }
    $fakePngBases = Get-ChildItem $fakePngDir -Filter *.png  -File | ForEach-Object { $_.BaseName }

    function To-Set($arr) {
      $set = [System.Collections.Generic.HashSet[string]]::new()
      foreach ($b in $arr) { [void]$set.Add($b) }
      return $set
    }

    $gifSet     = To-Set $gifBases
    $avifSet    = To-Set $avifBases
    $fakePngSet = To-Set $fakePngBases

    Write-Host "GIF count:     $($gifSet.Count)"
    Write-Host "AVIF count:    $($avifSet.Count)"
    Write-Host "FakePNG count: $($fakePngSet.Count)"

    # Compare sets
    $onlyGif  = $gifSet.Where({ -not $avifSet.Contains($_) })
    $onlyAvif = $avifSet.Where({ -not $gifSet.Contains($_) })
    $onlyFake = $fakePngSet.Where({ -not $gifSet.Contains($_) -and -not $avifSet.Contains($_) })

    Write-Host "Only in GIF (missing AVIF):  $($onlyGif.Count)"
    Write-Host "Only in AVIF (missing GIF):  $($onlyAvif.Count)"
    Write-Host "Only in FakePNG (missing both): $($onlyFake.Count)"

    if ($onlyGif.Count -gt 0) {
      Write-Host "Examples only in GIF:"; $onlyGif | Select-Object -First 20 | ForEach-Object { "  $_" } | Write-Host
    }
    if ($onlyAvif.Count -gt 0) {
      Write-Host "Examples only in AVIF:"; $onlyAvif | Select-Object -First 20 | ForEach-Object { "  $_" } | Write-Host
    }
    if ($onlyFake.Count -gt 0) {
      Write-Host "Examples only in FakePNG:"; $onlyFake | Select-Object -First 20 | ForEach-Object { "  $_" } | Write-Host
    }

    $gifBytes     = (Get-ChildItem $gifDir     -Filter *.gif  -File | Measure-Object -Property Length -Sum).Sum
    $avifBytes    = (Get-ChildItem $avifDir    -Filter *.avif -File | Measure-Object -Property Length -Sum).Sum
    $fakePngBytes = (Get-ChildItem $fakePngDir -Filter *.png  -File | Measure-Object -Property Length -Sum).Sum

    Write-Host ("Total GIF size:     {0:N2} MB" -f ($gifBytes/1MB))
    Write-Host ("Total AVIF size:    {0:N2} MB" -f ($avifBytes/1MB))
    Write-Host ("Total FakePNG size: {0:N2} MB" -f ($fakePngBytes/1MB))
