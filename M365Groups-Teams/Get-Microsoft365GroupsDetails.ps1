function Get-Microsoft365GroupsDetails {

	<#
Connect-ExchangeOnline	

Connect-MicrosoftTeams

Connect-AzureAD

$domain = (Get-AzureADDomain | Where-Object {$_.IsInitial}).Name
$domain = $domain.replace('.onmicrosoft.com','')

Connect-SPOService https://$domain-admin.sharepoint.com

#>
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 

	[System.Collections.Generic.List[PSObject]]$data = @()
	

	Write-Host 'Get Azure AD Users' -ForegroundColor Cyan
	$AllAADUsers = Get-AzureADUser -All:$true -ErrorAction SilentlyContinue

	#$hashtable all users and guest
	$AllMemberUsers = @{}
	$AllAADUsers | Where-Object { $_.UserType -eq 'Member' -or $null -eq $_.UserType } | ForEach-Object { $AllMemberUsers.Add($_.UserPrincipalName, 'Member') }

	$AllGuestUsers = @{}
	$AllAADUsers | Where-Object { $_.UserType -eq 'Guest' } | ForEach-Object { $AllGuestUsers.Add($_.mail, 'Guest') }

	Write-Host 'Get Microsoft 365 Groups' -ForegroundColor Cyan
	$groups = Get-Recipient -RecipientTypeDetails GroupMailbox -ResultSize Unlimited | Sort-Object DisplayName

	Write-Host 'Get Microsoft 365 Teams' -ForegroundColor Cyan
	$teams = Get-Team -NumberOfThreads 20
	
	$TeamsList = @{}
	$teams | ForEach-Object { $TeamsList.Add($_.GroupId, $_.DisplayName) }
	
	Write-Host 'Get SharePoint Sites' -ForegroundColor Cyan
	$allSPOSites = Get-SPOSite -Limit All | Select-Object Url, SharingCapability
	$hashSPOSites = @{}
	$allSPOSites | ForEach-Object {
		$hashSPOSites.Add($_.Url, $_.SharingCapability)
	}
	
	$i = 0
	Write-Host 'Gather information about Teams/Microsoft 365 groups' -ForegroundColor Cyan
	foreach ($group in $groups) {
		$i++

		[string]$channelsNames = [string]$teamOwnersEmails = [string]$uGroupMembersEmail = [string]$teamGuestsEmails = [string]$uGroupOwnersEmail = ''
		$teamEnabled = $false
		$team = $null
		Write-Host "Get details for $($group.Name) - $i of $($groups.count)" -ForegroundColor Cyan

		$uGroup = Get-UnifiedGroup -Identity $group.DistinguishedName
	
		$uGroupMembers = Get-UnifiedGroupLinks -Identity $uGroup.DistinguishedName -LinkType Members

		if ($uGroupMembers.PrimarySmtpAddress) {
			$uGroupMembers | ForEach-Object { $uGroupMembersEmail += $_ }
		}

		$uGroupOwners = Get-UnifiedGroupLinks -Identity $uGroup.DistinguishedName -LinkType Owners

		if ($uGroupOwners.PrimarySmtpAddress) {
			$uGroupOwners | ForEach-Object { $uGroupOwnersEmail += $uGroupOwnersEmail+'|'+$_ }
		}

		# If Team-Enabled, we can find the date of the last chat compliance record
		if ($TeamsList.ContainsKey($uGroup.ExternalDirectoryObjectId)) {
			$teamEnabled = $True
	
			$teamChatData = (Get-MailboxFolderStatistics -Identity $uGroup.PrimarySmtpAddress -IncludeOldestAndNewestItems -FolderScope ConversationHistory)
				
			if ($teamChatData.ItemsInFolder[1] -ne 0) {
				$LastItemAddedtoTeams = $teamChatData.NewestItemReceivedDate[1]
				$NumberofChats = $teamChatData.ItemsInFolder[1] 
				if ($teamChatData.NewestItemReceivedDate -le $WarningEmailDate) {
					Write-Host "Team-enabled group $($ugroup.DisplayName) has only $($teamChatData.ItemsInFolder[1]) compliance record(s)"
				}
			}
					
			$channelsList = Get-TeamChannel -GroupId $uGroup.ExternalDirectoryObjectId
			
			foreach ($channel in $channelsList) {
				$channelsNames += $channel.DisplayName
			}
	
			if ([array]$uGroupOwners = $uGroupMembers | Where-Object { $_.Role -eq 'owner' }) {
				$teamOwnersCount = $uGroupOwners.Count
				$uGroupOwners | ForEach-Object { $teamOwnersEmails += $_.User }

			}
			else {
				$teamOwnersCount = 0
				$teamOwnersEmails = ''
			}

			if ([array]$uGroupGuest = $uGroupMembers | Where-Object { $_.Role -eq 'guest' }) {
				$uGroupGuest | ForEach-Object { $teamGuestsEmails += $_.User }
			}

			$teamAllowToAddGuests = $teamAllowAddGuestsToAccessGroups = 'True'
			$teamGuestSettings = $null
			$teamGuestSettings = Get-AzureADObjectSetting -TargetType groups -TargetObjectId $uGroup.ExternalDirectoryObjectId
		
			$team = Get-Team -GroupID $uGroup.ExternalDirectoryObjectId

			if ($null -ne $teamGuestSettings) {    
	
				$guestSettings = ((Get-AzureADObjectSetting -TargetType groups -TargetObjectId $uGroup.ExternalDirectoryObjectId).ToJson() | ConvertFrom-Json).Values
				foreach ($guestSetting in $guestSettings) {
				
					switch ($guestSetting.Name) {
						AllowToAddGuests {
							if ($guestSettings.value -eq 'false') {
								$teamAllowToAddGuests = 'False'
							}
						}
						AllowGuestsToAccessGroups {
							if ($guestSettings.value -eq 'false') {
								$teamAllowAddGuestsToAccessGroups = 'False'
							}
						}
					}
				}
			}			
		}
		#Team name    TeamMail    Channels    MembersCount    OwnersCount    GuestsCount    Privacy
	
		$object = [pscustomobject][ordered] @{
			GroupID                                             = $uGroup.ExternalDirectoryObjectId
			GroupTeamMainMail                                   = $uGroup.PrimarySmtpAddress
			GroupTeamAllMailAddresses                           = $uGroup.EmailAddresses -split ',' -join '|'
			GroupHiddenfromOutlook                              = $uGroup.HiddenFromExchangeClientsEnabled
			GroupAccessType                                     = $uGroup.AccessType
			GroupExternalMemberCount                            = $uGroup.GroupExternalMemberCount
			TeamEnabled                                         = $teamEnabled
			GroupName                                           = $uGroup.DisplayName
			GroupDescription                                    = $uGroup.Description
			GroupCreationUTCTime                                = $uGroup.WhenCreatedUTC
			TeamMemberSettingsAllowCreateUpdateChannels         = $team.AllowCreateUpdateChannels
			TeamMemberSettingsAllowDeleteChannels               = $team.AllowDeleteChannels
			TeamMemberSettingsAllowAddRemoveApps                = $team.AllowAddRemoveApps
			TeamMemberSettingsAllowCreateUpdateRemoveTabs       = $team.AllowCreateUpdateRemoveTabs
			TeamMemberSettingsAllowCreateUpdateRemoveConnectors = $team.AllowCreateUpdateRemoveConnectors
			TeamMessagingSettingsAllowUserEditMessages          = $team.AllowUserEditMessages
			TeamMessagingSettingsAllowUserDeleteMessages        = $team.AllowUserDeleteMessages
			TeamMessagingSettingsAllowOwnerDeleteMessages       = $team.AllowOwnerDeleteMessages
			TeamMessagingSettingsAllowTeamMentions              = $team.AllowTeamMentions
			TeamMessagingSettingsAllowChannelMentions           = $team.AllowChannelMentions
			TeamGuestSettingsAllowCreateUpdateChannels          = $team.AllowCreateUpdateChannels
			TeamGuestSettingsAllowDeleteChannels                = $team.AllowDeleteChannels
			TeamFunSettingsAllowGiphy                           = $team.AllowGiphy
			TeamFunSettingsGiphyContentRating                   = $team.GiphyContentRating
			TeamFunSettingsAllowStickersAndMemes                = $team.AllowStickersAndMemes
			TeamFunSettingsAllowCustomMemes                     = $team.AllowCustomMemes
			TeamChannelsCount                                   = $channelsList.Count
			TeamChannelsNames                                   = $channelsNames -join '|'
			TeamOwnersCount                                     = $teamOwnersEmails.count
			TeamOwnersEmails                                    = $teamOwnersEmails -join '|'
			uGroupMembersCount                                  = $uGroupMembersEmail.count
			uGroupMembersEmail                                  = $uGroupMembersEmail -join '|'
			TeamGuestsCount                                     = $teamGuestsEmails.count
			TeamGuestsEmails                                    = $teamGuestsEmails -join '|'
			TeamGuestsAllowedToBeAdded                          = $teamAllowToAddGuests
			TeamGuestsToAccessGroups                            = $teamAllowAddGuestsToAccessGroups 
			TeamSharePointSiteURL                               = if ($uGroup.SharePointSiteUrl) { $uGroup.SharePointSiteUrl }else { 'UNKOWN' }
			TeamSharePointDocumentsURL                          = $uGroup.SharePointDocumentsUrl
			# SharePointSiteUrl can be empty (exemple of allcompany group)
			SharePointSiteSharingCapability                     = if ($uGroup.SharePointSiteUrl) { $hashSPOSites[$uGroup.SharePointSiteUrl] }else { 'UNKOWN' }
			UnifiedGroupWelcomeMessageEnabled                   = $uGroup.WelcomeMessageEnabled
		}
		
		$data.Add($object)
	}

	return $data
}