<#
.synopsis
    Creates a new Entra ID Application with Message Center Read permissions
.DESCRIPTION
    This script creates a new Entra ID Application with Message Center Read permissions.
    The script will create a new application registration in Microosft Entra ID, create a client secret, and assign the required permissions.
    The script will output the Client ID, Tenant ID, and Client Secret.
    This script will grant admin consent for the application (application permissions, not delegated permissions).
    The script will also provide a URL to check admin consent for the application.
.EXAMPLE
   .\New-EntraIDAppWithMessageCenterRead.ps1 -ApplicationName 'MessageCenterRead'
.NOTES
    Bastien PEREZ
#>

function New-MessageCenterReadAppRegistration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = 'Provide a name for the Message Center Read Application. Example: MessageCenterRead')]
        [string]$ApplicationName = 'MessageCenter-Read'
    )

    $scopes = 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All'
    Write-Host 'Connecting to Microsoft Graph with Scopes: $scopes' -ForegroundColor Cyan

    Connect-MgGraph -Scopes $scopes -NoWelcome

    $tenantDetail = Get-MgOrganization
    $tenantID = $tenantDetail.Id

    $appRegistrationParams = @{
        displayName            = $ApplicationName
        description            = "App registration for $ApplicationName"
        isFallbackPublicClient = 'True'
        signInAudience         = 'AzureADMyOrg'
    }

    Write-Host -ForegroundColor Cyan "Creating $ApplicationName app registration."
    try {
        $mgApp = New-MgApplication -BodyParameter $AppRegistrationParams -ErrorAction Stop
        Write-Host "Successfully created $ApplicationName app registration." -ForegroundColor Green
    }
    catch {
        throw "Failed to create $applicationName app registration: $($_.Exception.Message)"
        return
    }

    # Even if the application is created, the service principal is not created yet, so we need to create it
    Write-Host -ForegroundColor Cyan "Creating service principal for $ApplicationName app registration"
    try {
        $mgSP = New-MgServicePrincipal -AppId $mgApp.AppId -DisplayName $mgApp.DisplayName
    }
    catch {
        throw "Failed to create service principal for $ApplicationName app registration: $($_.Exception.Message)"
        return
    }

    # Create a client secret
    try {
        $passwordCredential = @{
            displayName = "$ApplicationName-Client Secret"
            endDateTime = (Get-Date).AddMonths(12)
        }

        Write-Host -ForegroundColor Cyan "Creating client secret for $ApplicationName"
        $mgAppPassword = Add-MgApplicationPassword -ApplicationId $mgApp.Id -PasswordCredential $passwordCredential
        $clientSecret = $mgAppPassword.SecretText
        Write-Host 'Successfully created client secret.' -ForegroundColor Green
    }
    catch {
        throw "Failed to create client secret: $_"
    }

    Write-Host -ForegroundColor Cyan "Assigning permissions to $ApplicationName app registration."
    # Get the main Microsoft Graph service
    $msGraphId = '00000003-0000-0000-c000-000000000000'
    $msGraphSP = Get-MgServicePrincipal -Filter "AppId eq '$msGraphId'"

    # Creating the required permissions
    $permission = @{
        ResourceAppId  = $graphApiId
        ResourceAccess = @(
            @{
                Id   = ($graphServicePrincipal.AppRoles | Where-Object { $_.Value -eq 'ServiceMessage.Read.All' }).Id
                Type = 'Role'
            }
        )
    }

    Write-Host -ForegroundColor Cyan "Adding required permissions to $ApplicationName app registration."
    Update-MgApplication -ApplicationId $mgApp.Id -RequiredResourceAccess @($permission)   

    $msGraphApp = Get-MgServicePrincipal -Filter "DisplayName eq 'Microsoft Graph'" 
    $appRole = $msGraphApp.AppRoles | Where-Object Value -EQ 'ServiceMessage.Read.All'

    Write-Host -ForegroundColor Cyan "Admin consent for $ApplicationName - Application permissions (not delegated)"
    New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $mgSP.id -PrincipalId $mgSP.Id -ResourceId $msGraphSP.Id -AppRoleId $appRole.Id

    Write-Host 'Client ID:' -ForegroundColor Cyan
    Write-Host "$($mgApp.AppId)"
    Write-Host 'Tenant ID:' -ForegroundColor Cyan
    Write-Host "$($TenantId)"
    Write-Host 'Client Secret:' -ForegroundColor Cyan
    Write-Host "$($ClientSecret)"

    $url = "https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/CallAnAPI/appId/$($mgApp.AppId)/isMSAApp~/false"
    Write-Warning "Check admin grant consent of this app on $url"
}