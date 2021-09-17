function Get-SPOSiteExternalUsers {
    Write-Host 'Retrieving SPO Sites...' -ForegroundColor Cyan
    $SPOSitesCollectionsAll = Get-SPOSite -Limit All -IncludePersonalSite $true
  
    [System.Collections.Generic.List[PSObject]]$spoSitesExternalUsersInfos = @()
  
    # get external user on each site (included personal onedrive site)
    foreach ($site in $SPOSitesCollectionsAll) {
        # used to fix the bug of get-spoexternaluser with modern sharing https://vladtalkstech.com/2018/03/bug-in-get-spoexternaluser-powershell-not-all-external-users-are-returned-anymore.html
        #$externalUsers = Get-SPOUser -Limit All -Site $site.Url | Where-Object { $_.LoginName -like "*urn:spo:guest*" -or $_.LoginName -like "*#ext#*" }
  
        # The Get-SPOExternalUser cmdlet has a limitation of returning first 50 users only
        #Read more: https://www.sharepointdiary.com/2017/11/sharepoint-online-find-all-external-users-using-powershell.html#ixzz76dzw6hws
        for ($i = 0; ; $i += 50) {
            $externalUsers = Get-SPOExternalUser -SiteUrl $site.Url -PageSize 50 -Position $i -ErrorAction SilentlyContinue
        
            if ($externalUsers.count -eq 0) {
                break
            }
  
            foreach ($externalUser in $externalUsers) {
                $object = [pscustomobject][ordered] @{
                    SiteCollectionUrl = $site.Url
                    DisplayName       = $externalUser.DisplayName
                    OriginalEmail     = $externalUser.Email
                    AcceptedAs        = $externalUser.AcceptedAs
                    JoinDate          = $externalUser.WhenCreated
                    InvitedBy         = $externalUser.InvitedBy
                }
                
                $spoSitesExternalUsersInfos.Add($object)
            }
        }
    }
}