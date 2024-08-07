# To see in the audit logs if the password was changed by user ot by Azure AD Connect, we can use my own script:
#Get-MgAuditLogs -Activity 'Change user password' | Where-Object InitiatedBy -like '*@domain*'

<#
.SYNOPSIS
    Retrieves and processes user password information from Microsoft Graph and get information about the user's password, such as the last password change date, on-premises sync status, and password policies.

.DESCRIPTION
    The Get-MgUserPasswordInfo script collects details such as the user's principal name, last password change date, on-premises sync status, and password policies.

.PARAMETER UserPrincipalName
    Specifies the user principal name(s) of the user(s) for which to retrieve password information.
    
.EXAMPLE
    Get-MgUserPasswordInfo
    Retrieves password information for all users and outputs it (default behavior).

.EXAMPLE
    Get-MgUserPasswordInfo -UserPrincipalName xxx@domain.com
    Retrieves password information for the specified user and outputs it

.OUTPUTS
    PSCustomObject
        The script returns an array of custom PowerShell objects containing the following properties for each user:
        - UserPrincipalName: The user's principal name.
        - LastPasswordChangeDateTimeUTC: The last date and time the user's password was changed.
        - OnPremisesLastSyncDateTimeUTC: The last date and time the user's on-premises directory was synchronized.
        - OnPremisesSyncEnabled: Indicates whether on-premises synchronization is enabled for the user.
        - ForceChangePasswordNextSignIn: Indicates whether the user is required to change their password at the next sign-in.
        - ForceChangePasswordNextSignInWithMfa: Indicates whether the user is required to change their password at the next sign-in with multi-factor authentication.
        - PasswordPolicies: The user's password policies. Can be : Empty, 'None' or 'DisablePasswordExpiration' (the last one is especially for synced users).
        - PasswordNotificationWindowInDays: The number of days before the password expires that the user is notified.
        - PasswordValidityPeriodInDays: The number of days before the password expires.

.NOTES
    Ensure you have the necessary permissions and modules installed to run this script, such as the Microsoft Graph PowerShell module.
    The script assumes that the necessary authentication to Microsoft Graph has already been handled with the Connect-MgGraph function.
    Connect-MgGraph -Scopes 'User.Read.All', 'Domain.Read.All'
#>
function Get-MgUserPasswordInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string[]]$UserPrincipalName,
        [Parameter(Mandatory = $false)]
        [switch]$PasswordPoliciesByDomainOnly
    )
    
    $modules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Users'
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

    [System.Collections.Generic.List[PSObject]]$domainPasswordPolicies = @()
    [System.Collections.Generic.List[PSObject]]$passwordsInfoArray = @()

    Write-Host -ForegroundColor Cyan 'Retrieving password policies for all domains'
    $domains = Get-MgDomain -All
    

    foreach ($domain in $domains) {
    
        if ($domain.PasswordValidityPeriodInDays -eq '2147483647') {
            $validityPeriod = '2147483647 (Password never expire)'
        }
        else {
            $validityPeriod = $domain.PasswordValidityPeriodInDays
        }
        
        $object = [PSCustomObject][ordered]@{
            Domain             = $domain.ID
            AuthenticationType = $domain.AuthenticationType
            NotificationDays   = $domain.PasswordNotificationWindowInDays
            ValidityPeriod     = $validityPeriod
        }

        $domainPasswordPolicies.Add($object)
    }

    if ($PasswordPoliciesByDomainOnly.IsPresent) {
        Write-Host -ForegroundColor Cyan "Note that if you have some federated domains, they don't have password policies because authentication is handled by another IDP (Identity Provider)"

        return $domainPasswordPolicies
    }

    if ($UserPrincipalName) {
        [System.Collections.Generic.List[PSObject]]$users = @()
        
        Write-Host -ForegroundColor Cyan "Retrieving password information for $($userprincipalname.count) user(s)"
        
        foreach ($upn in $UserPrincipalName) {
            # don't know if a user can have more than one password policy
            $user = Get-MgUser -UserId $upn -Property UserPrincipalName, LastPasswordChangeDateTime, OnPremisesLastSyncDateTime, OnPremisesSyncEnabled, PasswordProfile, PasswordPolicies, @{Name = 'PasswordPolicies'; Expression = { $_.PasswordPolicies -join '|' } }

            $users.Add($user)
        }
    }
    else {
        Write-Host -ForegroundColor Cyan 'Retrieving password information for all users'
        
        $users = [array](Get-MgUser -All -Property UserPrincipalName, LastPasswordChangeDateTime, OnPremisesLastSyncDateTime, OnPremisesSyncEnabled, PasswordProfile, PasswordPolicies, @{Name = 'PasswordPolicies'; Expression = { $_.PasswordPolicies -join '|' } })
    }
   
    foreach ($user in $users) {
        $userDomain = $user.UserPrincipalName.Split('@')[1]
        $object = [PSCustomObject][ordered]@{
            UserPrincipalName                    = $user.UserPrincipalName
            LastPasswordChangeDateTimeUTC        = $user.LastPasswordChangeDateTime
            OnPremisesLastSyncDateTimeUTC        = $user.OnPremisesLastSyncDateTime
            OnPremisesSyncEnabled                = $user.OnPremisesSyncEnabled
            ForceChangePasswordNextSignIn        = $user.PasswordProfile.ForceChangePasswordNextSignIn
            ForceChangePasswordNextSignInWithMfa = $user.PasswordProfile.ForceChangePasswordNextSignInWithMfa
            PasswordPolicies                     = $user.PasswordPolicies
            Domain                               = $userDomain
            PasswordNotificationWindowInDays     = ($domainPasswordPolicies | Where-Object Domain -eq $userDomain).NotificationDays
            PasswordValidityPeriodInDays         = ($domainPasswordPolicies | Where-Object Domain -eq $userDomain).ValidityPeriod
        }
    
        $passwordsInfoArray.Add($object)
    }

    return $passwordsInfoArray
} 