function Get-MsolRoleReport {
    [CmdletBinding()]
    param (
        [boolean]$IncludeEmptyRoles
    )

    try {
        Import-Module MSOnline -ErrorAction stop
    }
    catch {
        Write-Warning 'First, install MSOnline module : Install-Module MSOnline'
        return
    }

    try {
        $msolRoles = Get-MsolRole -ErrorAction Stop
    }
    catch {
        Connect-MsolService
        $msolRoles = Get-MsolRole
    }

    # Use MsolService because returns more role and allows MFA status 
    #$azureADRoles = Get-AzureADDirectoryRole
    
    $rolesMembership = New-Object 'System.Collections.Generic.List[System.Object]'

    foreach ($msolRole in $msolRoles) {

        # Global administrator is called Company administrator in Microsoft Graph API and Azure AD PowerShell https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/directory-assign-admin-roles#global-administrator--company-administrator
        # Other roles also have another name, but the name is understable
        switch ($msolRole.Name) {
            'Company Administrator' {
                $msolRole.Name = 'Company Administrator/Global administrator'
                break
            }
        }

        Write-Host -ForegroundColor green "Processing role $($msolRole.Name)..." -NoNewline
        
        try {

            $roleMembers = Get-MsolRoleMember -RoleObjectId $msolRole.ObjectId
            
            Write-Host -ForegroundColor green " $($roleMembers.count) member(s) found"

            if ($IncludeEmptyRoles -and $roleMembers.count -eq 0) {
                $object = [PSCustomObject] [ordered]@{
                    'Role'                    = $msolRole.Name
                    'RoleDescription'         = $msolRole.Description
                    'MemberDisplayName'       = '-'
                    'MemberUserPrincipalName' = '-'
                    'MemberEmail'             = '-'
                    'MemberAlternateEmail'    = '-'
                    'RoleMemberType'          = '-'
                    'MemberAccountEnabled'    = '-'
                    'MemberLastDirSyncTime'   = '-'
                    'MemberMFAState'          = '-'
                }
                
                $rolesMembership.Add($object)

                # break the loop
                continue
            }

            foreach ($roleMember in $roleMembers) {
                # Sometimes, user is service account, not present in Office 365. We set ErrorAction SilentlyContinue to prevent error
                $member = Get-MsolUser -objectid $roleMember.ObjectID -ErrorAction SilentlyContinue
                
                $MFAState = $member.StrongAuthenticationRequirements.State
                
                if ($null -eq $MFA) {
                    $MFAState = 'Disabled'
                }

                if ($null -eq $member.LastDirSyncTime) {
                    $lastDirSyncTime = 'Not a synchronized user'
                }
                else {
                    $lastDirSyncTime = $member.LastDirSyncTime
                }

                $object = [PSCustomObject] [ordered]@{
                    'Role'                    = $msolRole.Name
                    'RoleDescription'         = $msolRole.Description
                    'MemberDisplayName'       = $roleMember.DisplayName
                    'MemberUserPrincipalName' = $roleMember.UserPrincipalName
                    'MemberEmail'             = $roleMember.EmailAddress
                    'MemberAlternateEmail'    = $roleMember.AlternateEmailAddresses
                    'RoleMemberType'          = $roleMember.RoleMemberType
                    'MemberAccountEnabled'    = -not $roleMember.AccountEnabled # BlockCredential is the opposite 
                    'MemberLastDirSyncTime'   = $lastDirSyncTime
                    'MemberMFAState'          = $MFAState
                }

                $rolesMembership.Add($object)
            }
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
    
    return $rolesMembership
}