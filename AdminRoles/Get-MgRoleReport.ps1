<#
.SYNOPSIS
Get-MGRoleReport.ps1 - Reports on Microsoft Entra ID (Azure AD) roles

.DESCRIPTION 
By default, the report contains only the groups with members.
To get all the role, included empty roles, add -IncludeEmptyRoles $true

.OUTPUTS
The report is output to an array contained all the audit logs found.
To export in a csv, do Get-MsolRoleReport | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRoles.csv" -Encoding UTF8

.EXAMPLE
Get-MGRoleReport

.EXAMPLE
Get-MGRoleReport -IncludeEmptyRoles $true

.EXAMPLE
Get-MGRoleReport | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRoles.csv" -Encoding UTF8

.LINK
https://itpro-tips.com/2020/get-the-office-365-admin-roles-and-track-the-changes/
https://github.com/itpro-tips/Microsoft365-Toolbox/blob/master/AdminRoles/Get-MGRoleReport.ps1

.NOTES
Written by Bastien Perez (Clidsys.com - ITPro-Tips.com)
For more Office 365/Microsoft 365 tips and news, check out ITPro-Tips.com.

Version history:
V1.0 19 october 2023

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
        [switch]$IncludeEmptyRoles,
        [String]$GroupNameUsedInConditionnalAccess,
        [switch]$FullDetails,
        [boolean]$IncludePIMEligibleAssignments = $true
    )

    $modules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Identity.Governance'
    )
    try {
        #Import-Module 
    }
    catch {
        Write-Warning "First, install module $module"
        return
    }

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
        Write-Verbose "Collecting PIM eligible role assignments..."
        $mgRoles += (Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty * | Select-Object id, principalId, directoryScopeId, roleDefinitionId, status, principal, @{Name = "RoleDefinitionExtended"; Expression = { $_.roleDefinition } })
    }

    [System.Collections.Generic.List[PSObject]]$rolesMembers = @()


    foreach ($mgRole in $mgRoles) {    
        switch ($mgRole.principal.AdditionalProperties.'@odata.type') {
            '#microsoft.graph.user' { $principal = $mgRole.principal.AdditionalProperties.userPrincipalName; break }
            '#microsoft.graph.servicePrincipal' { $principal = $mgRole.principal.AdditionalProperties.appId; break }
            '#microsoft.graph.group' { $principal = $mgRole.principalid; break }
        }

        $object = [PSCustomObject][ordered]@{    
            Principal              = $principal   
            "PrincipalDisplayName" = $mgRole.principal.AdditionalProperties.displayName
            "PrincipalType"        = $mgRole.principal.AdditionalProperties.'@odata.type'.Split('.')[-1]
            "AssignedRole"         = $mgRole.RoleDefinitionExtended.displayName
            "AssignedRoleScope"    = $mgRole.directoryScopeId
            "AssignmentType"       = if ($mgRole.status -eq 'Provisioned') { 'Eligible' } else { 'Permanent' }
            "IsBuiltIn"            = $mgRole.RoleDefinitionExtended.isBuiltIn
            "RoleTemplate"         = $mgRole.RoleDefinitionExtended.templateId
            DirectMember           = $true
        }

        $rolesMembers.Add($object)

        if ($object.PrincipalType -eq 'group') {
            $group = Get-MgGroup -GroupId $object.Principal

            $groupMembers = Get-MgGroupMember -GroupId $group.Id -Property displayName, userPrincipalName

            foreach ($member in $groupMembers) {
                $object = [PSCustomObject][ordered]@{
                    Principal              = $member.AdditionalProperties.userPrincipalName
                    "PrincipalDisplayName" = $member.AdditionalProperties.displayName
                    "PrincipalType"        = $member
                    "AssignedRole"         = $mgRole.RoleDefinitionExtended.displayName
                    "AssignedRoleScope"    = $mgRole.directoryScopeId
                    "AssignmentType"       = if ($mgRole.status -eq 'Provisioned') { 'Eligible' } else { 'Permanent' }
                    "IsBuiltIn"            = $mgRole.RoleDefinitionExtended.isBuiltIn
                    "RoleTemplate"         = $mgRole.RoleDefinitionExtended.templateId
                    DirectMember           = $false
                }

                $rolesMembers.Add($object)
            }
        }
        
            <#
        try {
            $roleMembers = [array](Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$($mgRole.Id)'")
        }
        catch {
            Write-Warning "Role $($mgRole.DisplayName) search error: $($_.Exception.Message)"
        } 

        # Add green color if member found into the role
        if($null -eq $rolesMembers -and $IncludeEmptyRoles.IsPresent) {
            Write-Host -ForegroundColor Cyan "Role $($mgRole.DisplayName) - Member found: $($roleMembers.count)"
        }
        elseif ($roleMembers.count -gt 0) {
            Write-Host -ForegroundColor Green "Role $($mgRole.DisplayName) - Member(s) found: $($roleMembers.count)"
            $object = [PSCustomObject][ordered]@{
                'Role'                                            = $msolRole.Name
                'RoleDescription'                                 = $msolRole.Description

            $rolesMembers.Add($object)
        }
        else {
            Write-Host -ForegroundColor Cyan "Role $($mgRole.DisplayName) - Member found: $($roleMembers.count)"
        }
        #>
        }

        return $rolesMembers
    }