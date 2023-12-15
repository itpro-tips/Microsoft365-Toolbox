<#
.SYNOPSIS 
Install Microsoft 365 PowerShell Prerequisites
 
.DESCRIPTION  
Downloads and installs the Msolservice v1 (deprecated by Microsoft but always useful), Azure AD deprecated by Microsoft but always useful),, Sharepoint Online, Skype Online for Windows PowerShell, PNP, etc.
You can choose the Azure AD in Azure AD Preview

.AUTHOR

.CREATION DATE
2019-12-13

.LASTMODIFIED
2023-12-15

#>

# PowerShell 5.0 pour PowerShell Gallery  
#Requires -Version 5.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [Parameter()]
    [Boolean]$AdvancedModules
)
# Register PSGallery PSprovider and set as Trusted source
Register-PSRepository -Default -ErrorAction SilentlyContinue
Set-PSRepository -Name PSGallery -InstallationPolicy trusted -ErrorAction SilentlyContinue

# Install modules from PSGallery
$modules = @(
    'PowershellGet',
    'AzureADPreview',
    'MSOnline',
    'MicrosoftTeams',
    'Microsoft.Graph.Intune',
    #'MicrosoftStaffHub',
    'ExchangeOnlineManagement',
    'Microsoft.Online.SharePoint.PowerShell',
    'PnP.PowerShell',
    # Microsoft Graph will replace AzureAD and MSOnline by december 2022 https://office365itpros.com/2021/06/03/microsoft-graph-sdk-powershell-future/
    'Microsoft.Graph'
)

if ($AdvancedModules) {
    # DSCParser to export or compare 365 configuration
    $modules += 'DSCParser'
        
    #The MSAL.PS PowerShell module wraps MSAL.NET functionality into PowerShell-friendly cmdlets and is not supported by Microsoft. By Microsoft
    $modules += 'MSAL.PS'

    # Checks the current status of connections to (and as required, prompts for login to) various Microsoft Cloud platforms. By Microsoft
    $modules += 'MSCloudLoginAssistant'

    # Tools for managing, troubleshooting, and reporting on various aspects of Microsoft Identity products and services, primarily Azure AD. By Microsoft
    $modules += 'MSIdentityTools'
}

foreach ($module in $modules) {
    $currentVersion = $null
	
    # Check if Azure ADPreview is installed
    if ($module -eq 'AzureAD') {
        $aadPreview = Get-InstalledModule -Name 'AzureADPreview' -ErrorAction SilentlyContinue
		
        if ($null -ne $aadPreview) {
            Write-Warning "Azure AD won't be installed, because Azure AD Preview is already installed (version: $($aadPreview.Version.Tostring()))"
            Write-Host -ForegroundColor Cyan "Azure AD Preview will be tested for upgrade"  
		
            $module = 'AzureADPreview'
            #continue
        }
    }
    if ($null -ne (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
        $currentVersion = (Get-InstalledModule -Name $module -AllVersions).Version
    }
	
    $moduleInfos = Find-Module -Name $module
	
    if ($null -eq $currentVersion) {
        Write-Host -ForegroundColor Cyan "Install from PowerShellGallery : $($moduleInfos.Name) - $($moduleInfos.Version) published on $($moduleInfos.PublishedDate)"  
		
        try {
            Install-Module -Name $module -Force
        }
        catch {
            Write-Host -ForegroundColor red "$_.Exception.Message"
        }
    }
    elseif ($moduleInfos.Version -eq $currentVersion) {
        Write-Host -ForegroundColor Green "$($moduleInfos.Name) already installed in the last version"
    }
    elseif ($currentVersion.count -gt 1) {
        Write-Warning "$module is installed in $($currentVersion.count) versions (versions: $currentVersion)"
        Write-Host -ForegroundColor Cyan "Uninstall previous $module versions"
        
        try {
            Get-InstalledModule -Name $module -AllVersions | Where-Object { $_.Version -ne $moduleInfos.Version } | Uninstall-Module -Force
        }
        catch {
            Write-Host -ForegroundColor red "$_.Exception.Message"
        }
        
        Write-Host -ForegroundColor Cyan "Install from PowerShellGallery : $($moduleInfos.Name) - $($moduleInfos.Version) published on $($moduleInfos.PublishedDate)"  
    
        try {
            Install-Module -Name $module -Force
        }
        catch {
            Write-Host -ForegroundColor red "$_.Exception.Message"
        }
    }
    else {
        Write-Host -ForegroundColor Cyan " $($moduleInfos.Name) - Update from PowerShellGallery from $currentVersion to $($moduleInfos.Version) published on $($moduleInfos.PublishedDate)" 
        try {
            Update-Module -Name $module -Force
        }
        catch {
            Write-Host -ForegroundColor red "$_.Exception.Message"
        }
    }
}