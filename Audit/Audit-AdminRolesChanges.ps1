# Admin roles list: https://docs.microsoft.com/en-us/microsoft-365/compliance/search-the-audit-log-in-security-and-compliance?view=o365-worldwide
$records = Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-90) -EndDate (Get-Date).AddDays(1) -Operations ('Add Member to Role','Remove Member From Role') -ResultSize 2000 -Formatted

if ($records.Count -eq 0) {
   Write-Host 'No audit logs found'
}else {
   Write-Host "Processing $($Records.Count) audit records..."
   
   $report = New-Object System.Collections.Generic.List[Object]
	ForEach ($record in $records) {
		$auditData = ConvertFrom-Json $record.Auditdata
		# Only process the additions of guest users to groups
	
		$timeStamp = Get-Date $record.CreationDate -format g
		# Try and find the timestamp when the Guest account was created in AAD
	
		$object = [PSCustomObject]@{
			TimeStamp   = $timeStamp
			
			ObjectId		= $auditData.ObjectId
			Action      	= $auditData.Operation
			Actor        	= $auditData.UserId
			ActorIpAddress	= $auditData.ActorIpAddress
			RoleName   		= $auditData.modifiedproperties.newvalue[1]
		}      
	   
		$report.Add($object)
	}
	
	return $report
}