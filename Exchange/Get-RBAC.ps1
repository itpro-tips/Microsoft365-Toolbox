# https://github.com/michevnew/PowerShell/blob/master/Role_assignments_Inventory.ps1
[System.Collections.Generic.List[PSObject]]$roleAssignmentsArray = @()

$roleAssignments = Get-ManagementRoleAssignment -GetEffectiveUsers | Where-Object { $_.RoleAssigneeType -notmatch "RoleAssignmentPolicy|PartnerLinkedRoleGroup" }

function getUPN ($user,$role) {
    $UPN = @(Get-User $user -ErrorAction SilentlyContinue | Where-Object {(Get-ManagementRoleAssignment -Role $role -RoleAssignee $_.SamAccountName -ErrorAction SilentlyContinue)})
    if ($UPN.Count -ne 1) { return $user }
    if ($UPN) { return $UPN.UserPrincipalName }
    else { return $user }
}

#Find the group matching a given DisplayName. If multiple entries are returned, use the -RoleAssignee parameter to determine the correct one. If unique entry is found, return the email address if present, or GUID. Otherwise return DisplayName
function getGroup ($group,$role) {
    $grp = @(Get-Group $group -ErrorAction SilentlyContinue | Where-Object {(Get-ManagementRoleAssignment -Role $role -RoleAssignee $_.SamAccountName -ErrorAction SilentlyContinue)})
    if ($grp.Count -ne 1) { return $group }
    if ($grp) {
        if ($grp.WindowsEmailAddress.ToString()) { return $grp.WindowsEmailAddress.ToString() }
        else { return $grp.Guid.Guid.ToString() }
    }
    else { return $group }
}

foreach ($ra in $RoleAssignments) {

    $count++

    #Since we are using the -GetEffectiveUsers parameter, the number of entries will be huge. And since for each entry we do a Get-User or Get-Group, add some anti-throttling controls via Check-Connectivity
    if ($count / 50 -is [int]) {
        Start-Sleep -Seconds 1
    }

    #Process each Role assignment entry
    # /!\ Careful Effective UserName is in language /!\
    if (($ra.EffectiveUserName -eq 'All Group Members' -or $ra.EffectiveUserName -eq 'Tous les membres du groupe') -and $ra.AssignmentMethod -eq 'Direct') {
        #Only list the "parent" entry when it's not a Role Group or when -IncludeRoleGroups is $true
        if ($ra.RoleAssigneeType -ne 'RoleGroup' -or $IncludeRoleGroups) {
            $object = [PSCustomObject][ordered]@{
                DisplayName    = $ra.RoleAssigneeName
                AssignmentType = $ra.AssignmentMethod
                AssigneeName   = $ra.EffectiveUserName
                Assignee       = (getGroup $ra.RoleAssignee $ra.Role)
                AssigneeType   = $ra.RoleAssigneeType
                AssignedRoles  = ((& { if ($IncludeDelegatingAssingments) { 'Delegating - ' + $ra.Role } else { $ra.Role } }))
            }

        }
        else {
            #User role assignments
            $object = [PSCustomObject][ordered]@{
                DisplayName    = $ra.RoleAssigneeName
                AssignmentType = $ra.AssignmentMethod
                AssigneeName   = $ra.EffectiveUserName
                Assignee       = (getUPN $ra.EffectiveUserName $ra.Role)
                AssigneeType   = 'User'
                AssignedRoles  = (& { if ($IncludeDelegatingAssingments) { 'Delegating - ' + $ra.Role } else { $ra.Role } })
            } 
        }

        $roleAssignmentsArray.Add($object)
    }
}
#return the output
return $roleAssignmentsArray
