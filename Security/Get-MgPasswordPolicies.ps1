# need Microsoft.Graph.Users
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
            $validityPeriod = 'Passwords never expire'
        }
        else {
            $validityPeriod = $domain.PasswordValidityPeriodInDays
        }
        
        $object = [PSCustomObject][ordered]@{
            Domain           = $domain.ID
            NotificationDays = $domain.PasswordNotificationWindowInDays
            ValidityPeriod   = $validityPeriod
        }

        $pwdPolicies.Add($object)
    }

    return $pwdPolicies
} 