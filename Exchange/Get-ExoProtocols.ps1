$tenantSmtpClientAuthenticationDisabled = (Get-TransportConfig).SmtpClientAuthenticationDisabled

if ($tenantSmtpClientAuthenticationDisabled) {
    Write-Host "SMTP Client Authentication is disabled" -ForegroundColor Green
    $tenantSmtpClientAuthenticationEnabled = $false
}
else {
    Write-Host "SMTP Client Authentication is enabled" -ForegroundColor Yellow
    $tenantSmtpClientAuthenticationEnabled = $true
}

# PropertySets All because by default SMTPClientAuthenticationDisabled is not returned
$casMailboxes = Get-EXOCasMailbox -ResultSize Unlimited  -PropertySets All

<#
ECPEnabled        : True
OWAEnabled        : True
ImapEnabled       : True
PopEnabled        : True
MAPIEnabled       : True
EwsEnabled        : True
ActiveSyncEnabled : True
#>

[System.Collections.Generic.List[PSObject]]$exoCasMailboxesArray = @()
foreach ($casMailbox in $casMailboxes) {
    
    $object = [PSCustomObject][ordered]@{ 
        Name                                  = $casMailbox.Name
        ECPEnabled                            = $casMailbox.ECPEnabled
        OWAEnabled                            = $casMailbox.OWAEnabled
        ImapEnabled                           = $casMailbox.ImapEnabled
        PopEnabled                            = $casMailbox.PopEnabled
        MAPIEnabled                           = $casMailbox.MAPIEnabled
        EwsEnabled                            = $casMailbox.EwsEnabled
        ActiveSyncEnabled                     = $casMailbox.ActiveSyncEnabled
        # CMDlet returns SMTPClientAuthenticationDisabled but we want SMTPClientAuthenticationEnabled
        SMTPClientAuthenticationEnabled       = if ($null -ne $casMailbox.SMTPClientAuthenticationDisabled) { -not $casMailbox.SMTPClientAuthenticationDisabled }else { '-' }
        TenantSmtpClientAuthenticationEnabled = $tenantSmtpClientAuthenticationEnabled
    }

    $exoCasMailboxesArray.Add($object)
}

return $exoCasMailboxesArray