# Install Java
Write-Output "Installing Java..."
Invoke-WebRequest -Uri "https://download.oracle.com/java/17/latest/jdk-17_windows-x64_bin.exe" -OutFile "$env:TEMP\java-installer.exe"
Start-Process "$env:TEMP\java-installer.exe" -ArgumentList "/s" -Wait

# Install Teams
Write-Output "Installing Microsoft Teams..."
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkID=869426" -OutFile "$env:TEMP\teams.exe"
Start-Process "$env:TEMP\teams.exe" -ArgumentList "/quiet" -Wait

# Install Chrome
Write-Output "Installing Google Chrome..."
Invoke-WebRequest -Uri "https://dl.google.com/chrome/install/latest/chrome_installer.exe" -OutFile "$env:TEMP\chrome_installer.exe"
Start-Process "$env:TEMP\chrome_installer.exe" -ArgumentList "/silent /install" -Wait

Write-Output "All software installed successfully."
