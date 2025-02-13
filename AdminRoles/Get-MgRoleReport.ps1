<#
.SYNOPSIS
Get-MgRoleReport.ps1 - Reports on Microsoft Entra ID (Azure AD) roles

.DESCRIPTION 
By default, the report contains only the roles with members.
To get all the role, included empty roles, add -IncludeEmptyRoles $true

.OUTPUTS
The report is output to an array contained all the audit logs found.
To export in a csv, do Get-MgRoleReport | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRoles.csv" -Encoding UTF8

.EXAMPLE
Get-MgRoleReport

.EXAMPLE
Get-MgRoleReport -IncludeEmptyRoles $true

.EXAMPLE
Get-MgRoleReport | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRoles.csv" -Encoding UTF8

.LINK
https://itpro-tips.com/get-the-office-365-admin-roles-and-track-the-changes/

.NOTES
Written by Bastien Perez (Clidsys.com - ITPro-Tips.com)
For more Office 365/Microsoft 365 tips and news, check out ITPro-Tips.com.

Version History:
#[1.4] - 2025-02-13
### Added
- Sign-in activity tracking.
- Account enabled status.
- On-premises sync enabled status.
- Remove old parameters

## [1.3] - 2024-05-15
### Changed
- Changes not specified.

## [1.2] - 2024-03-13
### Changed
- Changes not specified.

## [1.1] - 2023-12-01
### Changed
- Changes not specified.

## [1.0] - 2023-10-19
### Initial Release

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.

#>
function Get-MgRoleReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [boolean]$IncludePIMEligibleAssignments = $true,
        [Parameter(Mandatory = $false)]
        [switch]$ForceNewToken
    )

    $modules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Identity.Governance'
        'Microsoft.Graph.Users'
        'Microsoft.Graph.Groups'
    )
    
    foreach ($module in $modules) {
        try {
            Import-Module $module -ErrorAction Stop 
        }
        catch {
            Write-Warning "First, install module $module"
            return
        }
    }

    if ($ForceNewToken.IsPresent) {
        $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
    }

    Write-Host -ForegroundColor Cyan 'Connecting to Microsoft Graph. Scopes: Directory.Read.All'
    $null = Connect-MgGraph -Scopes 'Directory.Read.All' -NoWelcome

    try {
        #$mgRoles = Get-MgRoleManagementDirectoryRoleDefinition -ErrorAction Stop
        
        $mgRoles = Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty Principal
        # The maximum property is 1 so we need to do a second request to get the role definition
        $mgRolesDefinition = Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty roleDefinition
    }
    catch {
        Write-Warning $($_.Exception.Message)   
    }   
    
    foreach ($mgRole in $mgRoles) {
        Add-Member -InputObject $mgRole -MemberType NoteProperty -Name RoleDefinitionExtended -Value ($mgRolesDefinition | Where-Object { $_.id -eq $mgRole.id }).roleDefinition 
    } # Add the role definition to the object

    if ($IncludePIMEligibleAssignments) {
        Write-Verbose 'Collecting PIM eligible role assignments...'
        try {
            $mgRoles += (Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty * -ErrorAction Stop | Select-Object id, principalId, directoryScopeId, roleDefinitionId, status, principal, @{Name = 'RoleDefinitionExtended'; Expression = { $_.roleDefinition } })
        }
        catch {
            Write-Warning "Unable to get PIM eligible role assignments: $($_.Exception.Message)"
        }
    }

    [System.Collections.Generic.List[PSObject]]$rolesMembers = @()

    foreach ($mgRole in $mgRoles) {    
        $principal = switch ($mgRole.principal.AdditionalProperties.'@odata.type') {
            '#microsoft.graph.user' { $mgRole.principal.AdditionalProperties.userPrincipalName; break }
            '#microsoft.graph.servicePrincipal' { $mgRole.principal.AdditionalProperties.appId; break }
            '#microsoft.graph.group' { $mgRole.principalid; break }
            'default' { '-' }
        }

        $object = [PSCustomObject][ordered]@{    
            Principal              = $principal   
            'PrincipalDisplayName' = $mgRole.principal.AdditionalProperties.displayName
            'PrincipalType'        = $mgRole.principal.AdditionalProperties.'@odata.type'.Split('.')[-1]
            'AssignedRole'         = $mgRole.RoleDefinitionExtended.displayName
            'AssignedRoleScope'    = $mgRole.directoryScopeId
            'AssignmentType'       = if ($mgRole.status -eq 'Provisioned') { 'Eligible' } else { 'Permanent' }
            'IsBuiltIn'            = $mgRole.RoleDefinitionExtended.isBuiltIn
            'RoleTemplate'         = $mgRole.RoleDefinitionExtended.templateId
            DirectMember           = $true
            Recommendations        = 'Check if the user has alternate email or alternate phone number on Microsoft Entra ID'
        }

        $rolesMembers.Add($object)

        if ($object.PrincipalType -eq 'group') {
            $group = Get-MgGroup -GroupId $object.Principal

            $groupMembers = Get-MgGroupMember -GroupId $group.Id -Property displayName, userPrincipalName

            foreach ($member in $groupMembers) {
                $typeMapping = @{
                    '#microsoft.graph.user'             = 'user'
                    '#microsoft.graph.group'            = 'group'
                    '#microsoft.graph.servicePrincipal' = 'servicePrincipal'
                    '#microsoft.graph.device'           = 'device'
                    '#microsoft.graph.orgContact'       = 'contact'
                    '#microsoft.graph.application'      = 'application'
                }

                $memberType = if ($typeMapping[$member.AdditionalProperties.'@odata.type']) {
                    $typeMapping[$member.AdditionalProperties.'@odata.type']
                }
                else {
                    'Unknown'
                }

                $object = [PSCustomObject][ordered]@{
                    Principal              = $member.AdditionalProperties.userPrincipalName
                    'PrincipalDisplayName' = $member.AdditionalProperties.displayName
                    'PrincipalType'        = $memberType
                    'AssignedRole'         = $mgRole.RoleDefinitionExtended.displayName
                    'AssignedRoleScope'    = $mgRole.directoryScopeId
                    'AssignmentType'       = if ($mgRole.status -eq 'Provisioned') { 'Eligible' } else { 'Permanent' }
                    'IsBuiltIn'            = $mgRole.RoleDefinitionExtended.isBuiltIn
                    'RoleTemplate'         = $mgRole.RoleDefinitionExtended.templateId
                    DirectMember           = $false
                    Recommendations        = 'Check if the user has alternate email or alternate phone number on Microsoft Entra ID'
                }

                $rolesMembers.Add($object)
            }
        }
    }

    $object = [PSCustomObject] [ordered]@{
        Principal              = 'Partners'
        'PrincipalDisplayName' = 'Partners'
        'PrincipalType'        = 'Partners'
        'AssignedRole'         = 'Partners'
        'AssignedRoleScope'    = 'Partners'
        'AssignmentType'       = 'Partners'
        'IsBuiltIn'            = 'Partners'
        'RoleTemplate'         = 'Partners'
        DirectMember           = ''
        Recommendations        = 'Please check this URL to identify if you have partner with admin roles https://admin.microsoft.com/AdminPortal/Home#/partners. More information on https://practical365.com/identifying-potential-unwanted-access-by-your-msp-csp-reseller/'
    }    
    
    $rolesMembers.Add($object)

    #foreach user, we check if the user is global administrator. If global administrator, we add a new parameter to the object recommandationRole to tell the other role is not useful
    $globalAdminsHash = @{}
    $rolesMembers | Where-Object { $_.AssignedRole -eq 'Global Administrator' } | ForEach-Object {
        $globalAdminsHash[$_.Principal] = $true
    }

    $rolesMembers | ForEach-Object {
        if ($globalAdminsHash.ContainsKey($_.Principal) -and $_.AssignedRole -ne 'Global Administrator') {
            $_ | Add-Member -MemberType NoteProperty -Name 'RecommandationRole' -Value 'This user is Global Administrator. The other role(s) is/are not useful'
        }
        else {
            $_ | Add-Member -MemberType NoteProperty -Name 'RecommandationRole' -Value ''
        }
    }

    [System.Collections.Generic.List[Object]]$usersCacheArray = @()

    foreach ($member in $rolesMembers) {

        $lastSignInDateTime = $null
        $accountEnabled = $null
        $onPremisesSyncEnabled = $null

        if ($member.PrincipalType -eq 'user') {
            if ($usersCacheArray.UserPrincipalName -Contains $member.Principal) {
                $accountEnabled = ($usersCacheArray | Where-Object { $_.UserPrincipalName -eq $member.Principal }).AccountEnabled
                $lastSignInDateTime = ($usersCacheArray | Where-Object { $_.UserPrincipalName -eq $member.Principal }).LastSignInDateTime
                $onPremisesSyncEnabled = ($usersCacheArray | Where-Object { $_.UserPrincipalName -eq $member.Principal }).onPremisesSyncEnabled
            }
            else {
                #$member.User = Get-MgUser -UserId $member.Principal -Property AccountEnabled, SignInActivity, onPremisesSyncEnabled
                # If we use Get-MgUser -UserId $member.Principal -Property AccountEnabled, SignInActivity, onPremisesSyncEnabled, 
                # we encounter the error 'Get-MgUser_Get: Get By Key only supports UserId, and the key must be a valid GUID'.
                # This is because the sign-in data comes from a different source that requires a GUID to retrieve the account's sign-in activity. 
                # Therefore, we must provide the account's object identifier for the command to function correctly.
                # To overcome this issue, we use the -Filter parameter to search for the user by their UserPrincipalName.
                $mgUser = Get-MgUser -Filter "UserPrincipalName eq '$($member.Principal)'" -Property UserPrincipalName, AccountEnabled, SignInActivity, onPremisesSyncEnabled | Select-Object UserPrincipalName, AccountEnabled, @{Name = 'LastSignInDateTime'; Expression = { $_.SignInActivity.LastSignInDateTime } }, onPremisesSyncEnabled
                
                $accountEnabled = $mgUser.AccountEnabled
                $lastSignInDateTime = $mgUser.LastSignInDateTime
                $onPremisesSyncEnabled = $mgUser.onPremisesSyncEnabled

                # add the user to the cache to avoid multiple requests for this user
                $usersCacheArray.Add($mgUser)
            }
        }

        $member | Add-Member -MemberType NoteProperty -Name 'LastSignInDateTime' -Value $lastSignInDateTime
        $member | Add-Member -MemberType NoteProperty -Name 'AccountEnabled' -Value $accountEnabled
        $member | Add-Member -MemberType NoteProperty -Name 'onPremisesSyncEnabled' -Value $onPremisesSyncEnabled
    }

    return $rolesMembers
}