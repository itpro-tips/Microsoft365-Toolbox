# To see in the audit logs if the password was changed by user ot by Azure AD Connect, we can use my own script:
#Get-MgAuditLogs -Activity 'Change user password' | Where-Object InitiatedBy -like '*@domain*'
function Get-MgPasswordInformation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$UserPrincipalName
    )

    $modules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Users'
    )
    
    [System.Collections.Generic.List[PSObject]]$passwordsInfoArray = @()

    foreach ($module in $modules) {
        try {
            $null = Get-InstalledModule $module -ErrorAction Stop
        }
        catch {
            Write-Warning "Please install $module first"
            return
        }
    }

    if ($UserPrincipalName) {
        [System.Collections.Generic.List[PSObject]]$users = @()
        foreach ($upn in $UserPrincipalName) {
            # don't know if a user can have more than one password policy
            $u = Get-MgUser -UserId $upn -Property UserPrincipalName, LastPasswordChangeDateTime, OnPremisesLastSyncDateTime, OnPremisesSyncEnabled, PasswordProfile, PasswordPolicies, @{Name = 'PasswordPolicies'; Expression = { $_.PasswordPolicies -join '|' } }

            $users.Add($u)
        }
    }
    else {
        $users = Get-MgUser -All -Property UserPrincipalName, LastPasswordChangeDateTime, OnPremisesLastSyncDateTime, OnPremisesSyncEnabled, PasswordProfile, PasswordPolicies, @{Name = 'PasswordPolicies'; Expression = { $_.PasswordPolicies -join '|' } }
    }
   
    foreach ($user in $users) {
        $object = [PSCustomObject][ordered]@{
            UserPrincipalName                    = $user.UserPrincipalName
            LastPasswordChangeDateTimeUTC        = $user.LastPasswordChangeDateTime
            OnPremisesLastSyncDateTimeUTC        = $user.OnPremisesLastSyncDateTime
            OnPremisesSyncEnabled                = $user.OnPremisesSyncEnabled
            ForceChangePasswordNextSignIn        = $user.PasswordProfile.ForceChangePasswordNextSignIn
            ForceChangePasswordNextSignInWithMfa = $user.PasswordProfile.ForceChangePasswordNextSignInWithMfa
            PasswordPolicies                     = $user.PasswordPolicies
        }
    
        $passwordsInfoArray.Add($object)
    }

    return $passwordsInfoArray
} 