$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot
$appDir = Split-Path (Split-Path $PSScriptRoot)
$htmlFile = Get-ChildItem $appDir -Filter *.html | Select-Object -First 1
Write-Output ('TARGET: ' + $htmlFile.FullName)

$seedJson = [System.IO.File]::ReadAllText(($baseDir + '\final_words.json'), [System.Text.Encoding]::UTF8)
$null = $seedJson | ConvertFrom-Json
$template = [System.IO.File]::ReadAllText(($baseDir + '\seed_template.js'), [System.Text.Encoding]::UTF8)
$js = $template.Replace('__SEED__', $seedJson)

$backup = $htmlFile.FullName + '.bak-before-seed'
if(-not (Test-Path $backup)){ throw 'backup missing' }
$html = [System.IO.File]::ReadAllText($backup, [System.Text.Encoding]::UTF8)
if($html.Contains('SEED_IMPORT_V2')){ throw 'backup unexpectedly seeded' }

$anchorCrlf = "applyTheme();`r`nrender();"
$anchorLf = "applyTheme();`nrender();"
$idx = $html.IndexOf($anchorCrlf)
$nl = "`r`n"
if($idx -ge 0){ Write-Output 'ANCHOR: CRLF' }
else {
  $idx = $html.IndexOf($anchorLf); $nl = "`n"
  if($idx -ge 0){ Write-Output 'ANCHOR: LF' } else { throw 'startup anchor not found' }
}

$newHtml = $html.Substring(0, $idx) + $js + $nl + $html.Substring($idx)
$bytes = [System.IO.File]::ReadAllBytes($backup)
$hadBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$enc = New-Object System.Text.UTF8Encoding($hadBom)
[System.IO.File]::WriteAllText($htmlFile.FullName, $newHtml, $enc)
Write-Output ('NEW SIZE: ' + (Get-Item $htmlFile.FullName).Length)
Write-Output 'INJECTED OK (pre-render)'
