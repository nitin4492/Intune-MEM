<#
.SYNOPSIS
	This script finds out the Discovered Apps in Intune

.EXAMPLE
#>

param(
[parameter(Mandatory=$True)]
$AppName
)

Connect-MSGraph

#Find Discovered Apps From Intune (It uses Intune Inventory to get apps from Add\RTemove Programs Entry)
$FindApp=Get-IntuneDetectedApp -Filter "displayName eq '$AppName'"
if($FindApp)
{
$result=$FindApp | Out-GridView -OutputMode:Single -Title "Select your Desired Discovered Application"
Get-IntuneDetectedAppDevice -detectedAppId $result.id | Out-GridView
}
else
{
write-host "Particular App Not Discovered" -ForegroundColor Green
}

