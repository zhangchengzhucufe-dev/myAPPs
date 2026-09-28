# 背单词同步服务器：提供应用页面 + 数据共享接口
# 用法：双击「背单词.bat」启动；关闭本窗口即停止服务
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$enc = [Text.Encoding]::UTF8
$stateFile = Join-Path $root 'state.json'
$listener = $null
try {
  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, 8642)
  $listener.Start()
} catch {
  Write-Host '端口 8642 已被占用：同步服务可能已经在运行了。'
  Start-Sleep -Seconds 3
  exit
}
Write-Host '=============================================='
Write-Host '  背单词同步服务已启动（关闭此窗口 = 停止服务）'
Write-Host '=============================================='
Write-Host '电脑使用： http://127.0.0.1:8642/'
[Net.Dns]::GetHostAddresses($env:COMPUTERNAME) |
  Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
  ForEach-Object { Write-Host ('手机(同一WiFi): http://{0}:8642/' -f $_.IPAddressToString) }
Write-Host '首次使用如弹出防火墙提示，请勾选「允许」。'
Write-Host '----------------------------------------------'

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $stream.ReadTimeout = 5000
    $ms = New-Object IO.MemoryStream
    $buf = New-Object byte[] 65536
    $headerText = ''
    $body = @()
    while ($true) {
      $n = $stream.Read($buf, 0, $buf.Length)
      if ($n -le 0) { break }
      $ms.Write($buf, 0, $n)
      $all = $ms.ToArray()
      $s = $enc.GetString($all)
      $i = $s.IndexOf("`r`n`r`n")
      if ($i -ge 0) {
        $headerText = $s.Substring(0, $i)
        $bodyStart = $i + 4
        $cl = 0
        foreach ($line in $headerText -split "`r`n") { if ($line -match '^Content-Length:\s*(\d+)') { $cl = [int]$Matches[1] } }
        if ($all.Length -gt $bodyStart) { $body = $all[$bodyStart..($all.Length - 1)] } else { $body = @() }
        while ($body.Count -lt $cl) {
          $n2 = $stream.Read($buf, 0, [Math]::Min($buf.Length, $cl - $body.Count))
          if ($n2 -le 0) { break }
          $body += $buf[0..($n2 - 1)]
        }
        break
      }
    }
    if (-not $headerText) { $client.Close(); continue }
    $reqLine = ($headerText -split "`r`n")[0]
    $parts = $reqLine -split ' '
    $method = $parts[0]
    $p = [Uri]::UnescapeDataString((($parts[1] -split '\?')[0]))
    $isOK = $true; $status = '200 OK'; $ctype = 'text/html; charset=utf-8'; $bytes = $null
    if ($method -eq 'OPTIONS') {
      $bytes = $enc.GetBytes('ok'); $ctype = 'text/plain'
    } elseif ($method -eq 'POST' -and $p -eq '/api/state') {
      [IO.File]::WriteAllBytes($stateFile, [byte[]]@($body))
      $bytes = $enc.GetBytes('{"ok":true}')
      $ctype = 'application/json'
      Write-Host ("[{0}] 手机/电脑同步了数据" -f (Get-Date -Format 'HH:mm:ss'))
    } elseif ($method -eq 'GET' -and $p -eq '/api/state') {
      if (Test-Path $stateFile) { $bytes = [IO.File]::ReadAllBytes($stateFile); $ctype = 'application/json' }
      else { $isOK = $false; $status = '404 Not Found'; $bytes = $enc.GetBytes('{"error":"empty"}'); $ctype = 'application/json' }
    } else {
      if ($p -eq '/' -or $p -eq '/index.html') {
        $file = Get-ChildItem -Path $root -Filter '背单词.html' | Select-Object -First 1
      } else {
        $fp = Join-Path $root ($p.TrimStart('/') -replace '/', '\')
        $file = if (Test-Path $fp -PathType Leaf) { Get-Item $fp } else { $null }
      }
      if ($file) { $bytes = [IO.File]::ReadAllBytes($file.FullName) }
      else { $isOK = $false; $status = '404 Not Found'; $bytes = $enc.GetBytes('404 not found'); $ctype = 'text/plain' }
    }
    $statusLine = if ($isOK) { 'HTTP/1.1 200 OK' } else { "HTTP/1.1 $status" }
    $hdr = "$statusLine`r`nContent-Type: $ctype`r`nContent-Length: $($bytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nAccess-Control-Allow-Methods: GET, POST, OPTIONS`r`nAccess-Control-Allow-Headers: Content-Type`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
    $hb = $enc.GetBytes($hdr)
    $stream.Write($hb, 0, $hb.Length)
    $stream.Write([byte[]]@($bytes), 0, $bytes.Length)
    $stream.Flush()
  } catch { Write-Host ('请求处理出错: ' + $_.Exception.Message) }
  finally { $client.Close() }
}
