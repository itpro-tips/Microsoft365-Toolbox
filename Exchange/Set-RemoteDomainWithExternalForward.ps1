# I had problems sending to an address with an external forward, even with this remotedomain parameter. solved when I deleted the base address in the OWA cache (auto-complete list).
# I don't know if it's related or just a waiting time...
# and it doesn't work anymore... in my opinion there's a waiting time
# and works again after a waiting time...
$domain = Read-Host 'Domain name?'

Get-HostedOutboundSpamFilterPolicy | Set-HostedOutboundSpamFilterPolicy -AutoForwardingMode 'On'

# Automatic transfer blocked by default
Set-RemoteDomain Default -AutoForwardEnabled $false

# New domain creation and automatic transfer authorization
New-RemoteDomain -DomainName $domain -Name $domain
Set-RemoteDomain -Identity $domain -AutoForwardEnabled $true