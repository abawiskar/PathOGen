@echo off
cd /d "%~dp0"
title PathOGen Web Server
powershell.exe -NoProfile -Command "$node = (Get-Command node -ErrorAction SilentlyContinue).Source; if (-not $node) { $node = 'C:\Program Files\WindowsApps\OpenAI.CodexPrimaryRuntime.v26-1111-574-0_26.1111.574.0_x64__3k8sg7r9htsxt\dependencies\node\bin\node.exe' }; if (Test-Path -LiteralPath $node) { & $node 'work\serve-web.cjs' } else { Write-Host 'Node.js was not found. Install Node.js and try again.' }"
pause
