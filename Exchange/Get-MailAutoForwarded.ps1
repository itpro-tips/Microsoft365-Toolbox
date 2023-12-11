<#You can use this cmdlet to search message data for the last 10 days. If you run this cmdlet without any parameters, data from last 10 days
If you enter a time period that's older than 10 days, you won't receive an error, but the command will return no results.
To search for message data that is greater than 10 days old, use the Start-HistoricalSearch and Get-HistoricalSearch cmdlets.
Careful about http://blog.icewolf.ch/archive/2020/10/06/how-to-control-the-many-ways-of-email-forwarding-in.aspx
Reports: https://protection.office.com/reportv2?id=MailFlowForwarding&pivot=Name
https://misstech.co.uk/2020/07/27/new-controls-available-to-block-automatic-email-forwarding/
#>

function Get-MailAutoForwarded {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$SenderAddress,
        [switch]$FailedOnly,
        [int]$Days = 10
    )

    $remoteDomains = Get-RemoteDomain

    foreach ($remoteDomain in $remoteDomains) {
        Write-Host "Remote Domain '$remotedomain' AutoForwardEnabled: $($remoteDomain.AutoForwardEnabled)"  -ForegroundColor Cyan
    }

    $outboundSpamPolicies = Get-HostedOutboundSpamFilterPolicy

    foreach ($outboundSpamPolicy in $outboundSpamPolicies) {
		
        Write-Host "OutboundSpamPolicy '$($outboundSpamPolicy.Name)' AutoForwardingMode: $($outboundSpamPolicy.AutoForwardingMode)" -ForegroundColor Cyan
		
        $autoForwardMode = $outboundSpamPolicy.AutoForwardingMode
		
        if ($autoForwardMode -eq 'Automatic') {
            Write-Host "Careful, the value 'Automatic is now the same as AutoForwardEnable=Off, means autoForward is even if the Remote domain(s) are configured with AutoForwardEnable = `$true
		Sources:
		https://office365itpros.com/2020/11/12/microsoft-clamps-down-mail-forwarding-exchange-online/
		http://blog.icewolf.ch/archive/2020/10/06/how-to-control-the-many-ways-of-email-forwarding-in.aspx
		https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/external-email-forwarding?view=o365-worldwide
		https://techcommunity.microsoft.com/t5/exchange-team-blog/all-you-need-to-know-about-automatic-email-forwarding-in/ba-p/2074888
	
		RoadMap ID: MC221113" -ForeGround Yellow
        }
    }

    Write-Host 'Get messages from the last' $days 'days' -ForegroundColor Cyan

    #The PageSize parameter specifies the maximum number of entries per page. Valid input for this parameter is an integer between 1 and 5000. The default value is 1000.
    if ($SenderAddress) {
        if ($FailedOnly) {   
            $messages = Get-MessageTrace -Status Failed -StartDate (Get-Date).AddDays(-$days) -EndDate (Get-Date) -PageSize 5000 -SenderAddress $SenderAddress
        }
        else {
            $messages = Get-MessageTrace -StartDate (Get-Date).AddDays(-$days) -EndDate (Get-Date) -PageSize 5000 -SenderAddress $SenderAddress
        }
    }
    else {
        if ($FailedOnly) {   
            $messages = Get-MessageTrace -Status Failed -StartDate (Get-Date).AddDays(-$days) -EndDate (Get-Date) -PageSize 5000 
        }
        else {
            $messages = Get-MessageTrace -StartDate (Get-Date).AddDays(-$days) -EndDate (Get-Date) -PageSize 5000
        }
    }
    
    Write-Host "Search in the $($messages.count) messages to find autoforward" -ForegroundColor green

    #only one Get-MessageTraceDetail for all because it's time consuming (12 seconds -> 8 seconds for about 20 messages!)
    #$messagesAutoForwarded = $messages | Get-MessageTraceDetail | Where-Object { $_.Detail -like '*LED=250 2.1.5 RESOLVER.MSGTYPE.AF; handled AutoForward addressed to external recipient*' -or $_.Detail -like '*LED=250 2.1.5 RESOLVER.FWD.Forwarded; recipient forward*' }
    $messagesAutoForwarded = $messages | ForEach-Object {Get-MessageTraceDetail -RecipientAddress $_.RecipientAddress -MessageTraceId $_.MessageTraceId | Where-Object { $_.Detail -like '*LED=250 2.1.5 RESOLVER.MSGTYPE.AF; handled AutoForward addressed to external recipient*' -or $_.Detail -like '*LED=250 2.1.5 RESOLVER.FWD.Forwarded; recipient forward*' }}
    
    [System.Collections.Generic.List[PSObject]]$emailsWithAutoForward = @()

    foreach ($messageAF in $messagesAutoForwarded) {
        # Get-MessageTraceDetail does not return info about sender, etc. so we search in the $messages list the $message
        $message = $messages | Where-Object { $_.MessageId -eq $messageAF.MessageId }
	
        $message | ForEach-Object {
            $object = [PSCustomObject] [ordered]@{
                SenderAddress    = $_.SenderAddress
                RecipientAddress = $_.RecipientAddress
                Subject          = $_.Subject
                Detail           = $messageAF.detail
                Status           = $_.Status
                Received         = $_.Received
                FromIP           = $_.FromIP
                ToIP             = $_.ToIP
                MessageId        = $_.MessageId
            }
    
            $emailsWithAutoForward.add($object)
        }
    }

    return $emailsWithAutoForward
}