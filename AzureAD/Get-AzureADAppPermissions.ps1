Function Get-AzureADAppPermissions {

    Write-Host 'Gathering information about Azure AD integrated applications...' -ForegroundColor Cyan

    try { 
        $servicePrincipals = Get-AzureADservicePrincipal -All:$true | Where-Object {$_.Tags -eq 'WindowsAzureActiveDirectoryIntegratedApp'} 
    }
    catch { 
        Write-Host 'You must connect to Azure AD first' -ForegroundColor Red -ErrorAction Stop 
        return
    }

    [System.Collections.Generic.List[PSObject]]$appPermissions = @()

    if (-not ($servicePrincipals.count -gt 0)) {
        Write-Host 'No application authorized' -ForegroundColor Cyan
        return
    }

    $i = 0
    foreach ($servicePrincipal in $servicePrincipals) {
        $i++
        Write-Host "Processing $($servicePrincipal.DisplayName) [$i / $($servicePrincipals.count)]"
        $servicePrincipalPermission = Get-AzureADservicePrincipalOAuth2PermissionGrant -ObjectId $servicePrincipal.ObjectId -All:$true
    
        $OAuthperm = @{}
        [System.Collections.Generic.List[PSObject]]$assignedTo = @()

        $resID = $userId = $null;  

        $valid = ($servicePrincipalPermission.ExpiryTime | Select-Object -Unique | Sort-Object -Descending | Select-Object -First 1)

        $object = [pscustomobject][ordered]@{
            ApplicationName = $servicePrincipal.DisplayName
            ApplicationId   = $servicePrincipal.AppId
            Publisher       = $servicePrincipal.PublisherName
            Homepage        = $servicePrincipal.Homepage
            ObjectId        = $servicePrincipal.ObjectId
            Enabled         = $servicePrincipal.AccountEnabled
            ValidUntil      = $valid
            Permissions     = ''
            AuthorizedBy    = ''
        }
    
        $servicePrincipalPermission | ForEach-Object { #CAN BE DIFFERENT FOR DIFFERENT USERS!
            $resID = (Get-AzureADObjectByObjectId -ObjectIds $_.ResourceId).DisplayName
            if ($_.PrincipalId) { 
                $userId = "(" + (Get-AzureADObjectByObjectId -ObjectIds $_.PrincipalId).UserPrincipalName + ')'
            }
            $OAuthperm["[" + $resID + $userId + "]"] = (($_.Scope.Trim().Split(" ") | Select-Object -Unique) -join ',')
        }

        $object.Permissions = (($OAuthperm.GetEnumerator() | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ';')
    
        if (($servicePrincipalPermission.ConsentType | Select-Object -Unique) -eq 'AllPrincipals') { 
            $assignedto.Add('All users (admin consent)')
        }
        try {
            $assignedto.Add((Get-AzureADObjectByObjectId -ObjectIds ($servicePrincipalPermission.PrincipalId | Select-Object -Unique)).UserPrincipalName)
        }
        catch { }

        $object.AuthorizedBy = $assignedto[0] -join ','
    
        $appPermissions.Add($object)
    }

    return $appPermissions
}