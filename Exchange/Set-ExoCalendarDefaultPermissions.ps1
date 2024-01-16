# permission list : https://learn.microsoft.com/en-us/powershell/module/exchange/set-mailboxfolderpermission?view=exchange-ps#-accessrights
<#
The following individual permissions are available:

None: The user has no access to view or interact with the folder or its contents.
CreateItems: The user can create items in the specified folder.
CreateSubfolders: The user can create subfolders in the specified folder.
DeleteAllItems: The user can delete all items in the specified folder.
DeleteOwnedItems: The user can only delete items that they created from the specified folder.
EditAllItems: The user can edit all items in the specified folder.
EditOwnedItems: The user can only edit items that they created in the specified folder.
FolderContact: The user is the contact for the specified public folder.
FolderOwner: The user is the owner of the specified folder. The user can view the folder, move the folder, and create subfolders. The user can't read items, edit items, delete items, or create items.
FolderVisible: The user can view the specified folder, but can't read or edit items within the specified public folder.
ReadItems: The user can read items within the specified folder.
The roles that are available, along with the permissions that they assign, are described in the following list:

Author: CreateItems, DeleteOwnedItems, EditOwnedItems, FolderVisible, ReadItems
Contributor: CreateItems, FolderVisible
Editor: CreateItems, DeleteAllItems, DeleteOwnedItems, EditAllItems, EditOwnedItems, FolderVisible, ReadItems
NonEditingAuthor: CreateItems, DeleteOwnedItems, FolderVisible, ReadItems
Owner: CreateItems, CreateSubfolders, DeleteAllItems, DeleteOwnedItems, EditAllItems, EditOwnedItems, FolderContact, FolderOwner, FolderVisible, ReadItems
PublishingAuthor: CreateItems, CreateSubfolders, DeleteOwnedItems, EditOwnedItems, FolderVisible, ReadItems
PublishingEditor: CreateItems, CreateSubfolders, DeleteAllItems, DeleteOwnedItems, EditAllItems, EditOwnedItems, FolderVisible, ReadItems
Reviewer: FolderVisible, ReadItems
#>

$mbxs = Get-Mailbox -ResultSize unlimited -RecipientTypeDetails Usermailbox

#$permission = 'Reviewer'
$permission = 'LimitedDetails'

foreach ($mbx in $mbxs) {
    $calFolders = @($mbx | Get-MailboxFolderStatistics -FolderScope Calendar | Where-Object { $_.FolderType -eq 'Calendar' } )

    $defaultCalendar = $calFolders | Where-Object ContainerClass -eq ''

    Write-Host -ForegroundColor Cyan "Add $permission permissions for $($mbx.alias):\$($defaultCalendar.Name)"
    Set-MailboxFolderPermission -Identity "$($mbx.alias):\$($defaultCalendar.Name)" -User Default -AccessRights $permission
}