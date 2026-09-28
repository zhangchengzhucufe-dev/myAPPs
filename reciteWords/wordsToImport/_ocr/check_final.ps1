$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot
$appDir = Split-Path (Split-Path $PSScriptRoot)
$htmlFile = Get-ChildItem $appDir -Filter '背单词.html' | Select-Object -First 1
if(-not $htmlFile){ $htmlFile = Get-ChildItem $appDir -Filter *.html | Where-Object { $_.Name -notlike '*.bak*' } | Select-Object -First 1 }
$html = [System.IO.File]::ReadAllText($htmlFile.FullName, [System.Text.Encoding]::UTF8)
Write-Output ('HTML SIZE: ' + $html.Length)
Write-Output ('SEED MARKER COUNT: ' + ([regex]::Matches($html, 'SEED_IMPORT_V2')).Count)

$m = [regex]::Match($html, 'const SEED_V2 = (\[[\s\S]*?\]);')
if(-not $m.Success){ Write-Output 'SEED ARRAY NOT FOUND'; exit 1 }
$arr = $m.Groups[1].Value | ConvertFrom-Json
Write-Output ('EMBEDDED WORDS: ' + @($arr).Count)
$dup = @($arr | Group-Object { $_[0].ToLower() } | Where-Object { $_.Count -gt 1 })
Write-Output ('EMBEDDED DUP EN: ' + $dup.Count)
$empty = @($arr | Where-Object { [string]::IsNullOrWhiteSpace([string]$_[1]) })
Write-Output ('EMPTY ZH: ' + $empty.Count)
Write-Output ('FIRST: ' + $arr[0][0] + ' ' + $arr[0][1])
Write-Output ('LAST: ' + $arr[@($arr).Count-1][0] + ' ' + $arr[@($arr).Count-1][1])

# 种子只跑一次的标记逻辑是否存在
$flagOk = $html.Contains([string]::Concat('localStorage.getItem(LS', " + '.seed2')"))
Write-Output ('SEED-ONCE FLAG LOGIC PRESENT: ' + $flagOk)
# 种子代码位于初始 render() 之前
$seedIdx = $html.IndexOf('SEED_IMPORT_V2')
$renderIdx = $html.LastIndexOf("applyTheme();")
Write-Output ('SEED BEFORE INITIAL RENDER: ' + ($seedIdx -lt $renderIdx))

# 备份文件
$backup = Get-Item ($htmlFile.FullName + '.bak-before-seed')
Write-Output ('BACKUP SIZE: ' + $backup.Length + '  (原版 ' + $backup.LastWriteTime + ')')

# 对比词表留档
$fin = [System.IO.File]::ReadAllText(($baseDir + '\final_words.json'), [System.Text.Encoding]::UTF8) | ConvertFrom-Json
Write-Output ('final_words.json COUNT: ' + @($fin).Count + '  (应与内嵌数量一致)')
