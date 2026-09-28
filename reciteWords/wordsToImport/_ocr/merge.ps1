$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$baseDir = $PSScriptRoot
$fixes = [System.IO.File]::ReadAllText(($baseDir + '\fixes.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$zhFixFile = @{}
foreach($p in $fixes.zhFix.PSObject.Properties){ $zhFixFile[$p.Name] = $p.Value }
$inserts = @{}
foreach($p in $fixes.inserts.PSObject.Properties){
  $rows = @()
  foreach($r in $p.Value){ $rows += ,@($r[0], $r[1], $r[2]) }
  $inserts[$p.Name] = $rows
}

$files = Get-ChildItem ($baseDir + '\A\*.json') | Sort-Object Name
$all = New-Object System.Collections.Generic.List[object]
$applied = 0
foreach($f in $files){
  $base = $f.BaseName
  $arr = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  $list = New-Object System.Collections.Generic.List[object]
  foreach($e in $arr){ $list.Add(@($e[0], $e[1])) }
  if($zhFixFile.ContainsKey($base)){
    foreach($k in $zhFixFile[$base].PSObject.Properties.Name){
      $v = $zhFixFile[$base].$k
      for($i=0; $i -lt $list.Count; $i++){
        if($list[$i][0] -ieq $k){ $list[$i] = @($list[$i][0], $v); $applied++ }
      }
    }
  }
  if($inserts.ContainsKey($base)){
    foreach($ins in $inserts[$base]){
      $before = $ins[0]; $en = $ins[1]; $zh = $ins[2]
      $idx = -1
      for($i=0; $i -lt $list.Count; $i++){ if($list[$i][0] -ieq $before){ $idx = $i; break } }
      if($idx -ge 0){ $list.Insert($idx, @($en, $zh)); $applied++ }
      else { Write-Output ('INSERT-TARGET-NOT-FOUND: ' + $base + ' before ' + $before) }
    }
  }
  foreach($e in $list){ $all.Add(@($base, $e[0], $e[1])) }
}
Write-Output ('FIXES APPLIED: ' + $applied + '   RAW TOTAL: ' + $all.Count)

$seen = @{}
$final = New-Object System.Collections.Generic.List[object]
$dups = New-Object System.Collections.Generic.List[string]
foreach($e in $all){
  $k = $e[1].ToLower()
  if($seen.ContainsKey($k)){ $dups.Add($e[1] + ' @' + $e[0]) }
  else { $seen[$k] = 1; $final.Add($e) }
}
Write-Output ('UNIQUE: ' + $final.Count + '   DUPS REMOVED: ' + $dups.Count)
if($dups.Count -gt 0){ Write-Output ('DUP LIST: ' + (($dups | Select-Object -First 60) -join ', ')) }

$parts = foreach($e in $final){ '["' + $e[1] + '","' + $e[2] + '"]' }
[System.IO.File]::WriteAllText(($baseDir + '\final_words.json'), ('[' + ($parts -join ",`n") + ']'), $utf8)

$txt = New-Object System.Collections.Generic.List[string]
$n = 0
foreach($e in $final){ $n++; $txt.Add(('{0}. {1}  {2}' -f $n, $e[1], $e[2])) }
[System.IO.File]::WriteAllLines(($baseDir + '\final_review.txt'), $txt, $utf8)
Write-Output 'WRITTEN: final_words.json + final_review.txt'
