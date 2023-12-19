<#
source : https://o365reports.com/2020/03/04/export-office-365-license-expiry-date-report-powershell/=
#>
function Get-MsolSub {
    [CmdletBinding()]
    param (
    )

    [System.Collections.Generic.List[PSObject]]$subscriptionsArray = @()
    
    $friendlyNameHash = @{}

    Import-Csv -Path "$PSScriptRoot\LicensesFriendlyName.csv" -ErrorAction Stop -Delimiter ',' | Select-Object String_Id, Product_Display_Name -Unique | ForEach-Object {
        $friendlyNameHash.Add($_.String_Id, $_.Product_Display_Name)
    }

    # Get available subscriptions in the tenant
    $subscriptions = Get-MsolSubscription

    foreach ($subscription in $subscriptions) {
        # Determine subscription type
        $subscriptionType = if ($subscription.IsTrial) { 'Trial' } 
        elseif ($subscription.SKUPartNumber -like '*Free*' -or $null -eq $subscription.NextLifeCycleDate) { 'Free' }
        else { 'Purchased' }

        # Friendly Expiry Date
        $expiryDate = $subscription.NextLifeCycleDate
        $friendlyExpiryDate = if ($null -ne $expiryDate) {
            $daysToExpiry = (New-TimeSpan -Start (Get-Date) -End $expiryDate).Days
            switch ($subscription.Status) {
                'Enabled' { "Will expire in $daysToExpiry days" }
                'Warning' { "Expired. Will suspend in $daysToExpiry days" }
                'Suspended' { "Expired. Will delete in $daysToExpiry days" }
                'LockedOut' { 'Subscription is locked. Please contact Microsoft' }
            }
        }
        else {
            'Never Expires'
        }

        # Creating custom object for each subscription
        $object = [PSCustomObject][ordered]@{
            'Subscription Name'                                = $subscription.SKUPartNumber
            'Friendly Subscription Name'                       = $friendlyNameHash[$subscription.SKUPartNumber]
            'Subscribed Date'                                  = $subscription.DateCreated
            'Total Licenses'                                   = $subscription.TotalLicenses
            'Subscription Type'                                = $subscriptionType
            'License Expiry Date/Next LifeCycle Activity Date' = $expiryDate
            'Friendly Expiry Date'                             = $friendlyExpiryDate
            'Status'                                           = $subscription.Status
        }

        $subscriptionsArray.Add($object)
    }

    # Return the results
    return $subscriptionsArray
}