# need Microsoft.Graph.Users
function Get-MgUsersAndPasswordPolicies {   
    $modules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Users'
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
    
    # don't know if a user can have more than one password policy
    $users = Get-MgUser -All -Property UserPrincipalName, PasswordPolicies | Select-Object -Property UserPrincipalName, @{Name = 'PasswordPolicies'; Expression = { $_.PasswordPolicies -join '|' } }

    return $users
} 