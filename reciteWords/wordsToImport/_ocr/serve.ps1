$ErrorActionPreference = 'Stop'
$appDir = Split-Path (Split-Path $PSScriptRoot)
$htmlFile = Get-ChildItem $appDir -Filter *.html | Select-Object -First 1
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://127.0.0.1:8931/')
$listener.Start()
Write-Output ('SERVING: ' + $htmlFile.FullName)
try {
  while($listener.IsListening){
    $ctx = $listener.GetContext()
    $bytes = [System.IO.File]::ReadAllBytes($htmlFile.FullName)
    $ctx.Response.ContentType = 'text/html; charset=utf-8'
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
  }
} finally { $listener.Stop() }
