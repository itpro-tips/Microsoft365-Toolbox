function Get-MsolPasswordPolicies {   

    [System.Collections.Generic.List[PSObject]]$pwdPolicies = @()

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