<#
.CHANGELOG

[2.0.0] - 2025-03-17
# Changed
- Add warning message to inform the user that the script may become obsolete due to the deprecation of MSOnline in April 2025.

[1.0.0] - 2024-07-7
# Initial Version  

#>

function Get-MsolPasswordPolicies {   

    [System.Collections.Generic.List[PSObject]]$pwdPolicies = @()

    Write-Warning 'This script may become obsolete due to the deprecation of MSOnline in April 2025. Ensure compatibility with newer modules such as Microsoft Graph PowerShell before use.'
    Write-Warning 'Prefer to use Get-MgPasswordPolicies script instead.'

    Get-MsolDomain | ForEach-Object {    
        $domain = $_.Name
        $pwdPolicy = Get-MsolPasswordPolicy -DomainName $_.Name

        if ($pwdPolicy.ValidityPeriod -eq '2147483647') {
            $validityPeriod = 'Password never expire'
        }
        
        $object = [PSCustomObject][ordered]@{
            Domain           = $domain
            NotificationDays = $pwdPolicy.NotificationDays
            ValidityPeriod   = $validityPeriod
        }

        $pwdPolicies.Add($object)
    }

    return $pwdPolicies
} 