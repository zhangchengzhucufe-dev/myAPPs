@echo off
rem 背单词启动器：启动同步服务 + 自动打开电脑网页端
cd /d "%~dp0"
start "背单词同步服务" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-server.ps1"
timeout /t 2 /nobreak >nul
rem 手机用数据线连接并开启USB调试后，自动映射同步端口（没装adb则跳过，不影响电脑使用）
set "ADB=C:\Users\15985\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if exist "%ADB%" (
  "%ADB%" reverse tcp:8642 tcp:8642 && echo 手机USB同步端口已映射
) else (
  echo 未检测到adb，跳过手机USB端口映射
)
start "" http://127.0.0.1:8642/
timeout /t 3 /nobreak >nul
