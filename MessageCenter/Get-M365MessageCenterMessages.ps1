function Get-M365MessageCenterMessages {
    [CmdLetbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$ClientID,
        [Parameter(Mandatory = $true)]
        [String]$ClientSecret,
        [Parameter(Mandatory = $true)]
        [String]$TenantDomain
    )
    
    $body = @{
        grant_type    = 'client_credentials'
        resource      = 'https://graph.microsoft.com'
        client_id     = $ClientID
        client_secret = $ClientSecret
        earliest_time = "-$($Hours)h@s"
    }

    $oauth = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$($TenantDomain)/oauth2/token?api-version=1.0" -Body $body
    $headerParams = @{'Authorization' = "$($oauth.token_type) $($oauth.access_token)" }
    
    try {
        $allMessages = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/admin/serviceAnnouncement/messages' -Headers $headerParams -Method GET -ErrorAction Stop
    }
    catch {
        Write-Warning "$($_.Exception.Message -replace "`n", ' ' -replace "`r", ' ')"

        return
    }
    
    $output = @{ }
    $output.MessageCenterInformation = foreach ($Message in $AllMessages.Value) {

        [PSCustomObject]@{
            Id                       = $Message.Id
            Title                    = $Message.Title
            Service                  = $Message.services
            LastUpdatedTime          = if ($Message.lastModifiedDateTime) { [DateTime]::Parse($Message.lastModifiedDateTime.ToString()) } else { $null }
            LastUpdatedDays          = if ($Message.lastModifiedDateTime) { ((Get-Date).Subtract([DateTime]::Parse($Message.lastModifiedDateTime.ToString()))).Days } else { $null }
            ActionRequiredByDateTime = if ( $Message.actionRequiredByDateTime) { [DateTime]::Parse($Message.actionRequiredByDateTime.ToString()) } else { $null }
            RoadmapId                = ($Message.details | Where-Object { $_.name -eq 'roadmapids' }).Value
            Category                 = $Message.category
        }
    }

    $output.MessageCenterInformationExtended = foreach ($Message in $AllMessages.Value) {
        [PSCustomObject] @{
            Id                       = $Message.Id
            Title                    = $Message.Title
            Service                  = $Message.services
            LastUpdatedTime          = if ($Message.lastModifiedDateTime) { [DateTime]::Parse($Message.lastModifiedDateTime.ToString()) } else { $null }
            LastUpdatedDays          = if ($Message.lastModifiedDateTime) { ((Get-Date).Subtract([DateTime]::Parse($Message.lastModifiedDateTime.ToString()))).Days } else { $null }
            ActionRequiredByDateTime = if ($Message.actionRequiredByDateTime) { [DateTime]::Parse($Message.actionRequiredByDateTime.ToString()) } else { $null }
            Tags                     = $Message.Tags
            Bloglink                 = ($Message.details | Where-Object { $_.name -eq 'bloglink' }).Value
            RoadmapId                = ($Message.details | Where-Object { $_.name -eq 'roadmapids' }).Value
            RoadmapIdLinks           = ($Message.details | Where-Object { $_.name -eq 'roadmapids' }).Value | ForEach-Object {
                "https://www.microsoft.com/en-us/microsoft-365/roadmap?filters=&searchterms=$_"
            }
            Category                 = $Message.category
            IsMajorChange            = $Message.isMajorChange
            Severity                 = $Message.Severity
            StartTime                = If ($Message.startDateTime) { [DateTime]::Parse($Message.startDateTime.ToString()) } else { $null }
            EndTime                  = if ($Message.endDateTime) { [DateTime]::Parse($Message.endDateTime.ToString()) } else { $null }
            Message                  = $Message.body.content
        }
    }

    $output
}