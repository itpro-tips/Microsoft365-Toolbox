<#
.SYNOPSIS
    Get password policies for all domains in the tenant.

.DESCRIPTION
    The Get-MgPasswordPolicies script retrieves password policies for all domains in the tenant.

.OUTPUTS
    PSCustomObject
        The script returns an array of custom PowerShell objects containing the following properties for each domain:
        - Domain: The domain ID.
        - NotificationDays: The number of days before the password expires that the user is notified.
        - ValidityPeriod: The number of days before the password expires.

.NOTES
    Ensure you have the necessary permissions and modules installed to run this script, such as the Microsoft Graph PowerShell module.
    The script assumes that the necessary authentication to Microsoft Graph has already been handled with the Connect-MgGraph function.
    Connect-MgGraph -Scopes 'Domain.Read.All'
#>
function Get-MgPasswordPolicies {   

    [System.Collections.Generic.List[PSObject]]$pwdPolicies = @()

    $modules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Identity.DirectoryManagement'
    )
    
    foreach ($module in $modules) {
        try {
            $null = Get-InstalledModule $module -ErrorAction Stop
        }
        catch {
            Write-Warning "Please install $module first"
            return
        }
    }
    
    $domains = Get-MgDomain -All

    foreach ($domain in $domains) {
    
        if ($domain.PasswordValidityPeriodInDays -eq '2147483647') {
            $validityPeriod = '2147483647 (Passwords never expire)'
        }
        else {
            $validityPeriod = $domain.PasswordValidityPeriodInDays
        }
        
        Write-Host -ForegroundColor Cyan "Note that if you have some federated domains, they don't have password policies because authentication is handled by another IDP (Identity Provider)"

        $object = [PSCustomObject][ordered]@{
            Domain             = $domain.ID
            AuthenticationType = $domain.AuthenticationType
            NotificationDays   = $domain.PasswordNotificationWindowInDays
            ValidityPeriod     = $validityPeriod
        }

        $pwdPolicies.Add($object)
    }

    return $pwdPolicies
} 