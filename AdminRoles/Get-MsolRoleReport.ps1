<#
.SYNOPSIS
Get-MsolRoleReport.ps1 - Reports on Office 365 Admin Role

.DESCRIPTION 
This script produces a report of the membership of Office 365 admin role groups.
By default, the report contains only the groups with members.
To get all the role, included empty roles, add -IncludeEmptyRoles $true

.OUTPUTS
The report is output to an array contained all the audit logs found.
To export in a csv, do Get-MsolRoleReport | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRolesChange.csv"

.EXAMPLE
Get-MsolRoleReport

.EXAMPLE
Get-MsolRoleReport.ps1 -IncludeEmptyRoles $true

.LINK
https://itpro-tips.com/2020/get-the-office-365-admin-roles-and-track-the-changes/

.NOTES
Written by Bastien Perez (ITPro-Tips.com)
For more Office 365/Microsoft 365 tips and news, check out ITPro-Tips.com.

Version history:
V1.0, 17 august 2020 - Initial version

Copyright (c) 2020 Bastien Perez (ITPro-Tips.com)

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
        [boolean]$IncludeEmptyRoles
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