$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot
$appDir = Split-Path (Split-Path $PSScriptRoot)
$htmlFile = Get-ChildItem $appDir -Filter *.html | Select-Object -First 1
if(-not $htmlFile){ throw 'html file not found' }
Write-Output ('TARGET: ' + $htmlFile.FullName)

$seedJson = [System.IO.File]::ReadAllText(($baseDir + '\final_words.json'), [System.Text.Encoding]::UTF8)
$null = $seedJson | ConvertFrom-Json
Write-Output ('SEED JSON VALID. chars: ' + $seedJson.Length)

$template = [System.IO.File]::ReadAllText(($baseDir + '\seed_template.js'), [System.Text.Encoding]::UTF8)
if(-not $template.Contains('__SEED__')){ throw 'template placeholder missing' }
$js = $template.Replace('__SEED__', $seedJson)

$bytes = [System.IO.File]::ReadAllBytes($htmlFile.FullName)
$hadBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Write-Output ('HTML size: ' + $bytes.Length + '  BOM: ' + $hadBom)

$html = [System.IO.File]::ReadAllText($htmlFile.FullName, [System.Text.Encoding]::UTF8)
if($html.Contains('SEED_IMPORT_V2')){ Write-Output 'ALREADY SEEDED - nothing to do'; exit }

Copy-Item $htmlFile.FullName ($htmlFile.FullName + '.bak-before-seed') -Force
Write-Output ('BACKUP: ' + $htmlFile.FullName + '.bak-before-seed')

$idx = $html.LastIndexOf('</script>')
if($idx -lt 0){ throw 'script end tag not found' }
$newHtml = $html.Substring(0, $idx) + $js + "`r`n" + $html.Substring($idx)
$enc = New-Object System.Text.UTF8Encoding($hadBom)
[System.IO.File]::WriteAllText($htmlFile.FullName, $newHtml, $enc)
Write-Output ('NEW SIZE: ' + (Get-Item $htmlFile.FullName).Length)
Write-Output 'INJECTED OK'
