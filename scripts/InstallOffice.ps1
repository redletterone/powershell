<#
  .SYNOPSIS
    Installs Microsoft Office 365
  .DESCRIPTION
    Installs Microsoft Office 365 using a default configuration xml, unless a custom xml is provided.
    WARNING: This script will remove all existing office installations if used with the default configuration xml.
  .PARAMETER Config
    File path to custom configuration xml for office installations.
  .PARAMETER x86
    Switch parameter to install 32-bit Office applications. Ignored if -Config is used.
  .LINK
    XML Configuration Generator: https://config.office.com/
  .NOTES
    Author: Aaron J. Stevenson
#>

param (
  [Alias('Configure')][String]$Config, # File path to custom configuration xml
  [Alias('32bit')][Switch]$x86 # Installs Office 32-bit (ignored if -Config is used)
)

function Get-ODT {
  [String]$MSWebPage = Invoke-RestMethod 'https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117'
  $Script:ODTURL = $MSWebPage | ForEach-Object {
    if ($_ -match 'url=(https://.*officedeploymenttool.*\.exe)') { $Matches[1] }
  }

  try {
    Write-Output "`nDownloading Office Deployment Tool (ODT)..."
    Invoke-WebRequest -Uri $Script:ODTURL -OutFile $Script:Installer
    Start-Process -Wait -NoNewWindow -FilePath $Script:Installer -ArgumentList "/extract:$Script:ODT /quiet"
  }
  catch {
    Remove-Item $Script:ODT, $Script:Installer -Recurse -Force -ErrorAction Ignore
    Write-Warning 'There was an error downloading the Office Deployment Tool.'
    Write-Warning $_
    exit 1
  }
}

function Set-ConfigXML {

  if ($Config) {
    if (Test-Path $Config) { $Script:ConfigFile = $Config }
    else {
      Write-Warning 'The configuration XML file path is not valid or is inaccessible.'
      Write-Warning 'Please check the path and try again.'
      exit 1
    }
  }
  else {
    $Path = Split-Path -Path $Script:ConfigFile -Parent
    if (!(Test-Path -PathType Container $Path)) {
      New-Item -ItemType Directory -Path $Path | Out-Null
    }

    if ($x86 -or !(([Environment]::Is64BitOperatingSystem))) {
      $XML = [XML]@'
  <Configuration ID="5cf809c5-8f36-4fea-a837-69c7185cca8a">
    <Remove All="TRUE"/>
    <Add OfficeClientEdition="32" Channel="Current" MigrateArch="TRUE">
      <Product ID="O365BusinessRetail">
        <Language ID="en-us"/>
        <ExcludeApp ID="Groove"/>
        <ExcludeApp ID="Lync"/>
      </Product>
    </Add>
    <Property Name="SharedComputerLicensing" Value="0"/>
    <Property Name="FORCEAPPSHUTDOWN" Value="TRUE"/>
    <Property Name="DeviceBasedLicensing" Value="0"/>
    <Property Name="SCLCacheOverride" Value="0"/>
    <Updates Enabled="TRUE"/>
    <RemoveMSI/>
    <AppSettings>
      <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas"/>
      <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas"/>
      <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas"/>
    </AppSettings>
    <Display Level="Full" AcceptEULA="TRUE"/>
  </Configuration>
'@
    }
    else {
      $XML = [XML]@'
  <Configuration ID="5cf809c5-8f36-4fea-a837-69c7185cca8a">
    <Remove All="TRUE"/>
    <Add OfficeClientEdition="64" Channel="Current" MigrateArch="TRUE">
      <Product ID="O365BusinessRetail">
        <Language ID="en-us"/>
        <ExcludeApp ID="Groove"/>
        <ExcludeApp ID="Lync"/>
      </Product>
    </Add>
    <Property Name="SharedComputerLicensing" Value="0"/>
    <Property Name="FORCEAPPSHUTDOWN" Value="TRUE"/>
    <Property Name="DeviceBasedLicensing" Value="0"/>
    <Property Name="SCLCacheOverride" Value="0"/>
    <Updates Enabled="TRUE"/>
    <RemoveMSI/>
    <AppSettings>
      <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas"/>
      <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas"/>
      <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas"/>
    </AppSettings>
    <Display Level="Full" AcceptEULA="TRUE"/>
  </Configuration>
'@
    }
    $XML.Save("$Script:ConfigFile")
  }
}

function Install-Office {
  Write-Output 'Installing Microsoft Office...'
  try { 
    Start-Process -Wait -WindowStyle Hidden -FilePath "$Script:ODT\setup.exe" -ArgumentList "/configure $Script:ConfigFile"
    Write-Output 'Installation complete.'
  }
  catch {
    Write-Warning 'Error during Office installation:'
    Write-Warning $_
  }
  finally { Remove-Item $Script:ODT, $Script:Installer -Recurse -Force -ErrorAction Ignore }
}

function Remove-OfficeHub {
  $AppName = 'Microsoft.MicrosoftOfficeHub'
  try {
    Write-Output "Removing [$AppName] (Microsoft Store App)..."
    Get-AppxProvisionedPackage -Online | Where-Object { ($AppName -contains $_.DisplayName) } | Remove-AppxProvisionedPackage -AllUsers | Out-Null
    Get-AppxPackage -AllUsers | Where-Object { ($AppName -contains $_.Name) } | Remove-AppxPackage -AllUsers
  }
  catch { 
    Write-Warning "Error during [$AppName] removal:"
    Write-Warning $_
  }
}

$Script:ODT = "$env:temp\ODT"
$Script:ConfigFile = "$Script:ODT\office-config.xml"
$Script:Installer = "$env:temp\ODTSetup.exe"

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

Get-ODT 
Set-ConfigXML
Install-Office
Remove-OfficeHub
