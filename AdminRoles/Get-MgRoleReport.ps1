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

.NOTES
Written by Bastien Perez (Clidsys.com - ITPro-Tips.com)
For more Office 365/Microsoft 365 tips and news, check out ITPro-Tips.com.

Version history:
V1.0 19 october 2023
V1.1 01 december 2023

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
            Recommendations        = 'Check if the user has alternate email or alternate phone number on Microsoft Entra ID'
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
                    Recommendations        = 'Check if the user has alternate email or alternate phone number on Microsoft Entra ID'
                }

                $rolesMembers.Add($object)
            }
        }
    }

    $object = [PSCustomObject] [ordered]@{
        Principal              = 'Partners'
        "PrincipalDisplayName" = 'Partners'
        "PrincipalType"        = 'Partners'
        "AssignedRole"         = 'Partners'
        "AssignedRoleScope"    = 'Partners'
        "AssignmentType"       = 'Partners'
        "IsBuiltIn"            = 'Partners'
        "RoleTemplate"         = 'Partners'
        DirectMember           = ''
        Recommendations        = 'Please check this URL to identify if you have partner with admin roles https://admin.microsoft.com/AdminPortal/Home#/partners. More information on https://practical365.com/identifying-potential-unwanted-access-by-your-msp-csp-reseller/'
        
    }
    
    $rolesMembers.Add($object)

    return $rolesMembers
}