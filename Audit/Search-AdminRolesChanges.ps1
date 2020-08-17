<#
.SYNOPSIS
Get-MsolRoleReport.ps1 - Reports on Office 365 Admin Role

.DESCRIPTION 
This script produces a report of the membership of Office 365 admin role groups.
By default, the report contains only the groups with members.
To get all the role, included empty roles, add -IncludeEmptyRoles $true

.OUTPUTS
The report is output to an array contained all the audit logs found.
To export in a csv, do Search-AdminRoleChanges | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRolesChange.csv"

.EXAMPLE
Search-AdminRoleChanges

.LINK
https://itpro-tips.com/2020/get-the-office-365-admin-roles-and-track-the-changes/

.NOTES
Written by Bastien Perez (ITPro-Tips.com)
For more Office 365/Microsoft 365 tips and news, check out ITPro-Tips.com.

Version history:
V1.0, 17 august 2020 - Initial version

Copyright (c) 2020 Bastien Perez (ITPro-Tips.com)

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.

#>

# Admin roles list: https://docs.microsoft.com/en-us/microsoft-365/compliance/search-the-audit-log-in-security-and-compliance?view=o365-worldwide
function Search-AdminRoleChanges {
	[CmdletBinding()]
	param (
	)
    
    try {
        Import-Module exchangeonlinemanagement -ErrorAction stop
    }
    catch {
        Write-Warning 'First, install the official Microsoft Exchange Online Management module : Install-Module exchangeonlinemanagement'
        return
    }

    try {
        $records = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-90) -EndDate (Get-Date).AddDays(1) -Operations ('Add Member to Role', 'Remove Member From Role') -ResultSize 2000 -Formatted-ErrorAction Stop
    }
    catch {
        Connect-ExchangeOnline
        $records = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-90) -EndDate (Get-Date).AddDays(1) -Operations ('Add Member to Role', 'Remove Member From Role') -ResultSize 2000 -Formatted
    }

	if ($records.Count -eq 0) {
		Write-Host 'No audit logs found'
	}
	else {
		Write-Host "Processing $($Records.Count) audit records..."
   
		$report = New-Object System.Collections.Generic.List[Object]
		ForEach ($record in $records) {
			$auditData = ConvertFrom-Json $record.Auditdata
			# Only process the additions of guest users to groups
	
			$timeStamp = Get-Date $record.CreationDate -format g
			# Try and find the timestamp when the Guest account was created in AAD
	
			$object = [PSCustomObject]@{
				TimeStamp      = $timeStamp
			
				ObjectId       = $auditData.ObjectId
				Action         = $auditData.Operation
				Actor          = $auditData.UserId
				ActorIpAddress	= $auditData.ActorIpAddress
				RoleName       = $auditData.modifiedproperties.newvalue[1]
			}      
	   
			$report.Add($object)
		}
	
		return $report
	}
}