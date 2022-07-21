<#
.SYNOPSIS
Search-AdminRolesChanges.ps1 - Reports on Office 365 Admin Role

.DESCRIPTION 
This script produces a report of the membership of Office 365 admin role groups.
By default, the report contains only the groups with members.
To get all the role, included empty roles, add -IncludeEmptyRoles $true

.OUTPUTS
The report is output to an array contained all the audit logs found.
To export in a csv, do Search-AdminRolesChanges | Export-CSV -NoTypeInformation "$(Get-Date -Format yyyyMMdd)_adminRolesChange.csv"

.EXAMPLE
Search-AdminRolesChanges

.LINK
https://itpro-tips.com/2020/get-the-office-365-admin-roles-and-track-the-changes/
https://github.com/itpro-tips/Microsoft365-Toolbox/blob/master/Audit/Search-AdminRolesChanges.ps1


.NOTES
Written by Bastien Perez (ITPro-Tips.com)
For more Office 365/Microsoft 365 tips and news, check out ITPro-Tips.com.

Version history:
V1.0, 17 august 2020 - Initial version
V.1.1, 4 january 2020 - Add ObjectUserPrincipalName

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
DEALINGS IN THE SOFTWARE.

#>

# Admin roles list: https://docs.microsoft.com/en-us/microsoft-365/compliance/search-the-audit-log-in-security-and-compliance?view=o365-worldwide
function Search-AdminRolesChanges {
	[CmdletBinding()]
	param (
		[string[]]$ObjectIDs
	)
    
	try {
		Import-Module exchangeonlinemanagement -ErrorAction stop
	}
	catch {
		Write-Warning 'First, install the official Microsoft Exchange Online Management module : Install-Module ExchangeOnlineManagement'
		return
	}

	try {
		$null = Get-Command Search-UnifiedAuditLog -ErrorAction Stop
	}
	catch {
		Write-Host 'Connect to Exchange Online' -ForegroundColor Cyan
		
		try {
			Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
		}
		catch {
			Write-Warning 'Unable to connect to Exchange Online'
			return
		}
	}
	
	try {
		#$maxAdminLogAge = [System.TimeSpan]::Parse((Get-AdminAuditLogConfig).AdminAuditLogAgeLimit).Days
		$maxAdminLogAge = 365
		Write-Host 'Search Add/Remove Member to Role actions logs' -ForegroundColor Cyan

		if ($ObjectIDs) {
			$objects = New-Object System.Collections.Generic.List[String]
			foreach ($obj in $ObjectIDs) {
				$user = Get-User $obj
				$null = $objects.Add($user.UserPrincipalName)
				$null = $objects.Add($user.ExternalDirectoryObjectId)
			}
				
		}
		else {
			# Set tp $null to search All
			$objects = $null 
		}

		$records = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-$maxAdminLogAge) -EndDate (Get-Date).AddDays(1) -Operations ('Add Member to Role', 'Remove Member From Role') -ResultSize 2000 -Formatted -ObjectIds $objects
	}
	catch {
		Write-Warning "Unable to gather information $($_.Exception.Message)"
		return
	}

	if ($records.Count -eq 0) {
		Write-Host 'No audit logs found' -ForegroundColor Green
	}
	else {
		
		Write-Host "Processing $($Records.Count) audit records..." -ForegroundColor Cyan
   
		$report = New-Object System.Collections.Generic.List[Object]
		ForEach ($record in $records) {
			$auditData = ConvertFrom-Json $record.Auditdata

			$timeStamp = Get-Date $record.CreationDate -format g

			# Test if ObjectID is GUID or the UserPrincipalName
			if ($auditData.ObjectID -match '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$') {
				$objectID = $auditData.ObjectID
			}
			else {
				$objectID = ($auditData.Target | Where-Object { $_.Type -eq 2 -and $_.ID -match '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$' }).ID # several values are with Type=2 ('User_GUID', 'GUID', 'User', 'NetID') The good value is a GUID so we filter one the value which matches GUID
			}
			
			$object = [PSCustomObject]@{
				TimeStamp               = $timeStamp
				ObjectId                = $objectID
				ObjectUserPrincipalName	= ($auditData.Target | Where-Object { $_.Type -eq 5 }).Id # value is @{ID=xxx@domain; Type=5
				RoleName                = $auditData.modifiedproperties.newvalue[1]
				Action                  = $auditData.Operation
				Actor                   = $auditData.UserId
				ActorIpAddress          = $auditData.ActorIpAddress
			}      
	   
			$report.Add($object)
		}
	
		return $report
	}
}