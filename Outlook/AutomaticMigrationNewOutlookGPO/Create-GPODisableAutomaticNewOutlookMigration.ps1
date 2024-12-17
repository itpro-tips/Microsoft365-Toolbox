# HKEY_CURRENT_USER\Software\Policies\Microsoft\office\16.0\outlook\preferences] "NewOutlookMigrationUserSetting"=dword:00000000
<#
Not set (Default): If you don’t configure this policy, the user setting for automatic migration remains uncontrolled, and users can manage it themselves. By default, this setting is enabled.
1 (Enable): If you enable this policy, the user setting for automatic migration is enforced. Automatic migration to the new Outlook is allowed, and users can't change the setting.
0 (Disable): If you disable this policy, the user setting for automatic migration is turned off. Automatic migration to the new Outlook is blocked, and users can't change the setting.
source : https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/get-started/control-install?branch=main#opt-out-of-new-outlook-migration
#>

[string]$GpoName = 'USER-Disable automatic migration to New Outlook'

$modules = @('GroupPolicy', 'ActiveDirectory')

foreach ($module in $modules) {
    try {
        Import-Module $module -ErrorAction Stop
    }
    catch {
        Write-Warning "Module $module not found"
        return
    }
}

$DC = (Get-ADDomainController -Discover -Service ADWS).Name
$domain = Get-ADDomain
$domainName = $domain.DNSRoot

Write-Host -ForegroundColor Cyan "$GpoName - Create GPO"

try {
    $myGPO = New-GPO -Name $GpoName -Comment 'GPO to disable automatic migration to New Outlook migration' -Domain $domainName -Server $DC -ErrorAction Stop
}
catch {
    Write-Warning "Error creating GPO: $($_.Exception.Message)"
    return
}

# Disable Computer settings
Write-Host "$gpoName - Disable Computer settings and enable User settings" -ForegroundColor Cyan

$gpm = New-Object -ComObject GPMgmt.GPM
$gpmConstants = $gpm.GetConstants()

$domainObject = $gpm.GetDomain($domainName, '', $gpmConstants.UseAnyDC)

$gpoId = (Get-GPO -Name $gpoName -Server $DC).id
$gpoID = $mygpo.id
$domainObject.GetGPO("{$gpoID}").SetUserEnabled($true)
$domainObject.GetGPO("{$gpoID}").SetComputerEnabled($false)

$keyHash = @{
    'NewOutlookMigrationUserSetting' = 0
}

Write-Host -ForegroundColor Cyan "$GpoName - Set registry key"
foreach ($key in $keyHash.Keys) {
    $value = $keyHash[$key]
    Write-Host "$gpoName - Setting $outlookRegPath -> $key to $value" -ForegroundColor Cyan
    try {
        $null = Set-GPPrefRegistryValue -Name $GpoName -Context 'User' -Key 'HKCU\Software\Policies\Microsoft\office\16.0\outlook\preferences' -ValueName $key -Value $value -Type DWord -Action Replace -Server $DC -ErrorAction Stop
    }
    catch {
        Write-Warning "Error setting registry key: $($_.Exception.Message)"
    }
}

Write-Host "`nINFORMATION 1: The GPO '$GpoName' has been created. You must link it to the desired OUs." -ForegroundColor Yellow

Write-Host "`nINFORMATION 2: The GPO settings apply to users. If you filter by user or user groups, ensure that 'Domain Computers' or 'Authenticated Users' have Read permissions: https://learn.microsoft.com/en-us/troubleshoot/windows-server/group-policy/cannot-apply-user-gpo-when-computer-objects-dont-have-read-permissions" -ForegroundColor Yellow

Write-Host "`nINFORMATION 3: Even if you delete the GPO, the registry key will remain on the user's computer. So if you want to enable automatic migration, you must delete the registry key on the device or set the value to 1." -ForegroundColor Yellow