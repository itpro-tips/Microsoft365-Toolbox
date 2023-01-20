# Admin must be site admin to get all properties
# Set-SPOUser -Site hxxx -LoginName xxx@xxx.onmicrosoft.com -IsSiteCollectionAdmin $true

# TODO : use LastItemUserModifiedDate but need to connect with ctx. or with PNP to each site
Function Get-SPOSitesDetails {
    [CmdletBinding()]
    Param(
        [boolean]$ExcludeOneDrive,
        [boolean]$OnlyOneDrive,
        [boolean]$M365GroupsDetails,
        [string]$SiteURL,
        [boolean]$SharingRightsAdminOrFullControl,
        [boolean]$regionalSettingsDetails
    )

    # https://diecknet.de/en/2021/07/09/Sharepoint-Online-Timezones-by-PowerShell/
    function Convert-SPOTimezoneToString(
        # ID of a SPO Timezone
        [int]$ID
    ) {
        <#
        .SYNOPSIS
        Convert a Sharepoint Online Time zone ID to a human readable string.

        .NOTES
        By Andreas Dieckmann - https://diecknet.de
        Timezone IDs according to https://docs.microsoft.com/en-us/dotnet/api/microsoft.sharepoint.spregionalsettings.timezones?view=sharepoint-server#Microsoft_SharePoint_SPRegionalSettings_TimeZones

        Licensed under MIT License
        Copyright 2021 Andreas Dieckmann

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

        .EXAMPLE
        Convert-SPOTimezoneToString 14
        (UTC-09:00) Alaska

        .LINK
        https://diecknet.de/en/2021/07/09/Sharepoint-Online-Timezones-by-PowerShell/
        #>

        $timezoneIDs = @{
            39  = "(UTC-12:00) International Date Line West"
            95  = "(UTC-11:00) Coordinated Universal Time-11"
            15  = "(UTC-10:00) Hawaii"
            14  = "(UTC-09:00) Alaska"
            78  = "(UTC-08:00) Baja California"
            13  = "(UTC-08:00) Pacific Time (US and Canada)"
            38  = "(UTC-07:00) Arizona"
            77  = "(UTC-07:00) Chihuahua, La Paz, Mazatlan"
            12  = "(UTC-07:00) Mountain Time (US and Canada)"
            55  = "(UTC-06:00) Central America"
            11  = "(UTC-06:00) Central Time (US and Canada)"
            37  = "(UTC-06:00) Guadalajara, Mexico City, Monterrey"
            36  = "(UTC-06:00) Saskatchewan"
            35  = "(UTC-05:00) Bogota, Lima, Quito"
            10  = "(UTC-05:00) Eastern Time (US and Canada)"
            34  = "(UTC-05:00) Indiana (East)"
            88  = "(UTC-04:30) Caracas"
            91  = "(UTC-04:00) Asuncion"
            9   = "(UTC-04:00) Atlantic Time (Canada)"
            81  = "(UTC-04:00) Cuiaba"
            33  = "(UTC-04:00) Georgetown, La Paz, Manaus, San Juan"
            28  = "(UTC-03:30) Newfoundland"
            8   = "(UTC-03:00) Brasilia"
            85  = "(UTC-03:00) Buenos Aires"
            32  = "(UTC-03:00) Cayenne, Fortaleza"
            60  = "(UTC-03:00) Greenland"
            90  = "(UTC-03:00) Montevideo"
            103 = "(UTC-03:00) Salvador"
            65  = "(UTC-03:00) Santiago"
            96  = "(UTC-02:00) Coordinated Universal Time-02"
            30  = "(UTC-02:00) Mid-Atlantic"
            29  = "(UTC-01:00) Azores"
            53  = "(UTC-01:00) Cabo Verde"
            86  = "(UTC) Casablanca"
            93  = "(UTC) Coordinated Universal Time"
            2   = "(UTC) Dublin, Edinburgh, Lisbon, London"
            31  = "(UTC) Monrovia, Reykjavik"
            4   = "(UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna"
            6   = "(UTC+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague"
            3   = "(UTC+01:00) Brussels, Copenhagen, Madrid, Paris"
            57  = "(UTC+01:00) Sarajevo, Skopje, Warsaw, Zagreb"
            69  = "(UTC+01:00) West Central Africa"
            83  = "(UTC+01:00) Windhoek"
            79  = "(UTC+02:00) Amman"
            5   = "(UTC+02:00) Athens, Bucharest, Istanbul"
            80  = "(UTC+02:00) Beirut"
            49  = "(UTC+02:00) Cairo"
            98  = "(UTC+02:00) Damascus"
            50  = "(UTC+02:00) Harare, Pretoria"
            59  = "(UTC+02:00) Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius"
            101 = "(UTC+02:00) Istanbul"
            27  = "(UTC+02:00) Jerusalem"
            7   = "(UTC+02:00) Minsk (old)"
            104 = "(UTC+02:00) E. Europe"
            100 = "(UTC+02:00) Kaliningrad (RTZ 1)"
            26  = "(UTC+03:00) Baghdad"
            74  = "(UTC+03:00) Kuwait, Riyadh"
            109 = "(UTC+03:00) Minsk"
            51  = "(UTC+03:00) Moscow, St. Petersburg, Volgograd (RTZ 2)"
            56  = "(UTC+03:00) Nairobi"
            25  = "(UTC+03:30) Tehran"
            24  = "(UTC+04:00) Abu Dhabi, Muscat"
            54  = "(UTC+04:00) Baku"
            106 = "(UTC+04:00) Izhevsk, Samara (RTZ 3)"
            89  = "(UTC+04:00) Port Louis"
            82  = "(UTC+04:00) Tbilisi"
            84  = "(UTC+04:00) Yerevan"
            48  = "(UTC+04:30) Kabul"
            58  = "(UTC+05:00) Ekaterinburg (RTZ 4)"
            87  = "(UTC+05:00) Islamabad, Karachi"
            47  = "(UTC+05:00) Tashkent"
            23  = "(UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi"
            66  = "(UTC+05:30) Sri Jayawardenepura"
            62  = "(UTC+05:45) Kathmandu"
            71  = "(UTC+06:00) Astana"
            102 = "(UTC+06:00) Dhaka"
            46  = "(UTC+06:00) Novosibirsk (RTZ 5)"
            61  = "(UTC+06:30) Yangon (Rangoon)"
            22  = "(UTC+07:00) Bangkok, Hanoi, Jakarta"
            64  = "(UTC+07:00) Krasnoyarsk (RTZ 6)"
            45  = "(UTC+08:00) Beijing, Chongqing, Hong Kong, Urumqi"
            63  = "(UTC+08:00) Irkutsk (RTZ 7)"
            21  = "(UTC+08:00) Kuala Lumpur, Singapore"
            73  = "(UTC+08:00) Perth"
            75  = "(UTC+08:00) Taipei"
            94  = "(UTC+08:00) Ulaanbaatar"
            20  = "(UTC+09:00) Osaka, Sapporo, Tokyo"
            72  = "(UTC+09:00) Seoul"
            70  = "(UTC+09:00) Yakutsk (RTZ 8)"
            19  = "(UTC+09:30) Adelaide"
            44  = "(UTC+09:30) Darwin"
            18  = "(UTC+10:00) Brisbane"
            76  = "(UTC+10:00) Canberra, Melbourne, Sydney"
            43  = "(UTC+10:00) Guam, Port Moresby"
            42  = "(UTC+10:00) Hobart"
            99  = "(UTC+10:00) Magadan"
            68  = "(UTC+10:00) Vladivostok, Magadan (RTZ 9)"
            107 = "(UTC+11:00) Chokurdakh (RTZ 10)"
            41  = "(UTC+11:00) Solomon Is., New Caledonia"
            108 = "(UTC+12:00) Anadyr, Petropavlovsk-Kamchatsky (RTZ 11)"
            17  = "(UTC+12:00) Auckland, Wellington"
            97  = "(UTC+12:00) Coordinated Universal Time+12"
            40  = "(UTC+12:00) Fiji"
            92  = "(UTC+12:00) Petropavlovsk-Kamchatsky - Old"
            67  = "(UTC+13:00) Nuku'alofa"
            16  = "(UTC+13:00) Samoa"
        }

        $timezoneString = $timezoneIDs.Get_Item($ID)

        if ($null -ne $timezoneString) {
            return $timezoneString
        }
        else {
            return $ID
        }
    }   

    if (-not(Get-Module AzureADPreview -ListAvailable)) {
        Write-Warning "To use Microsoft 365 groups template, you must install AzureADPreview. Please run:
	Uninstall-Module AzureAD
	Install-Module AzureADPreview
	
	Note: After the Team creation, you can switch to the non Preview version:
	Uninstall-Module AzureADPreview
	Install-Module AzureAD
	"
	
        return
    }

    if (-not(Get-Module MicrosoftTeams -ListAvailable)) {
        Write-Warning "Please install MicrosoftTeams PowerShell module:
	Install-Module MicrosoftTeams
	"
        return
    }

    if (-not(Get-Module Microsoft.Online.SharePoint.PowerShell -ListAvailable)) {
        Write-Warning "Please install SharePoint Online PowerShell module:
	http://www.microsoft.com/en-us/download/details.aspx?id=35588
	"
        return
    }

    # Define a new object to gather output
    [System.Collections.Generic.List[PSObject]]$spoSitesInfos = @()

    Write-Verbose 'Get SharePoint Online sites Details'
    if ($siteurl) {
        $spoSites = Get-SPOSite -Identity $SiteURL
    }
    else {
        if ($ExcludeOneDrive) {
            $spoSites = Get-SPOSite -Limit All -IncludePersonalSite $false
        }
        else {
            $spoSites = Get-SPOSite -Limit All -IncludePersonalSite $true
        }
    
        if ($OnlyOneDrive) {
            $spoSites = $spoSites | Where-Object { $_.Url -like '*-my.sharepoint.com/personal/*' }
        }
    }
    
    if ($M365GroupsDetails) {
        $directorySettings = (Get-AzureADDirectorySetting).Values
        if (-not($directorySettings)) {
            Write-Warning 'Unable to get AzureADDirectorySetting (default?)'
        }
        else {
            $groupCreation = ($directorySettings | Where-Object { $_.Name -eq 'EnableGroupCreation' }).Value
            $groupCreationAllowedGroupId = ($directorySettings | Where-Object { $_.Name -eq "GroupCreationAllowedGroupId" }).Value
            $allowToAddGuest = ($directorySettings | Where-Object { $_.Name -eq "AllowToAddGuests" }).Value
            $allowGuestsToAccessGroups = ($directorySettings | Where-Object { $_.Name -eq "AllowGuestsToAccessGroups" }).Value
            $allowGuestsToBeGroupOwner = ($directorySettings | Where-Object { $_.Name -eq "AllowGuestsToBeGroupOwner" }).Value

            if ($groupCreation) {
                if ($groupCreationAllowedGroupId) {
                    Write-Host 'Microsoft 365 Groups (or Teams) creation only allows for :'
                    Get-AzureADGroup -ObjectID $groupCreationAllowedGroupId
                }
                else {
                    Write-Warning 'Microsoft 365 Groups (or Teams) creation only allows for all Microsoft 365 users.'
                }
            }
            else {
                Write-Host 'Microsoft 365 Groups (or Teams) creation disabled.'
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

        $allM365Groups = Get-UnifiedGroup -ResultSize Unlimited
        
        $hash = @{}
        $hashWhenCreated = @{}

        $allM365Groups | ForEach-Object {
            if ($_.SharePointSiteUrl -and $_.PrimarySmtpAddress) {
                $hash.Add($_.SharePointSiteUrl, $_.PrimarySmtpAddress)
                
            }
            if ($_.SharePointSiteUrl -and $_.WhenCreatedUTC) {
                $hashWhenCreated.Add($_.SharePointSiteUrl, $_.WhenCreatedUTC)
            }
        }
    }

    Write-Verbose "SharePoint Online sites Count is $($spoSites.count)"

    foreach ($spoSite in $spoSites) {
        Write-Verbose "Get details for SharePoint site $($spoSite.Url)"
    
        $groupID = $null
        # Init variables    
        $channelCount = $teamUsers = $TeamOwnerCount = $TeamMemberCount = $TeamGuestCount = $groupID = $siteOwner = $membersCount = $sharing = $sharingAllowedDomain = $sharingBlockedDomain = $groupID = $spoSiteAdmins = 'NULL'
        
        $ChannelCount = $teamUsers = $owners = $ownersCount = $membersCount = $guestsCount = $visibility = $archived = $team = $null 
        
        $regionalSettings = $type = $null

        if ($M365GroupsDetails) {
            $teamsEnabled = $isM365Group = $false
        }

        if ($spoSite.SharingAllowedDomainList) {
            $sharingAllowedDomain = $spoSite.SharingAllowedDomainList -join '|'
        }
    
        if ($spoSite.SharingBlockedDomainList) {
            $sharingBlockedDomain = $spoSite.SharingBlockedDomainList -join '|'
        }

        if ($M365GroupsDetails) {
            $groupID = $sposite.RelatedGroupId.Guid

            if ($groupID -eq '00000000-0000-0000-0000-000000000000') {
                $type = 'SharePoint Site'
            }
            
            # Check if Microsoft 365 group
            elseif ($sposite.template -eq 'GROUP#0') {
                # https://office365itpros.com/2019/08/15/reporting-group-enabled-sharepoint-online-sites/
                # do not working anymore because -detailed deprecated and not return groupID
                #$groupID = (Get-SpoSite $spoSite.Url -Detailed).GroupId.Guid

                #$groupID = $hash[$sposite.url][0]
                # $groupID = $sposite.RelatedGroupId.Guid

                # (Get-UnifiedGroup | Where-Object {$_.SharePointSiteUrl -eq $spoSite.url}).ExternalDirectoryObjectId
        
                # Check if the Microsoft 365 Group exists
                if ($null -ne $hash[$sposite.url]) {
                    $membersCount = $M365Group.GroupMemberCount
                    $type = 'M365 Group'

                    # Check if Microsoft 365 group has a team
                    try {
                        $team = Get-Team -GroupId $GroupId -ErrorAction Stop
                        $teamsEnabled = $true
                    }
                    catch {
                        $teamsEnabled = $False
                    }
			
                    if ($teamsEnabled) {
                        try {
                            #Get channel details
                            $channels = $null

                            $channels = Get-TeamChannel -GroupId $groupId
                            $ChannelCount = $channels.count

                            # Get Owners, members and guests

                            $teamUsers = Get-TeamUser -GroupId $groupId

                            $owners = ($teamUsers | Where-Object { $_.Role -like 'owner' }).User -join '|'
                            $ownersCount = ($teamUsers | Where-Object { $_.Role -like 'owner' }).count

                            $membersCount = ($teamUsers | Where-Object { $_.Role -like 'member' }).count
                            $guestsCount = ($teamUsers | Where-Object { $_.Role -like 'guest' }).count
                            $visibility = $team.Visibility
                            $archived = $team.Archived
                        }
                        catch {

                        }
                    }
                }
                else {
                    $type = 'M365 group but not connected (?)'
                }
            }
        }

        if ($regionalSettingsDetails) {
            $regionalSettings = (Get-SPOSiteScriptFromWeb -WebUrl $sposite.url -IncludeRegionalSettings | ConvertFrom-Json).actions
            $lang = [globalization.cultureinfo][int]$sposite.localeid
        }
        # spo site admins need to be found by user/ cast to arry to get .count
        [array]$spoSiteAdmins = (Get-SPOUser -Site $spoSite.Url -Limit All | Where-Object { $_.IsSiteAdmin }).LoginName

        # source: https://onedrive.live.com/?authkey=%21AOu1SovQbowVNPU&cid=0CAD1DAC2D5DF9C0&id=CAD1DAC2D5DF9C0%211321&parId=CAD1DAC2D5DF9C0%21113&o=OneUp
        
        #Get all Groups from the site permissions
        if ($SharingRightsAdminOrFullControl) {
            $sitegroups = Get-SPOSiteGroup -Site $spoSite.Url -Limit 99999
    
            #Get Group info and members that have site owners permissions
            foreach ($sitegroup in $sitegroups) {
                if ($role.Contains('Site Owner')) {
                    $roleSiteOwner = $sitegroup.Users
                } 
            
                if ($role.Contains('Full Control')) {
                    $roleFullControl = $sitegroup.Users
                }
            }
        }

        # Put all details into an object
        $params = [ordered] @{
            SPTitle                                     = $spoSite.Title
            GroupID                                     = $groupId
            Url                                         = $spoSite.Url
            StorageLimit                                = (($spoSite.StorageQuota) / 1024)
            StorageUsed                                 = (($spoSite.StorageUsageCurrent) / 1024)
            Owner                                       = $spoSite.Owner
            SiteAdmins                                  = $spoSiteAdmins -join '|'
            SiteAdminsNumber                            = $spoSiteAdmins.count
            SiteAdminsMessage                           = "Please check 'My Site Secondary Admin' too https://<tenant>-admin.sharepoint.com/_layouts/15/Online/PersonalSites.aspx?PersonalSitesOverridden=1"
            SharingCapability                           = $spoSite.SharingCapability
            SharingAllowedDomain                        = $spoSite.SharingAllowedDomainList
            SiteDefinedSharingCapability                = $spoSite.SiteDefinedSharingCapability
            LockState                                   = $spoSite.LockState
            LocaleID                                    = $spoSite.LocaleID
            LocaleIDString                              = "$($lang.Name)|$($lang.DisplayName)"
            Timezone                                    = $regionalSettings.timeZone
            TimezoneString                              = Convert-SPOTimezoneToString $regionalSettings.timeZone
            HourFormat                                  = $regionalSettings.hourFormat
            SortOrder                                   = $regionalSettings.sortOrder
            Template                                    = $spoSite.Template
            ConditionalAccessPolicy                     = $spoSite.ConditionalAccessPolicy
            LastContentModifiedDate                     = $sposite.LastContentModifiedDate
            IsTeamsConnected                            = $sposite.IsTeamsConnected
            IsTeamsChannelConnected                     = $sposite.IsTeamsChannelConnected
            SensitivityLabel                            = $sposite.SensitivityLabel
            DefaultLinkPermission                       = $sposite.DefaultLinkPermission
            DefaultSharingLinkType                      = $sposite.DefaultSharingLinkType
            DefaultLinkToExistingAccess                 = $sposite.DefaultLinkToExistingAccess
            AnonymousLinkExpirationInDays               = $sposite.AnonymousLinkExpirationInDays
            OverrideTenantAnonymousLinkExpirationPolicy = $sposite.OverrideTenantAnonymousLinkExpirationPolicy
            ExternalUserExpirationInDays                = $sposite.ExternalUserExpirationInDays
            OverrideTenantExternalUserExpirationPolicy  = $sposite.OverrideTenantExternalUserExpirationPolicy
            IsHubSite                                   = $sposite.IsHubSite
            RoleFullControl                             = $roleFullControl
            RoleSiteOwner                               = $roleSiteOwner
        }
        
        # If Teams renamed, the DisplayName is not the same as the Title of the SPOsite
        if ($M365GroupsDetails) {
            $primarySMTPAddress = $hash[$spoSite.Url]
            $params.Add('PrimarySmtpAddress', $primarySMTPAddress)
            $params.Add('Type', $type)
            $params.Add('M365DisplayName', $team.DisplayName)
            $params.Add('M365WhenCreatedUTC', $hashWhenCreated[$spoSite.Url])
            $params.Add('TeamDescription', $team.Description)
            $params.Add('TeamVisibility', $visibility)
            $params.Add('TeamArchived', $archived)
            $params.Add('TeamChannelCount', $ChannelCount)
            $params.Add('TeamOwners', $owners)
            $params.Add('TeamOwnersCount', $ownersCount)
            $params.Add('TeamMembersCount', $membersCount)
            $params.Add('TeamGuestsCount', $guestsCount)
        }

        $object = New-Object -Type PSObject -Property $params

        $spoSitesInfos.Add($object)
    }

    return $spoSitesInfos
}