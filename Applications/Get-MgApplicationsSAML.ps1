# article : https://itpro-tips.com/get-azure-ad-saml-certificate-details/
# the information about the SAML applications clams is not available in the Microsoft Graph API v1 but in https://main.iam.ad.ext.azure.com/api/ApplicationSso/<service-principal-id>/FederatedSsoV2 so we don't get them
try {
    # At the date of writing (december 2023), PreferredTokenSigningKeyEndDateTime parameter is only on Beta profile
    Import-Module 'Microsoft.Graph.Beta.Applications' -ErrorAction Stop -ErrorVariable mgGraphAppsMissing
    Import-Module 'Microsoft.Graph.Beta.Identity.SignIns' -ErrorAction Stop -ErrorVariable mgGraphIdentitySignInsMissing
}
catch {
    if ($mgGraphAppsMissing) {
        Write-Warning "Failed to import Microsoft.Graph.Applications module: $($mgGraphAppsMissing.Exception.Message)"
    }
    if ($mgGraphIdentitySignInsMissing) {
        Write-Warning "Failed to import Microsoft.Graph.Identity.SignIns module: $($mgGraphIdentitySignInsMissing.Exception.Message)"
    }
    return
}

Connect-MgGraph -Scopes 'Application.Read.All'

[System.Collections.Generic.List[PSObject]]$samlApplicationsArray = @()
$samlApplications = Get-MgBetaServicePrincipal -Filter "PreferredSingleSignOnMode eq 'saml'"

foreach ($samlApp in $samlApplications) {
    $object = [PSCustomObject][ordered]@{
        DisplayName                         = $samlApp.DisplayName
        Id                                  = $samlApp.Id
        AppId                               = $samlApp.AppId
        LoginUrl                            = $samlApp.LoginUrl
        LogoutUrl                           = $samlApp.LogoutUrl
        NotificationEmailAddresses          = $samlApp.NotificationEmailAddresses -join '|'
        AppRoleAssignmentRequired           = $samlApp.AppRoleAssignmentRequired
        PreferredSingleSignOnMode           = $samlApp.PreferredSingleSignOnMode
        PreferredTokenSigningKeyEndDateTime = $samlApp.PreferredTokenSigningKeyEndDateTime
        # PreferredTokenSigningKeyEndDateTime is date time, compared to now and see it is valid
        PreferredTokenSigningKeyValid       = $samlApp.PreferredTokenSigningKeyEndDateTime -gt (Get-Date)
        ReplyUrls                           = $samlApp.ReplyUrls -join '|'
        SignInAudience                      = $samlApp.SignInAudience
    }

    $samlApplicationsArray.Add($object)
}

return $samlApplicationsArray