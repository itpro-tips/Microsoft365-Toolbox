<#
.SYNOPSIS
Get-MsolRoleReport.ps1 - Reports on Office 365 Admin Role

.DESCRIPTION 
This script produces a report of the membership of Office 365 admin role groups.
By default, the report contains only the groups with members.
To get all the role, included empty roles, add -IncludeEmptyRoles $true

.OUTPUTS
The report is output to an array contained all the audit logs found.
To export in a csv, do Get-MsolRoleReport | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRoles.csv" -Encoding UTF8

.EXAMPLE
Get-MsolRoleReport

.EXAMPLE
Get-MsolRoleReport -IncludeEmptyRoles $true

.EXAMPLE
Get-MsolRoleReport | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRoles.csv" -Encoding UTF8

.LINK
https://itpro-tips.com/2020/get-the-office-365-admin-roles-and-track-the-changes/
https://github.com/itpro-tips/Microsoft365-Toolbox/blob/master/AdminRoles/Get-MsolRoleReport.ps1

.NOTES
Written by Bastien Perez (Clidsys.com - ITPro-Tips.com)
For more Office 365/Microsoft 365 tips and news, check out ITPro-Tips.com.

Version history:
V1.0, 17 august 2020 - Initial version
V1.1, 05 april 2022 - Add alternate email, Phone number, PIN
V1.2, 27 april april 2022 - Add GroupNameUsedInConditionnalAccess to check if user is member of group used in conditionnal access
V1.3, 2 may 2022 - Add Partners links

/!\
/!\
/!\
CAREFUL, THIS SCRIPT CAN STOP WORKING AFTER DECEMBER 2022 DUE TO MICROSOFT DELETION OF MSOL AND AZURE AD MODULES
https://office365itpros.com/2022/03/17/azure-ad-powershell-deprecation/
/!\
/!\
/!\

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.

#>
function Get-MsolRoleReport {
    [CmdletBinding()]
    param (
        [boolean]$IncludeEmptyRoles,
        [String]$GroupNameUsedInConditionnalAccess
    )

    try {
        Import-Module MSOnline -ErrorAction stop
    }
    catch {
        Write-Warning 'First, install the official Microsoft MSOnline module : Install-Module MSOnline'
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
    [System.Collections.Generic.List[PSObject]]$rolesMembers = @()

    foreach ($msolRole in $msolRoles) {

        # Global administrator is called Company administrator in Microsoft Graph API and Azure AD PowerShell https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/directory-assign-admin-roles#global-administrator--company-administrator
        # Other roles also have another name, but the name is understable
        switch ($msolRole.Name) {
            'Company Administrator' {
                $msolRole.Name = 'Company Administrator/Global administrator'
                break
            }
        }
        
        try {

            $roleMembers = @(Get-MsolRoleMember -RoleObjectId $msolRole.ObjectId)

            # Add green color if member found into the role
            if ($roleMembers.count -gt 0) {
                Write-Host -ForegroundColor Green "Role $($msolRole.Name) - Member(s) found: $($roleMembers.count)"
            }
            else {
                Write-Host -ForegroundColor Cyan "Role $($msolRole.Name) - Member found: $($roleMembers.count)"
            }

            if ($IncludeEmptyRoles -and $roleMembers.count -eq 0) {
                $object = [PSCustomObject] [ordered]@{
                    'Role'                                            = $msolRole.Name
                    'RoleDescription'                                 = $msolRole.Description
                    'MemberDisplayName'                               = '-'
                    'MemberUserPrincipalName'                         = '-'
                    'MemberEmail'                                     = '-'
                    'RoleMemberType'                                  = '-'
                    'MemberAccountEnabled'                            = '-'
                    'MemberLastDirSyncTime'                           = '-'
                    'MemberMFAState(IgnoreIfConditionalAccessIsUsed)' = '-'
                    'MemberStrongAuthNDefaultMethodType'              = '-'   
                    'MemberObjectID'                                  = '-'
                    'MemberAlternateEmailAddresses'                   = '-'
                    'MemberStrongAuthNEmail'                          = '-'
                    'MemberStrongAuthNPin'                            = '-'
                    'MemberStrongAuthNOldPin'                         = '-'
                    'MemberStrongAuthNPhoneNumber'                    = '-'
                    'MemberStrongAuthNAlternativePhoneNumber'         = '-'
                    'Recommendations'                                 = '-'
                }

                $rolesMembers.Add($object)

            }
            else {
                foreach ($roleMember in $roleMembers) {                
                    # if user already exist in the arraylist, we look for to prevent a new Get-MsolUser (time consuming)
                    # Select only the first if user already exists in multiple roles
                    if ($rolesMembers.MemberObjectID -contains $roleMember.ObjectID) {
                        $found = $rolesMembers | Where-Object { $_.MemberObjectID -eq $roleMember.ObjectID } | Select-Object -First 1
                        $object = [PSCustomObject][ordered]@{
                            'Role'                                            = $msolRole.Name
                            'RoleDescription'                                 = $msolRole.Description
                            'MemberDisplayName'                               = $found.MemberDisplayName
                            'MemberUserPrincipalName'                         = $found.MemberUserPrincipalName
                            'MemberEmail'                                     = $found.MemberEmail
                            'RoleMemberType'                                  = $found.RoleMemberType
                            'MemberAccountEnabled'                            = $found.MemberAccountEnabled
                            'MemberLastDirSyncTime'                           = $found.MemberLastDirSyncTime
                            'MemberMFAState(IgnoreIfConditionalAccessIsUsed)' = $found.'MemberMFAState(IgnoreIfConditionalAccessIsUsed)'
                            'MemberStrongAuthNDefaultMethodType'              = $found.MemberStrongAuthNDefaultMethodType
                            'MemberObjectID'                                  = $found.MemberObjectID
                            'MemberAlternateEmailAddresses'                   = $found.MemberAlternateEmailAddresses
                            'MemberStrongAuthNEmail'                          = $found.MemberStrongAuthNEmail
                            'MemberStrongAuthNPin'                            = $found.MemberStrongAuthNPin
                            'MemberStrongAuthNOldPin'                         = $found.MemberStrongAuthNOldPin
                            'MemberStrongAuthNPhoneNumber'                    = $found.MemberStrongAuthNPhoneNumber
                            'MemberStrongAuthNAlternativePhoneNumber'         = $found.MemberStrongAuthNAlternativePhoneNumber
                            'Recommendations'                                 = $found.Recommendations
                        }
                    }
                    else {
                        if ($roleMember.RoleMemberType -eq 'ServicePrincipal') {
                            $member = Get-MsolServicePrincipal -SearchString $roleMember.DisplayName
                        }
                        # Sometimes, user is service account, not present in Office 365. We set ErrorAction SilentlyContinue to prevent error. not handle non user type
                        else {
                            $member = Get-MsolUser -ObjectId $roleMember.ObjectID -ErrorAction SilentlyContinue
                        }
                    
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
                            'Role'                                            = $msolRole.Name
                            'RoleDescription'                                 = $msolRole.Description
                            'MemberDisplayName'                               = $roleMember.DisplayName
                            'MemberUserPrincipalName'                         = $member.UserPrincipalName
                            'MemberEmail'                                     = $roleMember.EmailAddress
                            'RoleMemberType'                                  = $roleMember.RoleMemberType
                            'MemberAccountEnabled'                            = -not $member.AccountEnabled # BlockCredential is the opposite 
                            'MemberLastDirSyncTime'                           = $lastDirSyncTime
                            'MemberMFAState(IgnoreIfConditionalAccessIsUsed)' = $MFAState
                            'MemberStrongAuthNDefaultMethodType'              = if ($null -eq ($member.StrongAuthenticationMethods | Where-Object { $_.IsDefault -eq $true }).MethodType) { '-' } else { ($member.StrongAuthenticationMethods | Where-Object { $_.IsDefault -eq $true }).MethodType }
                            'MemberObjectID'                                  = $member.ObjectId
                            'MemberAlternateEmailAddresses'                   = if (($member.AlternateEmailAddresses.count -eq 0)) { '-' } else { $member.AlternateEmailAddresses -join '|' }
                            'MemberStrongAuthNEmail'                          = if ($null -eq $member.StrongAuthenticationUserDetails.Email) { '-' } else { $member.StrongAuthenticationUserDetails.Email }
                            'MemberStrongAuthNPin'                            = if ($null -eq $member.StrongAuthenticationUserDetails.Pin) { '-' } else { $member.StrongAuthenticationUserDetails.Pin }
                            'MemberStrongAuthNOldPin'                         = if ($null -eq $member.StrongAuthenticationUserDetails.OldPin) { '-' } else { $member.StrongAuthenticationUserDetails.OldPin }
                            'MemberStrongAuthNPhoneNumber'                    = if ($null -eq $member.StrongAuthenticationUserDetails.PhoneNumber) { '-' } else { $member.StrongAuthenticationUserDetails.PhoneNumber }
                            'MemberStrongAuthNAlternativePhoneNumber'         = if ($null -eq $member.StrongAuthenticationUserDetails.AlternativePhoneNumber) { '-' } else { $member.StrongAuthenticationUserDetails.AlternativePhoneNumber }
                            'Recommendations'                                 = ''
                        }

                        $recommendationsString = $null

                        if ($object.MemberAlternateEmailAddresses -ne '-') {
                            $recommendationsString = "alternate email address (user profile in Azure AD portal) = $($object.MemberAlternateEmailAddresses);"
                        } 

                        if ($object.MemberStrongAuthNEmail -ne '-') {
                            $recommendationsString += "authentication email (Authentication Methods in Azure AD portal) = $($object.MemberStrongAuthNEmail);"
                        }   

                        if ($object.MemberStrongAuthNPhoneNumber -ne '-') {
                            $recommendationsString += "phone number = $($object.MemberStrongAuthNPhoneNumber);"
                        }   

                        if ($object.MemberStrongAuthNAlternativePhoneNumber -ne '-') {
                            $recommendationsString += "alternate phone number = $($object.MemberStrongAuthNAlternativePhoneNumber);"
                        }   
                    
                        if ($null -ne $recommendationsString) {
                            $object.Recommendations = "Be careful about this admin user. If someone access the following phone(s)/email(s), he can reset the user password: $recommendationsString"
                        }
                    }

                    $rolesMembers.Add($object)
                }
            }
        }
        catch {
            Write-Warning $_.Exception.Message
        }

    }
    
    $object = [PSCustomObject] [ordered]@{
        'Role'                                            = 'Partners'
        'RoleDescription'                                 = 'Partners'
        'MemberDisplayName'                               = 'Partners'
        'MemberUserPrincipalName'                         = 'Partners'
        'MemberEmail'                                     = 'Partners'
        'RoleMemberType'                                  = 'Partners'
        'MemberAccountEnabled'                            = 'Partners'
        'MemberLastDirSyncTime'                           = 'Partners'
        'MemberMFAState(IgnoreIfConditionalAccessIsUsed)' = 'Partners'
        'MemberStrongAuthNDefaultMethodType'              = 'Partners'
        'MemberObjectID'                                  = 'Partners'
        'MemberAlternateEmailAddresses'                   = 'Partners'
        'MemberStrongAuthNEmail'                          = 'Partners'
        'MemberStrongAuthNPin'                            = 'Partners'
        'MemberStrongAuthNOldPin'                         = 'Partners'
        'MemberStrongAuthNPhoneNumber'                    = 'Partners'
        'MemberStrongAuthNAlternativePhoneNumber'         = 'Partners'
        'Recommendations'                                 = 'Please check this URL to identify if you have partner with admin roles https://admin.microsoft.com/AdminPortal/Home#/partners. More information on https://practical365.com/identifying-potential-unwanted-access-by-your-msp-csp-reseller/'
    }

    $rolesMembers.Add($object)

    if ($GroupNameUsedInConditionnalAccess) {

        $tempRolesMembers = New-Object 'System.Collections.Generic.List[System.Object]'

        $msolGroup = Get-MsolGroup -SearchString $GroupNameUsedInConditionnalAccess
        $msolGroupMembers = Get-MsolGroupMember -GroupObjectId $msolGroup.ObjectID

        foreach ($roleMember in $rolesMembers) {
            $isMember = $false

            if ($msolGroupMembers.ObjectId -contains $roleMember.MemberObjectID) {
                $isMember = $true
            }

            $roleMember | Add-Member -MemberType NoteProperty -Name MemberOfGroupUsedByConditionnalAccess -Value $isMember

            $tempRolesMembers.Add($roleMember)
        }

        $rolesMembers = $tempRolesMembers        

    }

    return $rolesMembers
}