# DEPRECATED

[System.Collections.Generic.List[PSObject]]$samlApplicationsArray = @()
$samlApplications = Get-AzureADServicePrincipal -All $true | Where-Object {($_.Tags -contains 'WindowsAzureActiveDirectoryGalleryApplicationNonPrimaryV1') -or ($_.Tags -contains 'WindowsAzureActiveDirectoryCustomSingleSignOnApplication')}

foreach ($samlApp in $samlApplications) {
    $object = [PSCustomObject][ordered]@{
        DisplayName                         = $samlApp.DisplayName
        Id                                  = $samlApp.ObjectId
        AppId                               = $samlApp.AppId
        LoginUrl                            = $samlApp.LoginUrl
        LogoutUrl                           = $samlApp.LogoutUrl
        NotificationEmailAddresses          = $samlApp.NotificationEmailAddresses -join '|'
        AppRoleAssignmentRequired           = ''
        PreferredSingleSignOnMode           = ''
        PreferredTokenSigningKeyEndDateTime = ''
        # PreferredTokenSigningKeyEndDateTime is date time, compared to now and see it is valid
        PreferredTokenSigningKeyValid       = ''
        PreferredTokenSigningKeyThumbprint = $samlApp.PreferredTokenSigningKeyThumbprint
        ReplyUrls                           = $samlApp.ReplyUrls -join '|'
        SignInAudience                      = $samlApp.SignInAudience
    }

    $samlApplicationsArray.Add($object)
}

return $samlApplicationsArray