function Get-Microsoft365GroupsDetails {

	<#
Connect-ExchangeOnline	

Connect-MicrosoftTeams

Import-Module AzureADPreview
Connect-AzureAD

$domain = (Get-AzureADDomain | Where-Object {$_.IsInitial}).Name
$domain = $domain.replace('.onmicrosoft.com','')

Connect-SPOService https://$domain-admin.sharepoint.com

#>
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 

	[System.Collections.Generic.List[PSObject]]$data = @()
	

	Write-Host 'Get Azure AD Users' -ForegroundColor Cyan
	$AllAADUsers = Get-AzureADUser -All:$true -ErrorAction SilentlyContinue

	$allAADUsersHash = @{}

	$AllAADUsers | ForEach-Object { 
		$allAADUsersHash.Add($_.UserPrincipalName, $_.UserType)
	}

	<#$hashtable all users and guest
	$AllMemberUsers = @{}
	$AllAADUsers | Where-Object { $_.UserType -eq 'Member' -or $null -eq $_.UserType } | ForEach-Object { $AllMemberUsers.Add($_.UserPrincipalName, 'Member') }

	$AllGuestUsers = @{}
	$AllAADUsers | Where-Object { $_.UserType -eq 'Guest' } | ForEach-Object {
		if ($null -eq $_.mail) {
			$AllGuestUsers.Add($_.UserPrincipalName, 'Guest')
		}
		else {
			$AllGuestUsers.Add($_.mail, 'Guest') 
  }
	}
#>
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
	
	$defaultAADSettings = (Get-AzureADDirectorySetting | Where-Object { $_.displayname -eq 'Group.Unified' }).Values

	if (($defaultAADSettings | Where-Object { $_.Name -eq 'EnableGroupCreation' }) -eq $false) {
		$unifiedGroupCreationAllowed = 'false (from default settings)'
	}
	else {
		# true or empty means that all users can create unified groups (default configuration))
		$unifiedGroupCreationAllowed = 'true (from default settings)'
	}

	if (($defaultAADSettings | Where-Object { $_.Name -eq 'AllowGuestsToAccessGroups' }) -eq $false) {
		$AllowGuestsToAccessGroups = 'false (from default settings)'
	}
	else {
		$AllowGuestsToAccessGroups = 'true (from default settings)'
	}

	if (($defaultAADSettings | Where-Object { $_.Name -eq 'AllowGuestsToBeGroupOwner' }) -eq $false) {
		$AllowGuestsToBeGroupOwner = 'false (from default settings)'
	}
	else {
		$AllowGuestsToBeGroupOwner = 'true (from default settings)'
	}

	if (($defaultAADSettings | Where-Object { $_.Name -eq 'AllowToAddGuests' }) -eq $false) {
		$AllowToAddGuests = 'false (from default settings)'
	}
	else {
		$AllowToAddGuests = 'true (from default settings)'
	}

	$i = 0
	Write-Host 'Gather information about Teams/Microsoft 365 groups' -ForegroundColor Cyan
	foreach ($group in $groups) {
		$i++

		#[string]$channelsNames = [string]$teamOwnersEmails = [string]$uGroupMembersEmail = [string]$teamGuestsEmails = [string]$uGroupOwnersEmail = ''
		[System.Collections.Generic.List[PSObject]]$channelsNames = @()
		[System.Collections.Generic.List[PSObject]]$uGroupMembersEmail = @()
		[System.Collections.Generic.List[PSObject]]$uGroupOwnersEmail = @()	

		$teamEnabled = $false
		$team = $null
		$NumberofChats = $null
		$LastItemAddedtoTeams = $null

		Write-Host "Get details for $($group.Name) - $i of $($groups.count)" -ForegroundColor Cyan

		$uGroup = Get-UnifiedGroup -Identity $group.DistinguishedName
	
		$uGroupMembers = Get-UnifiedGroupLinks -Identity $uGroup.DistinguishedName -LinkType Members

		foreach ($uMember in $uGroupMembers) {
			if ($uMember.PrimarySmtpAddress) {
				$uMemberStr = $uMember.PrimarySmtpAddress
				
			}
			elseif ($uMember.DisplayName) {
				$uMemberStr = $uMember.DisplayName
			}
			else {
				$uMemberStr = $uMember.Name
			}

			$uGroupMembersEmail.Add($uMemberStr)
		}

		$uGroupOwners = Get-UnifiedGroupLinks -Identity $uGroup.DistinguishedName -LinkType Owners

		foreach ($uOwner in $uGroupOwners) {
			if ($uOwner.PrimarySmtpAddress) {
				$uOwnerStr = $uOwner.PrimarySmtpAddress
			}
			elseif ($uOwner.DisplayName) {
				$uOwnerStr = $uOwner.DisplayName
			}
			else {
				$uOwnerStr = $uOwner.Name
			}
	
			$uGroupOwnersEmail.Add($uOwnerStr)
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
				$channelsNames.Add($channel.DisplayName)
			}


			$teamsUsers = Get-TeamUser -GroupId $uGroup.ExternalDirectoryObjectId
			$teamsMember = $teamsUsers | Where-Object { $_.Role -eq 'member' }
			$teamsGuest = $teamsUsers | Where-Object { $_.Role -eq 'guest' }
			$teamsOwners = $teamsUsers | Where-Object { $_.Role -eq 'owner' }

			$teamAllowToAddGuests = $null
			$teamAllowAddGuestsToAccessGroups = $null
			$teamGuestSettings = $null

			$teamGuestSettings = Get-AzureADObjectSetting -TargetType groups -TargetObjectId $uGroup.ExternalDirectoryObjectId
		
			$team = Get-Team -GroupID $uGroup.ExternalDirectoryObjectId

			if ($null -ne $teamGuestSettings) {    
	
				# https://learn.microsoft.com/en-us/entra/identity/users/groups-settings-cmdlets#update-settings-for-a-specific-group
				$guestSettings = ((Get-AzureADObjectSetting -TargetType groups -TargetObjectId $uGroup.ExternalDirectoryObjectId).ToJson() | ConvertFrom-Json).Values

				foreach ($guestSetting in $guestSettings) {
				
					switch ($guestSetting.Name) {
						AllowToAddGuests {
							if ($null -eq $guestSettings.value) {
								$teamAllowToAddGuests = $AllowToAddGuests
							}
							elseif ($guestSettings.value -eq 'false') {
								$teamAllowToAddGuests = 'True'
							}
							else {
								$teamAllowToAddGuests = 'True'
							}

							break
						}
						AllowGuestsToAccessGroups {
							if ($null -eq $guestSettings.value) {
								$teamAllowAddGuestsToAccessGroups = $AllowGuestsToAccessGroups
							}
							elseif ($guestSettings.value -eq 'false') {
								$teamAllowAddGuestsToAccessGroups = 'False'
							}
							else {
								$teamAllowAddGuestsToAccessGroups = 'True'
							}

							break
						}
						AllowGuestsToBeGroupOwner {
							if ($null -eq $guestSettings.value) {
								$teamAllowGuestsToBeGroupOwner = $AllowGuestsToBeGroupOwner
							}
							elseif ($guestSettings.value -eq 'false') {
								$teamAllowGuestsToBeGroupOwner = 'False'
							}
							else {
								$teamAllowGuestsToBeGroupOwner = 'True'
							}

							break
						}
					}
				}
			}
			else {
				$teamAllowToAddGuests = $AllowToAddGuests
				$teamAllowAddGuestsToAccessGroups = $AllowGuestsToAccessGroups
				$teamAllowGuestsToBeGroupOwner = $AllowGuestsToBeGroupOwner
			}		
		}
		#Team name    TeamMail    Channels    MembersCount    OwnersCount    GuestsCount    Privacy
	
		$object = [PSCustomObject][ordered] @{
			GroupID                                             = $uGroup.ExternalDirectoryObjectId
			GroupTeamMainMail                                   = $uGroup.PrimarySmtpAddress
			GroupTeamAllMailAddresses                           = $uGroup.EmailAddresses -split ',' -join '|'
			GroupHiddenfromOutlook                              = $uGroup.HiddenFromExchangeClientsEnabled
			GroupAccessType                                     = $uGroup.AccessType
			GroupExternalMemberCount                            = $uGroup.GroupExternalMemberCount
			GroupName                                           = $uGroup.DisplayName
			GroupDescription                                    = $uGroup.Description
			GroupCreationUTCTime                                = $uGroup.WhenCreatedUTC
			SharePointSiteURL                                   = if ($uGroup.SharePointSiteUrl) { $uGroup.SharePointSiteUrl }else { '-' }
			SharePointDocumentsURL                              = if ($uGroup.SharePointDocumentsUrl) { $uGroup.SharePointDocumentsUrl }else { '-' }
			# SharePointSiteUrl can be empty (exemple of allcompany group)
			SharePointSiteSharingCapability                     = if ($uGroup.SharePointSiteUrl) { $hashSPOSites[$uGroup.SharePointSiteUrl] }else { '-' }
			TeamEnabled                                         = $teamEnabled
			TeamStandardChannelCount                            = ($channelsList | Where-Object { $_.MembershipType -eq 'Standard' } | Measure-Object).Count
			TeamPrivateChannelCount                             = ($channelsList | Where-Object { $_.MembershipType -eq 'Private' } | Measure-Object).Count
			TeamSharedChannelCount                              = ($channelsList | Where-Object { $_.MembershipType -eq 'Shared' } | Measure-Object).Count
			TeamChannelsNames                                   = $channelsNames -join '|'
			LastItemAddedtoTeams                                = $LastItemAddedtoTeams
			NumberofChats                                       = $NumberofChats
			uGroupMembersCount                                  = $uGroupMembersEmail.count
			uGroupMembersEmail                                  = $uGroupMembersEmail -join '|'
			TeamOwnersCount                                     = $teamsOwners.Count
			TeamOwnersEmails                                    = $teamsOwners.User -join '|'
			TeamMemberCount                                     = $teamsMember.Count
			TeamMemberEmails                                    = $teamsMember.User -join '|'
			TeamGuestCount                                      = $teamsGuest.Count
			TeamGuestEmails                                     = $teamsGuest.User -join '|'
			TeamAllUsersCount                                   = $teamsUsers.Count
			TeamAllUsersEmails                                  = $teamsUsers.User -join '|'
			TeamAllowToAddGuests                                = $teamAllowToAddGuests
			TeamAllowGuestsToBeGroupOwner                       = $teamAllowGuestsToBeGroupOwner
			TeamAllowGuestsToAccessGroups                       = $teamAllowAddGuestsToAccessGroups			
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
			UnifiedGroupWelcomeMessageEnabled                   = $uGroup.WelcomeMessageEnabled
		}
		
		$data.Add($object)
	}

	return $data
}