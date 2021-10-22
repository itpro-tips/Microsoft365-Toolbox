
Function Get-SPOSitesDetails {
    Param(
        [boolean]$ExcludeOneDrive
    )

    if (-not(Get-Module AzureADPreview -ListAvailable)) {
        Write-Warning "To use Office 365 groupes template, you must install AzureADPreview. Please run:
	Uninstall-Module AzureAD
	Install-Module AzureADPreview
	
	Note: After the Team creation, you can switch to the non Preview version:
	Uninstall-Module AzureADPreview
	Install-Module AzureAD
	"
	
        exit
    }

    if (-not(Get-Module MicrosoftTeams -ListAvailable)) {
        Write-Warning "Please install MicrosoftTeams PowerShell module:
	Install-Module MicrosoftTeams
	"
        exit
    }

    if (-not(Get-Module Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
        Write-Warning "Please install SharePoint Online PowerShell module:
	http://www.microsoft.com/en-us/download/details.aspx?id=35588
	"
        exit
    }

    Function Get-TeamEnabled {
        Param(
            $Group
        )
	
        $teamEnabled = $false
 
        try {
            $group = Get-MailboxFolderStatistics -Identity $group.Alias -IncludeOldestAndNewestItems -FolderScope ConversationHistory | Select-Object FolderType
        }
        catch {
	
        }
        if ($group.FolderType -eq 'TeamChat') {
            $teamEnabled = $true
        }
        else {
            $teamEnabled = $false
        }
	
        return $teamEnabled
    }


    # Define a new object to gather output
    [System.Collections.Generic.List[PSObject]]$spoSitesInfos = @()

    Write-Verbose 'Get SharePoint Online sites Details'
    if($ExcludeOneDrive) {
        $spoSites = Get-SPOSite -Limit All -IncludePersonalSite $false

    }
    else {
        $spoSites = Get-SPOSite -Limit All -IncludePersonalSite $true
    }

    $directorySettings = (Get-AzureADDirectorySetting).Values
    if (-not($directorySettings)) {
        Write-Warning 'Unable to get AzureADDirectorySetting (default?)'
    }
    else {
        $groupCreation = ($directorySettings | Where-Object { $_.Name -eq 'EnableGroupCreation' }).Value
        $groupCreationAllowedGroupId = ($directorySettings | Where-Object { $_.Name -eq 'GroupCreationAllowedGroupId' }).Value
        $allowToAddGuest = ($directorySettings | Where-Object { $_.Name -eq "AllowToAddGuests" }).Value
        $allowGuestsToAccessGroups = ($directorySettings | Where-Object { $_.Name -eq "AllowGuestsToAccessGroups" }).Value
        $allowGuestsToBeGroupOwner = ($directorySettings | Where-Object { $_.Name -eq "AllowGuestsToBeGroupOwner" }).Value

        if ($groupCreation) {
            if ($groupCreationAllowedGroupId) {
                Write-Host 'Office 365 Groups (or Teams) creation only allows for :'
                Get-AzureADGroup -ObjectID $groupCreationAllowedGroupId
            }
            else	{
                Write-Warning 'Office 365 Groups (or Teams) creation only allows for all Office 365 users.'
            }
        }
        else {
            Write-Host 'Office 365 Groups (or Teams) creation disabled.'
        }

        if ($allowToAddGuest) {
            Write-Warning "Guest are enabled:
	    `n`t Guest can be group owner : $allowGuestsToBeGroupOwner
	    `n`t Guest can acces to group: $allowGuestsToAccessGroups"
        }
        else {
            Write-Host "Guest are disabled."
        }

    }


    # TOdo create hashtable pour aller plus vite

    $allO365Groups = Get-UnifiedGroup -ResultSize Unlimited
    $hash = @{}

    $allO365Groups | ForEach-Object {
        if ($_.SharePointSiteUrl -and $_.ExternalDirectoryObjectId) {
            $hash.Add($_.SharePointSiteUrl, $_.ExternalDirectoryObjectId)
        }
    }


    Write-Verbose "SharePoint Online sites Count is $($spoSites.count)"

    foreach ($spoSite in $spoSites) {
        Write-Verbose "Get details for SharePoint site $($object.Url)"

        $object = $spoSite
    
        $groupID = $null
        # Init variables    
        $ChannelCount = $TeamUsers = $TeamOwnerCount = $TeamMemberCount = $TeamGuestCount = $visibility = $archived = $groupID = $url = $siteOwner = $membersCount = $sharing = $sharingAllowedDomain = $sharingBlockedDomain = 'NULL'
        $owners = $ownersCount = $membersCount = $guestsCount = 'NULL'

        $teamsEnabled = $isO365Group = $false
    
        $url = $object.Url

        if ($object.SharingAllowedDomainList) {
            $sharingAllowedDomain = $object.SharingAllowedDomainList
        }
    
        if ($object.SharingBlockedDomainList) {
            $sharingBlockedDomain = $object.SharingBlockedDomainList
        }

        # Check if Office 365 group
        if ($object.template -eq 'GROUP#0') {
            # https://office365itpros.com/2019/08/15/reporting-group-enabled-sharepoint-online-sites/
            # do not working anymore because -detailed deprecated and not return groupID
            #$groupID = (Get-SpoSite $object.Url -Detailed).GroupId.Guid

            $groupID = $hash[$object.url]
            #        (Get-UnifiedGroup | Where-Object {$_.SharePointSiteUrl -eq $object.url}).ExternalDirectoryObjectId
        
            # Check if the Office 365 Group exists
            if ($groupID) {
                $membersCount = $O365Group.GroupMemberCount
            
                # Check if Office 365 group has a team
                try {
                    $team = Get-Team -GroupId $GroupId
                    $teamsEnabled = $true
                }
                catch {
                    $teamsEnabled = $False
                }
			
                if ($teamsEnabled) {		
                    try {				
                        #Get channel details
                        $Channels = $null

                        $Channels = Get-TeamChannel -GroupId $groupId
                        $ChannelCount = $Channels.count
			
                        # Get Owners, members and guests

                        $TeamUsers = Get-TeamUser -GroupId $groupId

                        $owners = ($TeamUsers | Where-Object { $_.Role -like 'owner' }).User -join '|'
                        $ownersCount = ($TeamUsers | Where-Object { $_.Role -like 'owner' }).count
                    

                        $membersCount = ($TeamUsers | Where-Object { $_.Role -like 'member' }).count
                        $guestsCount = ($TeamUsers | Where-Object { $_.Role -like 'guest' }).count
                        $visibility = $object.Visibility
                        $archived = $object.Archived
                    }
                    catch {
			
                    }
                }
            }
        }

        # Put all details into an object

        $object = [pscustomobject][ordered] @{
            Title                   = $spoSite.Title
            Url                     = $object.Url
            Description             = $object.Description
            GroupID                 = $groupId
            IsMicrosoftTeam         = $teamsEnabled
            Visibility              = $visibility
            Archived                = $archived
            StorageLimit            = (($spoSite.StorageQuota) / 1024).ToString("N")
            StorageUsed             = (($spoSite.StorageUsageCurrent) / 1024).ToString("N")
            Owner                   = $spoSite.Owner
            SharingCapability       = $spoSite.SharingCapability
            SharingAllowedDomain    = $spoSite.SharingAllowedDomainList
            LockState               = $spoSite.LockState
            Template                = $spoSite.Template
            ConditionalAccessPolicy = $spoSite.ConditionalAccessPolicy
            ChannelCount            = $ChannelCount
            Owners                  = $owners
            OwnersCount             = $ownersCount
            MembersCount            = $membersCount
            GuestsCount             = $guestsCount    
        }

        # owner
        #     LastContent  = $Site.LastContentModifiedDate
        # manque lacces externe

        $spoSitesInfos.Add($object)
    }

    return $spoSitesInfos
}