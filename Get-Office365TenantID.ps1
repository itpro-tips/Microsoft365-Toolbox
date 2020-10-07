# Another great way to get tenant ID from domain: https://www.whatismytenantid.com/result
Param(
	[string]$Domain
)

(Invoke-WebRequest https://login.windows.net/$domain/.well-known/openid-configuration|ConvertFrom-Json).Token_Endpoint.Split("/")[3]