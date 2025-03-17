<#
.CHANGELOG

[1.0.0] - 2025-03-17
# Initial Version  

#>

function Get-MgPasswordPolicies { 

    [System.Collections.Generic.List[PSObject]]$pwdPolicies = @()

    $domains = Get-MgDomain
    
    foreach ($domain in $domains) {
        
        if ($domain.PasswordValidityPeriodInDays -eq '2147483647') {
            $pwddValidityPeriodInDays = 'Password never expire'
        }
        else {
            $pwddValidityPeriodInDays = $domain.PasswordValidityPeriodInDays
        }
        
        $object = [PSCustomObject][ordered]@{
            Domain                           = $domain.Id
            PasswordValidityPeriodInDays     = $pwddValidityPeriodInDays
            PasswordNotificationWindowInDays = $domain.PasswordNotificationWindowInDays
        }

        $pwdPolicies.Add($object)
    }

    return $pwdPolicies
} 