# Builds Resource Manager for grandMA as a single self-contained .exe (no separate
# .NET runtime install needed) and drops it in .\publish\.
#
# Usage (from PowerShell, in this folder):
#   .\install.ps1
#
# First launch will likely trigger a Windows SmartScreen "unknown publisher"
# warning, since this isn't code-signed — click "More info" -> "Run anyway".

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\GrandMAResourceManager"

dotnet publish -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o "$PSScriptRoot\publish"

Write-Host ""
Write-Host "Built: $PSScriptRoot\publish\ResourceManagerForGrandMA.exe"
Write-Host "Copy that .exe anywhere and run it directly - no installer needed."
