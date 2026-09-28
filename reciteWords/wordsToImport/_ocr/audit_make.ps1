$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$baseDir = $PSScriptRoot
$wordsDir = Split-Path $baseDir   # wordsToImport

$fin = [System.IO.File]::ReadAllText(($baseDir + '\final_words.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$count = @($fin).Count

# 等距抽 30 条，覆盖全书
$idxSet = New-Object System.Collections.Generic.HashSet[int]
for($i = 0; $i -lt 30; $i++){
  $null = $idxSet.Add([int][math]::Round($i * ($count - 1) / 29.0))
}
$sampleIdx = @($idxSet) | Sort-Object

# 建立 en -> (file, pos) 索引；记录每图词条数用于行距计算
$aFiles = Get-ChildItem ($baseDir + '\A\*.json') | Sort-Object Name
$loc = @{}
$fileCount = @{}
foreach($f in $aFiles){
  $arr = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  $fileCount[$f.BaseName] = @($arr).Count
  for($i=0; $i -lt $arr.Count; $i++){
    $k = $arr[$i][0].ToLower()
    if(-not $loc.ContainsKey($k)){ $loc[$k] = @($f.BaseName, $i) }
  }
}

Add-Type -AssemblyName System.Drawing
$outDir = $baseDir + '\_audit'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$report = New-Object System.Collections.Generic.List[string]
$n = 0
foreach($si in $sampleIdx){
  $n++
  $en = $fin[$si][0]; $zh = $fin[$si][1]
  $k = $en.ToLower()
  if(-not $loc.ContainsKey($k)){ $report.Add(($n.ToString('00') + ' LOCATE-FAIL ' + $en)); continue }
  $fileBase = $loc[$k][0]; $pos = $loc[$k][1]

  $jpg = Join-Path $wordsDir ($fileBase + '.jpg')
  $img = [System.Drawing.Image]::FromFile($jpg)
  $imgH = $img.Height
  $rows = $fileCount[$fileBase]
  $pitch = ($imgH - 450.0) / $rows
  $center = [int](320 + ($pos + 0.5) * $pitch)
  $y0 = $center - 350; if($y0 -lt 0){ $y0 = 0 }
  $cropH = 700; if($y0 + $cropH -gt $imgH){ $cropH = $imgH - $y0 }
  $bmp = New-Object System.Drawing.Bitmap(1260, $cropH)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0,0,1260,$cropH)), (New-Object System.Drawing.Rectangle(0,$y0,1260,$cropH)), [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  $name = '{0:00}_{1}.png' -f $n, ($en -replace '[^a-z-]','')
  $bmp.Save(($outDir + '\' + $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose(); $img.Dispose()
  $report.Add(('{0:00} {1}  src={2} row={3} img={4}' -f $n, $en, $fileBase, ($pos+1), $name))
}
[System.IO.File]::WriteAllLines(($baseDir + '\audit_list.txt'), $report, $utf8)
$report | ForEach-Object { Write-Output $_ }
