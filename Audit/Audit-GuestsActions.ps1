Connect-MsolService
Connect-ExchangeOnline

$extUsers = Get-MsolUser | Where-Object {$_.UserPrincipalName -like "*#EXT#*" }
$extUsers | ForEach {
    $auditEventsForUser = Search-UnifiedAuditLog -EndDate $((Get-Date)) -StartDate $((Get-Date).AddDays(-365)) -UserIds $_.UserPrincipalName
Write-Host "Events for" $_.DisplayName "created at" $_.WhenCreated
$auditEventsForUser | FT
}