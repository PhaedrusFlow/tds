$uri  = "https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-x86_64.exe"
$out  = "$env:TEMP\rustdesk.exe"

Write-Host "Downloading RustDesk from $uri to $out ..."
Invoke-WebRequest -Uri $uri -OutFile $out

Write-Host "Starting RustDesk installer..."
Start-Process $out
