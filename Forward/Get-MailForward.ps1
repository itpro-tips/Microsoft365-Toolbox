# Priority 1: forwardingAddress
# Priority 2: forwardingSMTPAddress
# Priority 3: inbox rule

Function Get-MailForward {

	[CmdletBinding()] 
	Param 
	( 
		[Parameter(Mandatory = $false)] 
		[ValidateNotNullOrEmpty()] 
		[string[]]$Mailboxes,
		[Parameter(Mandatory = $false)] 
		[boolean]$ForwardingAndForwardingSMTPOnly,
		[Parameter(Mandatory = $false)] 
		[boolean]$InboxRulesOnly,
		[Parameter(Mandatory = $false)] 
		[boolean]$ExportResults
	)

	$internalDomains = (Get-AcceptedDomain).domainName

	$remoteDomains = Get-RemoteDomain

	foreach ($remoteDomain in $remoteDomains) {
		Write-Host "Remote Domain '$remotedomain' AutoForwardEnabled: $($remoteDomain.AutoForwardEnabled)"  -ForegroundColor Cyan
	}

	$outboundSpamPolicies = Get-HostedOutboundSpamFilterPolicy

	foreach ($outboundSpamPolicy in $outboundSpamPolicies) {
		
		Write-Host "OutboundSpamPolicy '$($outboundSpamPolicy.Name)' AutoForwardingMode: $($outboundSpamPolicy.AutoForwardingMode)" -ForegroundColor Cyan
		
		$autoForwardMode = $outboundSpamPolicy.AutoForwardingMode
		
		Write-Host "Careful if value is 'Automatic'. It means the autoForward will be block even if the Remote domain(s) are configured with AutoForwardEnable = `$true
		Sources:
		https://office365itpros.com/2020/11/12/microsoft-clamps-down-mail-forwarding-exchange-online/
		http://blog.icewolf.ch/archive/2020/10/06/how-to-control-the-many-ways-of-email-forwarding-in.aspx
		RoadMap ID: MC221113" -ForeGround Yellow
	}

	$hashRecipients = @{ }
	
	Write-Host -ForegroundColor green 'Gathering Exchange recipients'
	#recipients = Get-Recipient -ResultSize Unlimited 
	$recipients = Get-EXORecipient -ResultSize Unlimited

	$recipients | ForEach-Object {
		$hashRecipients.Add($_.Name, $_.PrimarySmtpAddress)
	}

	$mailboxeslist = New-Object 'System.Collections.Generic.List[System.Object]'

	Write-Host -ForegroundColor green 'Gathering mailboxes'
	if ($null -ne $Mailboxes -and $Mailboxes.Count -gt 0) {
		foreach ($mbx in $Mailboxes) {
			try {
				$mailbox = Get-EXOMailbox -Identity $mbx -ErrorAction Stop
				$null = $mailboxeslist.Add($mailbox)
			}
			catch {
				Write-Warning "$user mailbox not found. $($_.Exception.Message)"
			}
		}
	}
	else {
		try {
			$mailboxeslist = Get-Mailbox * -ResultSize Unlimited -ErrorAction Stop | Sort-Object Name
		}
		catch {
			Write-Warning "Mailbox not found. $($_.Exception.Message)"
		}
	}
	
	Write-Host -ForegroundColor green 'Get Accepted Domain in Exchange Online to identify internal/external forward'
	$domains = (Get-AcceptedDomain).Name

	# To prevent, block via rule and via OWA policy

	# If user set forwardingSMTPaddress+deliverToMailboxAndForward is set AND forwardingAddress is also set. The Exchange Online CMDLet will tell us the deliverToMailboxAndForward is set... but no !
	# Many ways to block automatic email forwarding in Exchange Online : https://techcommunity.microsoft.com/t5/exchange-team-blog/the-many-ways-to-block-automatic-email-forwarding-in-exchange/ba-p/607579
	# https://nedimmehic.org/2019/08/08/disable-forwarding-in-owa-with-powershell/

	# Identify mailbox with DistinguishedName to prevent issue in case of alias/name duplicate
	<#
	$mbxWithForward = $mailboxeslist | Where-Object { ($null -ne $_.ForwardingSMTPAddress) -or ($null -ne $_.ForwardingAddress) } | Select-Object Name, PrimarySmtpAddress, ForwardingSMTPAddress, ForwardingAddress, @{Name = 'ForwardingAddressConvertSMTP'; Expression = { if ($null -ne $_.ForwardingAddress) { (Get-Recipient -Identity "$($_.ForwardingAddress)").PrimarySmtpAddress } } }, DeliverToMailboxAndForward
	
	if ($null -ne $mbxWithForward) {
		Write-Host -ForegroundColor Yellow "ForwardingAddress and ForwardingSMTP Address found"
		$mbxWithForward
	}
	else {
		Write-Host -ForegroundColor Green "SERVER SIDE (forwardingAddress and ForwardingSMTP Address) : No forward on server side"
	}
	#>
	
	$mailboxesWithForward = New-Object 'System.Collections.Generic.List[System.Object]'

	if (-not($InboxRulesOnly)) {
		foreach ($mailbox in $mailboxeslist) {
			Write-Host -ForegroundColor cyan "Processing ForwardingAddress|ForwardingSMTPAddress - $($mailbox.Name) - $($mailbox.PrimarySMTPAddress)"
			#$forward = $mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress) -or ($null -ne $_.ForwardingAddress) } | Select-Object Name, PrimarySmtpAddress, ForwardingSMTPAddress, ForwardingAddress, @{Name = 'ForwardingAddressConvertSMTP'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress] } } }, DeliverToMailboxAndForward

			<# --- Forwarding Address part ---
			ForwardingAddress is a RecipientIdParameter and used when you want to forward emails to a mail-enabled object. 
			The target object should exists in your ActiveDirectory | Exchange Online as a mail-enabled object like MailUser, Contact or RemoteMailUser.
			If you do not have a mail-enabled object for your forwarding address then this will not work.  
			ForwardingAddress can be set by using the -ForwardingAddress parameter in the command set-mailbox.
			#>

			$forwardingAddress = $mailbox | Where-Object { ($null -ne $_.ForwardingAddress) } | Select-Object Name, PrimarySmtpAddress, ForwardingAddress, @{Name = 'ForwardingAddressConverted'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress] } } }, DeliverToMailboxAndForward
			#$forward = $mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress -and -not($domains -contains $_.ForwardingSMTPAddress.split('@')[1])) -or ($null -ne $_.ForwardingAddress -and -not($domains -contains $hashRecipients[$_.ForwardingSMTPAddress].split('@')[1]) ) } | Select-Object Name, PrimarySmtpAddress, ForwardingSMTPAddress, ForwardingAddress, @{Name = 'ForwardingAddressConvertSMTP'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress] } } }, DeliverToMailboxAndForward	

			
			if ($null -ne $forwardingAddress) {  
				if ($internalDomains -match $forwardingAddress.ForwardingAddressConverted.Split('@')[1] -and $autoForwardMode) {
					$forwardingWorks = "True (autoForward mode = $autoForwardMode)"
				}
				elseif ($autoForwardMode -eq 'Automatic' -or $autoForwardMode -eq 'Off') {
					$forwardingWorks = "False (autoForward mode = $autoForwardMode)" 
				}
				else {
					$forwardingWorks = "True (autoForward mode = $autoForwardMode)"
				}

				$object = [pscustomobject][ordered]@{
					Identity                               = $mailbox.Identity
					Name                                   = $mailbox.Name
					DisplayName                            = $mailbox.DisplayName	
					PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
					UserPrincipalName                      = $mailbox.UserPrincipalName
					ForwardType                            = 'ForwardingAddress'
					ForwardScope                           = ''
					Precedence                             = '-'
					ForwardingAddress                      = $forwardingAddress.ForwardingAddress
					ForwardingAddressConverted             = $forwardingAddress.ForwardingAddressConverted
					ForwardingSMTPAddress                  = '-'
					ForwardingWorks                        = $forwardingWorks
					DeliverToMailboxAndForward             = '-'
					InboxRulePriority                      = '-'
					InboxRuleEnabled                       = '-'
					InboxRuleRedirectTo                    = '-'
					InboxRuleForwardTo                     = '-'
					InboxRuleForwardAsAttachmentTo         = '-'
					InboxRuleSendTextMessageNotificationTo = '-'
					InboxRuleDescription                   = '-'
				}

				#Add object to an array
				$null = $mailboxesWithForward.Add($object)
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
			#$forward = $mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress -and -not($domains -contains $_.ForwardingSMTPAddress.split('@')[1])) -or ($null -ne $_.ForwardingAddress -and -not($domains -contains $hashRecipients[$_.ForwardingSMTPAddress].split('@')[1]) ) } | Select-Object Name, PrimarySmtpAddress, ForwardingSMTPAddress, ForwardingAddress, @{Name = 'ForwardingAddressConvertSMTP'; Expression = { if ($null -ne $_.ForwardingAddress) { $hashRecipients[$_.ForwardingAddress] } } }, DeliverToMailboxAndForward	
			
			if ($null -ne $forwardingSMTPAddress) { 
				if ($mailboxesWithForward.PrimarySMTPAddress -contains $mailbox.PrimarySmtpAddress) {
					$precedence = 'ForwardingAddress is already set for this mailbox. ForwardingAddress has a higher priority than the ForwardingSMTPAddress. This ForwardingSMTPAddress is ignored'
				}
				else {
					$precedence = '-'
				}

				if ($internalDomains -match $forwardingSMTPAddress.forwardingSMTPAddress.Split('@')[1] -and $autoForwardMode) {
					$forwardingWorks = "True (autoForward mode = $autoForwardMode)"
				}
				elseif ($autoForwardMode -eq 'Automatic' -or $autoForwardMode -eq 'Off') {
					$forwardingWorks = "False (autoForward mode = $autoForwardMode)" 
				}
				else {
					$forwardingWorks = "True (autoForward mode = $autoForwardMode)"
				}

				$object = [pscustomobject][ordered]@{
					Identity                               = $mailbox.Identity
					Name                                   = $mailbox.Name
					DisplayName                            = $mailbox.DisplayName	
					PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
					UserPrincipalName                      = $mailbox.UserPrincipalName
					ForwardType                            = 'ForwardingSMTPAddress'
					ForwardScope                           = ''
					Precedence                             = $precedence
					ForwardingAddress                      = '-'
					ForwardingAddressConvertSMTP           = $forwardingSMTPAddress.ForwardingAddressConvertSMTP
					ForwardingSMTPAddress                  = $forwardingSMTPAddress.ForwardingSMTPAddress
					ForwardingWorks                        = $forwardingWorks
					DeliverToMailboxAndForward             = $forwardingSMTPAddress.DeliverToMailboxAndForward
					InboxRulePriority                      = '-'
					InboxRuleEnabled                       = '-'
					InboxRuleRedirectTo                    = '-'
					InboxRuleForwardTo                     = '-'
					InboxRuleForwardAsAttachmentTo         = '-'
					InboxRuleSendTextMessageNotificationTo = '-'
					InboxRuleDescription                   = '-'
				}

				#Add object to an array
				$null = $mailboxesWithForward.Add($object)
			}
		}
	}
	#$mailboxesWithInboxForward = New-Object 'System.Collections.Generic.List[System.Object]'
	$i = 0
	if (-not($ForwardingAndForwardingSMTPOnly)) {
		foreach ($mailbox in $mailboxeslist) {
			$i++
			Write-Host -ForegroundColor cyan "Processing Inbox rules - $($mailbox.Name) - $($mailbox.PrimarySMTPAddress) [$i/$($mailboxeslist.count)]"

			$mailboxInboxForwardRules = Get-InboxRule -Mailbox "$($mailbox.DistinguishedName)" | Where-Object { ($null -ne $_.ForwardTo) -or ($null -ne $_.ForwardAsAttachmentTo) -or ($null -ne $_.RedirectTo) -or ($_.SendTextMessageNotificationTo.count -gt 0) } | Select-Object Identity, Enabled, ForwardTo, ForwardAsAttachmentTo, RedirectTo, SendTextMessageNotificationTo, Description, Priority
			
			if (($mailboxInboxForwardRules | Measure-Object).count -gt 0) {
				Write-Host -ForegroundColor yellow "$($mailbox.Name) - $($mailbox.PrimarySMTPAddress) - $(($mailboxInboxForwardRules | Measure-Object).count) forward rule(s) found"

				foreach ($mailboxInboxForwardRule in $mailboxInboxForwardRules) {
					if ($null -ne $mailboxInboxForwardRule) {  
						if ($mailboxesWithForward.PrimarySMTPAddress -contains $mailbox.PrimarySmtpAddress) {
							$precedence = 'ForwardingAddress | ForwardingSMTPAddress is already set for this mailbox. They have a higher priority than inbox rules. This inbox rule will be ignored'
						}
						else {
							$precedence = '-'
						}

						$object = [pscustomobject][ordered]@{
							Identity                               = $mailbox.Identity
							Name                                   = $mailbox.Name
							DisplayName                            = $mailbox.DisplayName	
							PrimarySmtpAddress                     = $mailbox.PrimarySmtpAddress
							UserPrincipalName                      = $mailbox.UserPrincipalName
							ForwardType                            = 'InboxRule'
							ForwardScope                           = ''
							Precedence                             = $precedence
							ForwardingAddress                      = '-'
							ForwardingSMTPAddress                  = '-'
							ForwardingAddressConvertSMTP           = '-'
							DeliverToMailboxAndForward             = '-'
							InboxRulePriority                      = $mailboxInboxForwardRule.Priority
							InboxRuleEnabled                       = $mailboxInboxForwardRule.Enabled
							InboxRuleRedirectTo                    = $mailboxInboxForwardRule.RedirectTo
							InboxRuleForwardTo                     = $mailboxInboxForwardRule.ForwardTo
							InboxRuleForwardAsAttachmentTo         = $mailboxInboxForwardRule.ForwardAsAttachmentTo
							InboxRuleSendTextMessageNotificationTo = $mailboxInboxForwardRule.SendTextMessageNotificationTo
							InboxRuleDescription                   = $mailboxInboxForwardRule.Description.replace("`r`n", " ").replace("`t", "") # on supprime les sauts de lignes et les tabulations 
						}
						
						#Add object to an array
						$null = $mailboxesWithForward.Add($object)

					}
				}
			}
			else {
				#Write-Host -ForegroundColor green "$($mailbox.Name) $($mailbox.PrimarySMTPAddress) - No inbox forward rule found"	
			}
		}
	}

	Write-Host -ForegroundColor cyan "$($mailboxesWithForward.count) mailboxes with forward found"

	$mailboxesWithForward | ForEach-Object {
		if ((($_.ForwardingAddressConverted -like '*@*') -and -not($domains -contains $_.ForwardingAddressConverted.split('@')[1])) -or (($_.ForwardingSMTPAddress -like '*@*') -and -not($domains -contains $_.ForwardingSMTPAddress.split('@')[1])) -or (($_.InboxRuleForwardTo -like '*@*') -and -not($domains -contains $_.InboxRuleForwardTo)) -or (($_.InboxRuleForwardAsAttachmentTo -like '*@*') -and -not($domains -contains $_.InboxRuleForwardAsAttachmentTo)) -or (($_.InboxRuleRedirectTo -like '*@*') -and -not($domains -contains $_.InboxRuleRedirectTo)) -or ($_.InboxRuleSendTextMessageNotificationTo -ne '-')) {
			$_.ForwardScope = 'External'
		}
		else {
			$_.ForwardScope = 'Internal'
		}
	}

	if ($ExportResults) {
		$filepath = "$($env:temp)\$(Get-Date -format yyyyMMdd_hhmm)_forward.csv"
		Write-Host -ForegroundColor green "Export results to $filepath"
				
		$mailboxesWithForward | Export-CSV -NoTypeInformation -Encoding UTF8 $filepath

		Invoke-Item $filepath
	}
	else {
		return $mailboxesWithForward
	}
}