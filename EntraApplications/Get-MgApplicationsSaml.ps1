try {
    Import-Module 'Microsoft.Graph.Applications' -ErrorAction Stop -ErrorVariable mgGraphAppsMissing
    Import-Module 'Microsoft.Graph.Identity.SignIns' -ErrorAction Stop -ErrorVariable mgGraphIdentitySignInsMissing
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

# At the date of writing (23 february 2023), PreferredTokenSigningKeyEndDateTime parameter is only on Beta profile
Select-MgProfile -Name beta

[System.Collections.Generic.List[PSObject]]$samlApplicationsArray = @()
$samlApplications = Get-MgServicePrincipal -Filter "PreferredSingleSignOnMode eq 'saml'"

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