# Priority 1: forwardingAddress
# Priority 2: forwardingSMTPAddress
# Priority 3: inbox rule

# Autoforward works if forwardingAddress because it's an internal object
# TODO:
# Add forwardWorks for inbox rules
# Add forwardWorks if RemoteDomain enable

function Get-MailboxForwarding {

	[CmdletBinding()] 
	param ( 
		[Parameter(Mandatory = $false)] 
		[ValidateNotNullOrEmpty()] 
		[string[]]$Mailboxes,
		[Parameter(Mandatory = $false)] 
		[switch]$ForwardingAndForwardingSMTPOnly,
		[Parameter(Mandatory = $false)] 
		[switch]$InboxRulesOnly,
		[Parameter(Mandatory = $false)] 
		[switch]$ExportResults,
		[Parameter(Mandatory = $false)] 
		[switch]$ExchangeOnPremise
	)

	function Translate-Recipient {
		Param (
			[Parameter(Mandatory = $true)]
			[string]$Recipient
		)
					
		# "name" [EX:/o=ExchangeLabs/ou=Exchange Administrative Group (FYDIBOHF23SPDLT)/cn=Recipients/cn=xxxx] if recipient is an object in the organization (mailbox, mail contact, etc.)
		# "name" [SMTP: is not in the same organization

		if ($Recipient -like '*`[SMTP:*@*') {
			# need to escape the [
			$recipientConverted = ($Recipient -split 'SMTP:')[1].TrimEnd(']')
		}
		# we use the LegacyExchangeDN after the EX: to get the recipient domain
		elseif ($Recipient -like '*`[EX:*') {
			# remove the last character (])
			$temp = ($Recipient -split 'EX:')[1].TrimEnd(']')
			$recipientConverted = $hashRecipients[$temp]
		}
		else {
			$recipientConverted = 'unknown format'
		}

		return $recipientConverted
	}

	[System.Collections.Generic.List[PSObject]]$mailboxesList = @()
	[System.Collections.Generic.List[PSObject]]$forwardList = @()
	# inboxForwardList is use to contains the mailbox with inbox rules with forward. We need to use it as temporary storage to check if the mailbox has already a forward set by forwardingAddress or forwardingSMTPAddress
	[System.Collections.Generic.List[PSObject]]$inboxForwardList = @()

	Write-Host -ForegroundColor cyan 'Get Accepted Domain in Exchange Online to identify internal/external forward'
	$internalDomains = (Get-AcceptedDomain).DomainName
	
	$remoteDomains = Get-RemoteDomain

	foreach ($remoteDomain in $remoteDomains) {
		Write-Host "Remote Domain '$remotedomain' AutoForwardEnabled: $($remoteDomain.AutoForwardEnabled)" -ForegroundColor Cyan
	}

	if (-not $ExchangeOnPremise) {
		$outboundSpamPolicies = Get-HostedOutboundSpamFilterPolicy

		foreach ($outboundSpamPolicy in $outboundSpamPolicies) {
		
			$state = (Get-HostedOutboundSpamFilterRule | Where-Object { $_.HostedOutboundSpamFilterPolicy -eq $outboundSpamPolicy.Name }).State

			if ($state -eq 'Enabled') {
				$prefix = ''
				$color = 'Cyan'
			}
			else {
				$prefix = '[NOT ENABLED] '
				$color = 'Gray'
			}

			Write-Host "$prefix`OutboundSpamPolicy '$($outboundSpamPolicy.Name)' - AutoForwardingMode: $($outboundSpamPolicy.AutoForwardingMode)" -ForegroundColor $color
		
			$autoForwardMode = $outboundSpamPolicy.AutoForwardingMode
		
			if ($autoForwardMode -eq 'Automatic' -and $state -eq 'Enabled') {
				Write-Host "Careful, the value 'Automatic is now the same as AutoForwardEnable=Off, means autoForward is disabled even if the Remote domain(s) are configured with AutoForwardEnable = `$true
		Sources:
		https://office365itpros.com/2020/11/12/microsoft-clamps-down-mail-forwarding-exchange-online/
		http://blog.icewolf.ch/archive/2020/10/06/how-to-control-the-many-ways-of-email-forwarding-in.aspx
		https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/external-email-forwarding?view=o365-worldwide
		https://techcommunity.microsoft.com/t5/exchange-team-blog/all-you-need-to-know-about-automatic-email-forwarding-in/ba-p/2074888
	
		RoadMap ID: MC221113" -ForeGround Yellow
			}
		}
	}

	$hashRecipients = @{}
	
	Write-Host -ForegroundColor Cyan 'Get all Exchange recipients'
	
	# Get all recipients, needed for forwardingAddress
	if (-not $ExchangeOnPremise) {
		$recipients = Get-EXORecipient -ResultSize Unlimited
	}
	else {
		$recipients = Get-Recipient -ResultSize Unlimited
	}

	$recipients | ForEach-Object {
		$hashRecipients.Add($_.Name, $_.PrimarySmtpAddress)
	}

	$properties = @('Identity', 'Name', 'DistinguishedName', 'PrimarySmtpAddress', 'ForwardingAddress', 'ForwardingSmtpAddress', 'DeliverToMailboxAndForward', 'LegacyExchangeDN', 'UserPrincipalName', 'DisplayName')


	# Get-LegacyExchangeDN, needed for inbox rules. We can also use name or ID but legacyExchangeDN is more reliable
	# Get-EXORecipient does not contain LegacyExchangeDN property so we need to get it from Get-EXOMailbox / Get-DistributionGroup and Get-UnifiedGroup
	if (-not $ExchangeOnPremise) {

		# Get-EOMailbox doesn't contain all the properties we need by default, so we need to specify them
		Get-EXOMailbox -ResultSize Unlimited -Properties $properties | Select-Object $properties | ForEach-Object {
			$mailboxesList.Add($_)
			$hashRecipients.Add($_.LegacyExchangeDN, $_.PrimarySmtpAddress)
		}

		Get-DistributionGroup -ResultSize Unlimited | ForEach-Object {
			$hashRecipients.Add($_.LegacyExchangeDN, $_.PrimarySmtpAddress)
		}

		Get-UnifiedGroup -ResultSize Unlimited | ForEach-Object {
			$hashRecipients.Add($_.LegacyExchangeDN, $_.PrimarySmtpAddress)
		}
	}
	else {
		<#
		Get-Mailbox -ResultSize Unlimited | ForEach-Object {
			$hashRecipients.Add($_.LegacyExchangeDN, $_.PrimarySmtpAddress)
		}
		#>

		Get-Mailbox -ResultSize Unlimited | Select-Object $properties | ForEach-Object {
			$mailboxesList.Add($_)
			$hashRecipients.Add($_.LegacyExchangeDN, $_.PrimarySmtpAddress)
		}
		
		Get-DistributionGroup -ResultSize Unlimited | ForEach-Object {
			$hashRecipients.Add($_.LegacyExchangeDN, $_.PrimarySmtpAddress)
		}
	}

	# if mailboxes is specified, get only these mailboxes
	if ($null -ne $Mailboxes -and $Mailboxes.Count -gt 0) {
		[System.Collections.Generic.List[Object]]$tempMailboxesList = @()
		foreach ($mbx in $Mailboxes) {
			try {
				$mailbox = $mailboxesList | Where-Object { $_.PrimarySMTPAddress -eq $mbx }
				$tempMailboxesList.Add($mailbox)
			}
			catch {
				Write-Warning "$mbx mailbox not found. $($_.Exception.Message)"
			}
		}

		$mailboxesList = $tempMailboxesList
	}
	# else get all mailboxes
	else {
		# all mailboxes are in $mailboxesList
		# nothing to do here
	}
	
	# To prevent, block via rule and via OWA policy

	# If user set forwardingSMTPaddress+deliverToMailboxAndForward is set AND forwardingAddress is also set. The Exchange Online CMDLet will tell us the deliverToMailboxAndForward is set... but no !
	# Many ways to block automatic email forwarding in Exchange Online : https://techcommunity.microsoft.com/t5/exchange-team-blog/the-many-ways-to-block-automatic-email-forwarding-in-exchange/ba-p/607579
	# https://nedimmehic.org/2019/08/08/disable-forwarding-in-owa-with-powershell/

	# Identify mailbox with DistinguishedName to prevent issue in case of alias/name duplicate
	<#
	$mbxWithForward = $mailboxesList | Where-Object { ($null -ne $_.ForwardingSMTPAddress) -or ($null -ne $_.ForwardingAddress) } | Select-Object Name, PrimarySmtpAddress, ForwardingSMTPAddress, ForwardingAddress, @{Name = 'ForwardingAddressConvertSMTP'; Expression = { if ($null -ne $_.ForwardingAddress) { (Get-Recipient -Identity "$($_.ForwardingAddress)").PrimarySmtpAddress } } }, DeliverToMailboxAndForward
	
	if ($null -ne $mbxWithForward) {
		Write-Host -ForegroundColor Yellow "ForwardingAddress and ForwardingSMTP Address found"
		$mbxWithForward
	}
	else {
		Write-Host -ForegroundColor Green "SERVER SIDE (forwardingAddress and ForwardingSMTP Address) : No forward on server side"
	}
	#>

	if (-not($InboxRulesOnly)) {
		foreach ($mailbox in $mailboxesList) {
			Write-Host -ForegroundColor cyan "Processing ForwardingAddress|ForwardingSMTPAddress - $($mailbox.Name) - $($mailbox.PrimarySMTPAddress)"
			#$forward = $mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress) -or ($null -ne $_.ForwardingAddress) } | Select-Object Name, PrimarySmtpAddress, ForwardingSMTPAddress, ForwardingAddress, @{Name = 'ForwardingAddressConvertSMTP'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress] } } }, DeliverToMailboxAndForward

			<# --- Forwarding Address part ---
			ForwardingAddress is a RecipientIdParameter and used when you want to forward emails to a mail-enabled object. 
			The target object should exists in your ActiveDirectory | Exchange Online as a mail-enabled object like MailUser, Contact or RemoteMailUser.
			If you do not have a mail-enabled object for your forwarding address then this will not work.  
			ForwardingAddress can be set by using the -ForwardingAddress parameter in the command set-mailbox.
			#>

			if ($ExchangeOnPremise) {
				$forwardingAddress = $mailbox | Where-Object { ($null -ne $_.ForwardingAddress) } | Select-Object Name, PrimarySmtpAddress, ForwardingAddress, @{Name = 'ForwardingAddressConverted'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress.Name].Address } } }, DeliverToMailboxAndForward
			}
			else {
				$forwardingAddress = $mailbox | Where-Object { ($null -ne $_.ForwardingAddress) } | Select-Object Name, PrimarySmtpAddress, ForwardingAddress, @{Name = 'ForwardingAddressConverted'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress] } } }, DeliverToMailboxAndForward
			}
			
			#$forward = $mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress -and -not($internalDomains -contains $_.ForwardingSMTPAddress.split('@')[1])) -or ($null -ne $_.ForwardingAddress -and -not($internalDomains -contains $hashRecipients[$_.ForwardingSMTPAddress].split('@')[1]) ) } | Select-Object Name, PrimarySmtpAddress, ForwardingSMTPAddress, ForwardingAddress, @{Name = 'ForwardingAddressConvertSMTP'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress] } } }, DeliverToMailboxAndForward	
			
			if ($null -ne $forwardingAddress) {  
				Write-Host -ForegroundColor yellow "$($mailbox.Name) - $($mailbox.PrimarySMTPAddress) - 1 forwardingAddress parameter found"

				$recipientDomain = $forwardingAddress.ForwardingAddressConverted.Split('@')[1]
				
				if ($internalDomains -contains $recipientDomain) {
					$forwardingWorks = "True ($recipientDomain = internalDomain)"
				}
				elseif ($autoForwardMode -eq 'Automatic' -or $autoForwardMode -eq 'Off') {
					$forwardingWorks = "False (Autoforward mode = $autoForwardMode)" 
				}
				else {
					$forwardingWorks = "Yes (Autoforward mode = $autoForwardMode) and address used is an internal object (contact or mailbox)"
				}

				$object = [PSCustomObject][ordered]@{
					Identity                               = $mailbox.Identity
					Name                                   = $mailbox.Name
					DisplayName                            = $mailbox.DisplayName	
					PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
					UserPrincipalName                      = $mailbox.UserPrincipalName
					ForwardingAddressConverted             = $forwardingAddress.ForwardingAddressConverted
					ForwardType                            = 'ForwardingAddress'
					ForwardScope                           = ''
					Precedence                             = '-'
					ForwardingAddress                      = $forwardingAddress.ForwardingAddress
					ForwardingSMTPAddress                  = '-'
					ForwardingWorks                        = $forwardingWorks
					DeliverToMailboxAndForward             = '-'
					InboxRulePriority                      = '-'
					InboxRuleEnabled                       = '-'
					InboxRuleForwardAddressConverted       = '-'
					InboxRuleRedirectTo                    = '-'
					InboxRuleForwardTo                     = '-'
					InboxRuleForwardAsAttachmentTo         = '-'
					InboxRuleSendTextMessageNotificationTo = '-'
					InboxRuleDescription                   = '-'
				}

				#Add object to an array
				$forwardList.Add($object)
			}
			
			<# --- Forwarding SMTP Address part ---
			On the other hand, ForwardingSMTPAddress, it is a ProxyAddresses Value and has lower priority than ForwardingAddress.
			You can set this attribute with a remote SMTP address even if there is no mail-enabled Object exists in your ActiveDirectory | Exchange Online
			User can set ForwardingSMTPAddress in OWA.
			The ForwardingSMTPAddress has a higher priority than InboxRule :
			'This is expected behavior. Forwarding on a mailbox overrides an inbox redirection rule. To enable the redirection rule, remove forwarding on the mailbox.'
			(https://support.microsoft.com/en-us/help/3069075/inbox-rule-to-redirect-messages-doesn-t-work-if-forwarding-is-set-up-o
			)

			#>
			$forwardingSMTPAddress = $mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress) }
			#$forward = $mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress -and -not($internalDomains -contains $_.ForwardingSMTPAddress.split('@')[1])) -or ($null -ne $_.ForwardingAddress -and -not($internalDomains -contains $hashRecipients[$_.ForwardingSMTPAddress].split('@')[1]) ) } | Select-Object Name, PrimarySmtpAddress, ForwardingSMTPAddress, ForwardingAddress, @{Name = 'ForwardingAddressConvertSMTP'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress] } } }, DeliverToMailboxAndForward	
			
			if ($null -ne $forwardingSMTPAddress) {
				Write-Host -ForegroundColor yellow "$($mailbox.Name) - $($mailbox.PrimarySMTPAddress) - 1 forwardingSMTPAddress parameter found"
 
				# we need to check if the forwardList.PrimarySMTPAddress already contains 
				#if ($forwardList.PrimarySMTPAddress -contains $mailbox.PrimarySmtpAddress) {
				if ($forwardList.PrimarySMTPAddress -contains $mailbox.PrimarySmtpAddress) {
					$precedence = 'ForwardingAddress is already set for this mailbox. ForwardingAddress has a higher priority than the ForwardingSMTPAddress. This ForwardingSMTPAddress is ignored'
				}
				else {
					$precedence = '-'
				}

				if ($ExchangeOnPremise) {
					# in exchange on premise, the ForwardingSMTPAddress is a ProxyAddress and is stored in the ProxyAddressesString attribute (the value is smtp:xxx)
					$recipientDomain = $forwardingSMTPAddress.ForwardingSmtpAddress.ProxyAddressString.Split('@')[1]
					$forwardingAddressConverted = $forwardingSMTPAddress.ForwardingSmtpAddress.ProxyAddressString.replace('smtp:', '')
				}
				else {
					$recipientDomain = $forwardingSMTPAddress.forwardingSMTPAddress.Split('@')[1]
					$forwardingAddressConverted = $forwardingSMTPAddress.forwardingSMTPAddress.replace('smtp:', '')
				}
				

				if ($internalDomains -contains $recipientDomain) {
					$forwardingWorks = "True ($recipientDomain = internalDomain)"
				}
				elseif ($autoForwardMode -eq 'Automatic' -or $autoForwardMode -eq 'Off') {
					$forwardingWorks = "False (Autoforward mode = $autoForwardMode)" 
				}
				else {
					$forwardingWorks = "Maybe (Autoforward mode = $autoForwardMode), check if RemoteDomain(s) allows external forwarding and check if TransportRule(s) exist to prevent external forwarding"
				}

				$object = [PSCustomObject][ordered]@{
					Identity                               = $mailbox.Identity
					Name                                   = $mailbox.Name
					DisplayName                            = $mailbox.DisplayName	
					PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
					UserPrincipalName                      = $mailbox.UserPrincipalName
					ForwardingAddressConverted             = $forwardingAddressConverted
					ForwardType                            = 'ForwardingSMTPAddress'
					ForwardScope                           = ''
					Precedence                             = $precedence
					ForwardingAddress                      = '-'
					ForwardingSMTPAddress                  = $forwardingSMTPAddress.ForwardingSMTPAddress
					ForwardingWorks                        = $forwardingWorks
					DeliverToMailboxAndForward             = $forwardingSMTPAddress.DeliverToMailboxAndForward
					InboxRulePriority                      = '-'
					InboxRuleEnabled                       = '-'
					InboxRuleForwardAddressConverted       = '-'
					InboxRuleRedirectTo                    = '-'
					InboxRuleForwardTo                     = '-'
					InboxRuleForwardAsAttachmentTo         = '-'
					InboxRuleSendTextMessageNotificationTo = '-'
					InboxRuleDescription                   = '-'
				}

				#Add object to an array
				$forwardList.Add($object)
			}
		}
	}
	#$mailboxesWithInboxForward = New-Object 'System.Collections.Generic.List[System.Object]'
	$i = 0
	if (-not($ForwardingAndForwardingSMTPOnly)) {
		foreach ($mailbox in $mailboxesList) {
			$i++
			Write-Host -ForegroundColor cyan "Processing Inbox rules - $($mailbox.Name) - $($mailbox.PrimarySMTPAddress) [$i/$($mailboxesList.count)]"

			$inboxForwardRules = @(Get-InboxRule -Mailbox "$($mailbox.DistinguishedName)" | Where-Object { ($null -ne $_.ForwardTo) -or ($null -ne $_.ForwardAsAttachmentTo) -or ($null -ne $_.RedirectTo) -or ($_.SendTextMessageNotificationTo.count -gt 0) }) | Select-Object Identity, Enabled, ForwardTo, ForwardAsAttachmentTo, RedirectTo, SendTextMessageNotificationTo, Description, Priority
			
			if ($inboxForwardRules.count -gt 0) {
				Write-Host -ForegroundColor yellow "$($mailbox.Name) - $($mailbox.PrimarySMTPAddress) - $(($inboxForwardRules ).count) forward rule(s) found"
			}

			foreach ($inboxForwardRule in $inboxForwardRules) {
				if ($forwardList.PrimarySMTPAddress -contains $mailbox.PrimarySmtpAddress -and ($forwardList.ForwardingAddress -ne '-' -or $forwardList.ForwardingSMTPAddress -ne '-')) {
					$precedence = 'ForwardingAddress | ForwardingSMTPAddress is already set for this mailbox. They have a higher priority than inbox rules. This inbox rule will be ignored unless DeliverToMailboxAndForward is set to $true'
				}
				else {
					$precedence = '-'
				}

				# ForwardTo, ForwardAsAttachmentTo, RedirectTo are in the following format:
				# "name" [EX:/o=ExchangeLabs/ou=Exchange Administrative Group (FYDIBOHF23SPDLT)/cn=Recipients/cn=xxxx] if recipient is an object in the organization (mailbox, mail contact, etc.)
				# "name" [SMTP: is not in the same organization
				# ForwardTo, ForwardAsAttachmentTo, RedirectTo can be a list of recipients
				# SendTextMessageNotificationTo is a list of phone numbers
			
				foreach ($forwardTo in $inboxForwardRule.ForwardTo) {
					
					if ($ExchangeOnPremise) {
						$inboxForwardRuleDescription = $inboxForwardRule.description.ToString().replace("`t", "") # delete line breaks and tabs
					}
					else {
						$inboxForwardRuleDescription = $inboxForwardRule.description.replace("`r`n", " ").replace("`t", "") # delete line breaks and tabs
					}

					$recipientConverted = Translate-Recipient -Recipient $forwardTo

					$object = [PSCustomObject][ordered]@{
						Identity                               = $mailbox.Identity
						Name                                   = $mailbox.Name
						DisplayName                            = $mailbox.DisplayName	
						PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
						UserPrincipalName                      = $mailbox.UserPrincipalName
						ForwardingAddressConverted             = $recipientConverted
						ForwardType                            = 'InboxRule'
						ForwardScope                           = $forwardingScope
						Precedence                             = $precedence
						ForwardingAddress                      = '-'
						ForwardingSMTPAddress                  = '-'
						ForwardingWorks                        = 'Not evaluated yet (check precedence and InboxRuleEnabled and forward address)'
						DeliverToMailboxAndForward             = '-'
						InboxRulePriority                      = $inboxForwardRule.Priority
						InboxRuleEnabled                       = $inboxForwardRule.Enabled
						InboxRuleForwardAddressConverted       = $recipientConverted
						InboxRuleRedirectTo                    = '-'
						InboxRuleForwardTo                     = $forwardTo
						InboxRuleForwardAsAttachmentTo         = '-'
						InboxRuleSendTextMessageNotificationTo = '-'
						InboxRuleDescription                   = $inboxForwardRuleDescription
					}
			
					#Add object to an array
					# $forwardList.Add($object)
					$inboxForwardList.Add($object)
				}
			
				foreach ($forwardAsAttachmentTo in $inboxForwardRule.ForwardAsAttachmentTo) {
					if ($ExchangeOnPremise) {
						$inboxForwardRuleDescription = $inboxForwardRule.description.ToString().("`r`n", " ").replace("`t", "") # delete line breaks and tabs
					}
					else {
						$inboxForwardRuleDescription = $inboxForwardRule.description.replace("`r`n", " ").replace("`t", "") # delete line breaks and tabs
					}
					
					$recipientConverted = Translate-Recipient -Recipient $forwardAsAttachmentTo
						
					$object = [PSCustomObject][ordered]@{
						Identity                               = $mailbox.Identity
						Name                                   = $mailbox.Name
						DisplayName                            = $mailbox.DisplayName	
						PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
						UserPrincipalName                      = $mailbox.UserPrincipalName
						ForwardingAddressConverted             = $recipientConverted
						ForwardType                            = 'InboxRule'
						ForwardScope                           = $forwardingScope
						Precedence                             = $precedence
						ForwardingAddress                      = '-'
						ForwardingSMTPAddress                  = '-'
						ForwardingWorks                        = 'Not evaluated yet (check precedence and InboxRuleEnabled and forward address)'
						DeliverToMailboxAndForward             = '-'
						InboxRulePriority                      = $inboxForwardRule.Priority
						InboxRuleEnabled                       = $inboxForwardRule.Enabled
						InboxRuleForwardAddressConverted       = $recipientConverted
						InboxRuleRedirectTo                    = '-'
						InboxRuleForwardTo                     = '-'
						InboxRuleForwardAsAttachmentTo         = $forwardAsAttachmentTo
						InboxRuleSendTextMessageNotificationTo = '-'
						InboxRuleDescription                   = $inboxForwardRuleDescription
					}
			
					#Add object to an array
					#$forwardList.Add($object)
					$inboxForwardList.Add($object)
				}
			
				foreach ($redirectTo in $inboxForwardRule.RedirectTo) {
					
					if ($ExchangeOnPremise) {
						$inboxForwardRuleDescription = $inboxForwardRule.description.ToString().replace("`r`n", " ").replace("`t", "") # delete line breaks and tabs
					}
					else {
						$inboxForwardRuleDescription = $inboxForwardRule.description.replace("`r`n", " ").replace("`t", "") # delete line breaks and tabs
					}
					
					$recipientConverted = Translate-Recipient -Recipient $redirectTo
			
					$object = [PSCustomObject][ordered]@{
						Identity                               = $mailbox.Identity
						Name                                   = $mailbox.Name
						DisplayName                            = $mailbox.DisplayName	
						PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
						UserPrincipalName                      = $mailbox.UserPrincipalName
						ForwardingAddressConverted             = $recipientConverted
						ForwardType                            = 'InboxRule'
						ForwardScope                           = $forwardingScope
						Precedence                             = $precedence
						ForwardingAddress                      = '-'
						ForwardingSMTPAddress                  = '-'
						ForwardingWorks                        = 'Not evaluated yet (check precedence and InboxRuleEnabled and forward address)'
						DeliverToMailboxAndForward             = '-'
						InboxRulePriority                      = $inboxForwardRule.Priority
						InboxRuleEnabled                       = $inboxForwardRule.Enabled
						InboxRuleForwardAddressConverted       = $recipientConverted
						InboxRuleRedirectTo                    = $redirectTo
						InboxRuleForwardTo                     = '-'
						InboxRuleForwardAsAttachmentTo         = '-'
						InboxRuleSendTextMessageNotificationTo = '-'
						InboxRuleDescription                   = $inboxForwardRuleDescription
					}
						
					#Add object to an array
					#$forwardList.Add($object)
					$inboxForwardList.Add($object)
				}

				foreach ($sendTextMessageNotificationTo in $inboxForwardRule.SendTextMessageNotificationTo) {

					if ($ExchangeOnPremise) {
						$sendTextMessageNotificationToDescription = $sendTextMessageNotificationTo.Description.ToString().("`r`n", " ").replace("`t", "") # delete line breaks and tabs
					}
					else {
						$sendTextMessageNotificationToDescription = $sendTextMessageNotificationTo.Description.replace("`r`n", " ").replace("`t", "") # delete line breaks and tabs
					}

					$forwardingScope = 'External'
			
					$object = [PSCustomObject][ordered]@{
						Identity                               = $mailbox.Identity
						Name                                   = $mailbox.Name
						DisplayName                            = $mailbox.DisplayName	
						PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
						UserPrincipalName                      = $mailbox.UserPrincipalName
						ForwardingAddressConverted             = $sendTextMessageNotificationTo
						ForwardType                            = 'InboxRule'
						ForwardScope                           = $forwardingScope
						InboxRulePriority                      = $inboxForwardRule.Priority
						InboxRuleEnabled                       = $inboxForwardRule.Enabled
						InboxRuleForwardAddressConverted       = $temp
						InboxRuleRedirectTo                    = '-'
						InboxRuleForwardTo                     = '-'
						InboxRuleForwardAsAttachmentTo         = '-'
						InboxRuleSendTextMessageNotificationTo = $sendTextMessageNotificationTo
						InboxRuleDescription                   = $sendTextMessageNotificationToDescription
					}
									
					#Add object to an array
					#$forwardList.Add($object)
					$inboxForwardList.Add($object)
				}						
			}
		}
	}

	$inboxForwardList | ForEach-Object {
		$forwardList.Add($_)
	}

	Write-Host -ForegroundColor cyan "$($forwardList.count) forward(s) found"

	$forwardList | ForEach-Object {
		if ((($_.ForwardingAddressConverted -like '*@*') -and -not($internalDomains -contains $_.ForwardingAddressConverted.split('@')[1])) -or (($_.ForwardingSMTPAddress -like '*@*') -and -not($internalDomains -contains $_.ForwardingSMTPAddress.split('@')[1])) -or (($_.InboxRuleForwardAddressConverted -like '*@*') -and -not($internalDomains -contains $_.InboxRuleForwardAddressConverted.split('@')[1]))) {
			$_.ForwardScope = 'External'
		}
		else {
			$_.ForwardScope = 'Internal'
		}
	}

	if ($ExportResults) {
		$filepath = "$($env:temp)\$(Get-Date -format yyyyMMdd_hhmm)_forward.csv"
		Write-Host -ForegroundColor green "Export results to $filepath"
				
		$forwardList | Export-CSV -NoTypeInformation -Encoding UTF8 $filepath

		Invoke-Item $filepath
	}
	else {
		return $forwardList
	}
}