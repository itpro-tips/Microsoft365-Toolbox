$mbxs = Get-Mailbox -ResultSize unlimited -RecipientTypeDetails Usermailbox
$permission = 'Reviewer'

foreach ($mbx in $mbxs) {
    $calFolders = @($mbx | Get-MailboxFolderStatistics -FolderScope Calendar | Where-Object { $_.FolderType -eq 'Calendar' } )

    $defaultCalendar = $calFolders | Where-Object ContainerClass -eq ''

    Write-Host -ForegroundColor Cyan "Add $permission permissions for $($mbx.alias):\$($defaultCalendar.Name)"
    Set-MailboxFolderPermission -Identity "$($mbx.alias):\$($defaultCalendar.Name)" -User Default -AccessRights $permission
}