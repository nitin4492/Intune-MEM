param(
[parameter(Mandatory=$True)]
$SGName,
[switch]$CheckOnlyWin32_and_LOB=$false
)
#Find Application ID From Intune Apps
Function Get-Application_All{
#Find Device Install staus of application
$uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps"
$response = (Invoke-MSGraphRequest -Url $uri -HttpMethod Get)

$Apps = $response.Value
$AppsNextLink = $response."@odata.nextLink"
		while ($AppsNextLink) {
			$response = (Invoke-MSGraphRequest -Url $AppsNextLink -HttpMethod Get)
			$AppsNextLink = $response."@odata.nextLink"
			$Apps += $response.value
		}	

if($CheckOnlyWin32_and_LOB){
return $Apps | where {($_.DisplayName -eq $Appname) -and (($_.'@odata.type' -contains "#microsoft.graph.win32LobApp") -or ($_.'@odata.type' -contains "#microsoft.graph.windowsMobileMSI") )}
}
else
{
return $Apps
}

}

#Function to Get Particular App Assignment
Function Get-AppAssignment
{
Param(
[Parameter(mandatory=$true)]
$Appid
)

$graphApiVersion = "v1.0"
$Resource = "deviceAppManagement/mobileApps/$appid/?`$expand=categories,assignments"
$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
$response=(Invoke-MSGraphRequest -Url $uri -HttpMethod Get) | select -Property assignments

return $response

}

#Function to get AzureAD Group Details
Function Get-AzureADGroup
{
param(
$AADGrpId,
$SGName
)
# Defining Variables
$graphApiVersion = "v1.0"
$Group_resource = "groups"

if($SGName){
$URI = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayName%20eq%20%27$SGName%27%20"
$response= (Invoke-MSGraphRequest -Url $uri -HttpMethod Get).VALUE
}
else
{
$uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)/$AADGrpId"
$response= (Invoke-MSGraphRequest -Url $uri -HttpMethod Get)
}


return $response
}

$SGName=$SGName -replace "`"",""
#$SGName="SG-TB-MDM-MPA-Users"
Remove-item -Path "C:\Temp\IntuneApps_Matching_SGAssigned.csv" -Force -ErrorAction SilentlyContinue

Connect-MSGraph

$SG_grpid=Get-AzureADGroup -SGName $SGName | select -ExpandProperty id
if(!$SG_grpid)
{
write-host "SG - $SGname group id is not found." -ForegroundColor Red
return
}

#use below only if needs win32 and lob app
#$appresult=Get-Application_All -CheckOnlyWin32_and_LOB
$appresult=Get-Application_All

$result=@()
#iterate thru each app and check assigned SG
$appresult | %{
$appid=$_.id
$appname=$_.displayName
$datatype=$_."@odata.type"
$grps=Get-AppAssignment -Appid $appid

#check only if app has any assignments
if($grps.assignments){
foreach($grp in $grps.assignments){
#iterating thru each grps in the assignments
$grpid=$grp.id.Split("_")[0]

if($grpid -eq $SG_grpid){

$grpdetail=Get-AzureADGroup -AADGrpId $grpid

$output=[pscustomobject]@{
ApplicationName=$appname
AppId=$appid
SGName=$($grpdetail.displayName)
SGID=$($grpdetail.id)
AssignementIntent=$($grp.intent)
AppDataType=$($datatype)
}

$result+=$output
$output,$grpid=$null
}

}
}

$grps=$null


}

$result | fl

$result | export-csv "c:\temp\IntuneApps_Matching_SGAssigned.csv" -NoClobber -NoTypeInformation

