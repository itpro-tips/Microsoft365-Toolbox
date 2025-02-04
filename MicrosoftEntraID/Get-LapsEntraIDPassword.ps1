function Get-LapsEntraIDPassword {
    param(
        [string]$DeviceID,
        [switch]$IncludePasswords,
        [switch]$AsPlainText,
        [switch]$IncludeHistory
    )

    #Connect to Microsoft Graph
    #Connect-MgGraph -Scope DeviceLocalCredential.Read.All, Device.Read.All

    #Define your device name here
    #$DeviceName = ''
    #Store the device id value for your target device
    #$DeviceId = (Get-MgDevice -All | Where-Object { $_.DisplayName -eq $DeviceName } | Select-Object DeviceId).DeviceId

    #Define the URI path
    $uri = 'v1.0/directory/deviceLocalCredentials/' + $DeviceId
    # ?$select=credentials will cause the server to return all credentials, ie latest plus history

    if ($IncludePasswords.IsPresent) {
        $uri = $uri + '?$select=credentials'
    }

    #Generate a new correlation ID
    $correlationID = [System.Guid]::NewGuid()
        
    #Build the request header
    $headers = @{}
    $headers.Add('ocp-client-name', 'Get-LapsAADPassword Windows LAPS Cmdlet')
    $headers.Add('ocp-client-version', '1.0')
    $headers.Add('client-request-id', $correlationID)

    #Initation the request to Microsoft Graph for the LAPS password
    $response = Invoke-MgGraphRequest -Method GET -Uri $URI -Headers $headers -OutputType Json

    # Build custom PS output object
    $resultsJson = ConvertFrom-Json $response
    
    $lapsDeviceId = $resultsJson.deviceName

    $lapsDeviceId = New-Object([System.Guid])
    $lapsDeviceId = [System.Guid]::Parse($resultsJson.id)

    # Grab password expiration time (only applies to the latest password)
    $lapsPasswordExpirationTime = Get-Date $resultsJson.refreshDateTime

    if ($IncludePasswords) {
        # Copy the credentials array
        $credentials = $resultsJson.credentials

        # Sort the credentials array by backupDateTime.
        $credentials = $credentials | Sort-Object -Property backupDateTime -Descending

        # Note: current password (ie, the one most recently set) is now in the zero position of the array

        # If history was not requested, truncate the credential array down to just the latest one
        if (-not $IncludeHistory) {
            $credentials = @($credentials[0])
        }

        foreach ($credential in $credentials) {

            # Cloud returns passwords in base64, convert:
            if ($AsPlainText) {
                $password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($credential.passwordBase64))
            }
            else {
                $bytes = [System.Convert]::FromBase64String($credential.passwordBase64)

                $plainText = [System.Text.Encoding]::UTF8.GetString($bytes)

                $password = ConvertTo-SecureString $plainText -AsPlainText -Force
            }

            $lapsPasswordExpirationTime = $null

            $object = [PSCustomObject][ordered]@{
                DeviceName             = $resultsJson.deviceName
                DeviceId               = $lapsDeviceId
                Account                = $credential.accountName
                Password               = $password
                PasswordExpirationTime = $lapsPasswordExpirationTime
                PasswordUpdateTime     = Get-Date $credential.backupDateTime
            }

            $object
        }
    }
    else {
        # Output a single object that just displays latest password expiration time
        # Note, $IncludeHistory is ignored even if specified in this case
        $object = [PSCustomObject][ordered]@{
            DeviceName             = $resultsJson.deviceName
            DeviceId               = $lapsDeviceId
            PasswordExpirationTime = $lapsPasswordExpirationTime
        }

        $object
    }

}