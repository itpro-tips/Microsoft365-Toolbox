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

Connect-MgGraph -Scopes 'Application.Read.All' -NoWelcome 

[System.Collections.Generic.List[PSObject]]$credentialsArray = @()

$mgApps = Get-MgApplication -All

foreach ($mgApp in $mgApps) {
    $owner = Get-MgApplicationOwner -ApplicationId $mgApp.Id

    foreach ($keyCredential in $mgApp.KeyCredentials) {
        $object = [PSCustomObject][ordered]@{
            DisplayName           = $mgApp.DisplayName
            CredentialType        = 'KeyCredentials'
            AppId                 = $mgApp.AppId
            CredentialDescription = $keyCredential.DisplayName
            CredentialStartDate   = $keyCredential.StartDateTime
            CredentialExpiryDate  = $keyCredential.EndDateTime
            # CredentialExpiryDate is date time, compared to now and see it is valid
            CredentialValid       = $keyCredential.EndDateTime -gt (Get-Date)
            Type                  = $keyCredential.Type
            Usage                 = $keyCredential.Usage
            Owners                = $owner.AdditionalProperties.userPrincipalName
        }

        $credentialsArray.Add($object)
    }

    foreach ($passwordCredential in $mgApp.PasswordCredentials) {
        $object = [PSCustomObject][ordered]@{
            DisplayName           = $mgApp.DisplayName
            CredentialType        = 'PasswordCredentials'
            AppId                 = $mgApp.AppId
            CredentialDescription = $passwordCredential.DisplayName
            CredentialStartDate   = $passwordCredential.StartDateTime
            CredentialExpiryDate  = $passwordCredential.EndDateTime
            # CredentialExpiryDate is date time, compared to now and see it is valid
            CredentialValid       = $passwordCredential.EndDateTime -gt (Get-Date)
            Type                  = 'NA'
            Usage                 = 'NA'
            Owners                = $owner.AdditionalProperties.userPrincipalName
        }

        $credentialsArray.Add($object)
    }
}

return $credentialsArray