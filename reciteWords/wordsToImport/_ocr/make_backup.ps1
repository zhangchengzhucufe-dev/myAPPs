$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$baseDir = $PSScriptRoot
$appDir = Split-Path (Split-Path $PSScriptRoot)

$fin = [System.IO.File]::ReadAllText(($baseDir + '\final_words.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$words = New-Object System.Collections.Generic.List[string]
foreach($e in $fin){
  $id = [guid]::NewGuid().ToString()
  $en = $e[0]; $zh = $e[1]
  $words.Add('{"id":"' + $id + '","en":' + ($en | ConvertTo-Json) + ',"zh":' + ($zh | ConvertTo-Json) + ',"createdAt":"2026-09-27","learnedAt":null,"reviewDone":[false,false,false]}')
}
$state = '{"version":1,"words":[' + ($words -join ",`n") + '],"settings":{"examDate":null,"theme":"auto"},"daily":{}}'
# 校验
$parsed = $state | ConvertFrom-Json
Write-Output ('BACKUP WORDS: ' + @($parsed.words).Count)
$out = Join-Path $appDir ('beidan-backup-3294-2026-09-27.json')
[System.IO.File]::WriteAllText($out, $state, $utf8)
Write-Output ('WRITTEN: ' + $out)
