# the CSV url is from https://docs.microsoft.com/en-us/azure/active-directory/enterprise-users/licensing-service-plan-reference
# not sure if the URL is always the same

$url = 'https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv'

# download the CSV file
Invoke-RestMethod -Uri $url -OutFile $PSScriptRoot\LicensesFriendlyName.csv