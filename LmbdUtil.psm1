<#
 # This module includes utility functions that are based on
 #
 # the AWSPowerShell module and AWSSDK to provide help administering
 # 
 # relevant tasks for AWS lambda functions.
 #>

<#
 .SYNOPSIS
 Get an extended list of data on aws lambdas.

 .DESCRIPTION
 Retrieve a list of lambda functions, config details and function policy statuses.
 #>
Function Get-AWSLmbds {
param([string]$accessKey,[string]$accessSecret,[string]$LambdaName)

if (Test-Path "$env:ProgramFiles\WindowsPowerShell\Modules\AWSPowerShell\3.3.604.0\") {

if ((Get-Module -Name AWSPowerShell) -eq $null) {
Import-Module AWSPowerShell -ErrorVariable "moduleimport" -Force
 Set-AWSCredential -AccessKey $accessKey -SecretKey $accessSecret -StoreAs "credsaws"
  Initialize-AWSDefaultConfiguration -ProfileName credsaws -Region (Get-DefaultAWSRegion)
 } else  {Trap { return Write-Host " Problem wih  module - error $moduleimport" -ErrorAction Stop; } }
}
else {
Trap [System.Exception] {
return Write-Host "Path with module N/A, exiting." -ErrorAction Stop;
 }
}

Try {
 $awskeysecret = (Get-AWSCredential).GetCredentials()
 $lmfuncs = Get-LMFunctionList -AccessKey $awskeysecret.AccessKey -Credential (Get-AWSCredential) -Region (Get-DefaultAWSRegion) | ?{$_.FunctionName -eq $LambdaName} -ErrorVariable 'exception' -ErrorAction Stop;
  $lmconfigInfo = Get-LMFunctionConfiguration -AccessKey $awskeysecret -Credential (Get-AWSCredential) -Region (Get-DefaultAWSRegion) -FunctionName $lmfuncs.FunctionName -ErrorVariable 'exception' -ErrorAction Stop;
  $lmpolicyInfo = ((Get-LMPolicy -FunctionName $lmfuncs.FunctionName).Policy | ConvertFrom-Json -ErrorVariable 'exception' -ErrorAction Stop).Statement;

  $LmbdInfoOut = New-Object -TypeName PSCustomObject;

  # Basic function information.
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "Name" -Value $lmconfigInfo.FunctionName
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "Handler" -Value $lmconfigInfo.Handler
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "LatestUpdate" -Value (($lmconfigInfo.LastModified) -replace "T" , "  " -replace "\+0000", "")
  
  # Extended config information.
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "Runtime" -Value $lmconfigInfo.Runtime
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "TracingConfig" -Value $lmconfigInfo.TracingConfig
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "TraceMode" -Value ($lmconfigInfo.TracingConfig.Mode)
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "LambdaSize" -Value $lmconfigInfo.CodeSize

  # Policy function information.
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "PolicyLevel" -Value ($lmpolicyInfo.Effect | Select -First 1)
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "PolicyType" -Value ($lmpolicyInfo.Principal | Select -First 1).Service
  $LmbdInfoOut | Add-Member -MemberType NoteProperty -Name "FunctionState" -Value $lmconfigInfo.HttpStatusCode
   }
  Catch{
  return Write-Error "Exception occured while retrieving info. Error Information - $($exception)" -ErrorAction Stop
  }
  return $LmbdInfoOut;
}

<#
 .DESCRIPTION
 Check whether an aws gateway has any HTTP methods enabled.

 .PARAMETER ApiGatewayRest
 The list of endpoint objects to check.

 .PARAMETER resPathName
 The resource name as endpoint path to perform the relevant HTTP methods check.
 #>
Function Test-AWSMethodsExist {
[CmdLetBinding()]
param(
[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
[PSCustomObject[]]$ApiGatewayRest,
[string]$resPathName
)
Process{ $resultEP = ($ApiGatewayRest | ?{$_.PathPart -eq $resPathName}) }
End {return $resultEP.ResourceMethods.Count -ne 0}
}

<#
 .DESCRIPTION
 Function used to identify whether a lambda is enabled on an aws api gateway endpoint.
 This also checks that any http methods are included for the relevant resource.

 .PARAMETER LambdaPart
 The name of the lambda function to validate.

 .PARAMETER AgResEndPointName
 The name of the api gateway used to perform the check.

 .PARAMETER AgResName
 The resource name on the api gateway.
 #>
Function Test-AWSLambdaEnabled {
[CmdletBinding()]
param(
[Parameter(Mandatory=$true,Position=0)]
[string]$LambdaPart,
[string]$AgResEndPointName,
[string]$AgResName
)

$endpointId = (Get-AGRestApiList -Region (Get-DefaultAWSRegion) | ?{ $_.Name -eq $AgResEndPointName}).Id
$resourceId = (Get-AGResourceList -RestApiId $endpointId -Region (Get-DefaultAWSRegion) | ?{$_.Path -ne "/" -and $_.PathPart -ne $null -and $_.PathPart -eq $AgResName}).Id

 if ($resourceId | Test-AWSMethodsExist -resPathName $AgResName) {
 return Write-Error "$([System.ArgumentException]::new("EndPoint setup does not include any http methods"))";
}
return ((Get-AGIntegration -HttpMethod "GET" -RestApiId $endpointId -ResourceId $resourceId).Uri -ilike "*$LambdaPart*")
}

<#
 .DESCRIPTION
 Used to call a lambda that is set on an aws api execution url.
 The function first checks that the endpoint has the function associated with it and 
 that the lambda is not in an error state. On error while calling the function,
 a default s3 bucket content can be set as an alternative response.

 .PARAMETER RestEndPointName
 The relevant rest api that hosts the function.

 .PARAMETER AGWStageName
 The stage name that is used for deployment on the gateway.

 .PARAMETER AGWResourceName
 The name of the resource on the gateway.

 .PARAMETER LmbdName
 The name of the lambda that is associated with the relevant gateway.
 #>
Function Invoke-AWSLambdaEndPoint {
param (
[string]$RestEndPointName,
[string]$AGWstageName,
[string]$AGWResourceName,
[string]$LmbdName
)

Try {

if (Test-AWSLambdaEnabled -LambdaPart $LmbdName -AgResEndPointName $RestEndPointName -AgResName $AGWResourceName) {
$lmbdres = (Invoke-LMFunction -FunctionName $LmbdName);
 if ($lmbdres.StatusCode -eq 200) {

 $regionName = ((Get-AWSRegion | ?{$_.Region -ilike "*us-west*"}) | Select -Last 1).Region;
$awsEpId = (Get-AGRestApiList -Region (Get-DefaultAWSRegion) | ?{ $_.Name -eq $RestEndPointName }).Id;
$resapigate = Get-AGResourceList -RestApiId ($awsEpId) -Region (Get-DefaultAWSRegion) | ?{$_.Path -ne "/" -and $_.PathPart -ne $null -and $_.PathPart -eq $AGWResourceName}

  $fullapiurl = "https://{0}.execute-api.{1}.amazonaws.com/{2}/{3}" -f $awsEpId, $regionName, $AGWStageName, "$($resapigate.PathPart)";
  $apiurl=$fullapiurl -replace  "/ ","/";
  $response = Invoke-RestMethod -Uri $apiurl -UseDefaultCredentials -UseBasicParsing
  
 } else {
  return  ("{'ErrorContent':'Function is in an error state.'}" | ConvertFrom-Json);
}
 } else {
return  ("{'ErrorContent':'Function not included in the endpoint.'}" | ConvertFrom-Json);
 }
}

Catch {
Write-Host "Failed to properly invoke function, getting default bucket response." | Out-Null; $_ | Out-File ".\error-awslambda.log";
   $response = ((Invoke-WebRequest -Uri "https://xxxxxx.s3-xxxx.amazonaws.com/xxxxxx/data.json").Content)
   } # Catch Exceptions retrieve default dataset from an s3 bucket.

return ($response | ConvertFrom-Json);
}

<#
 .DESCRIPTION
 This function checks that a lambda has vpc configuration.

 .PARAMETER LambdaName
 Name of the function used for the relevant check.
 #>
Function Test-AWSVpcCfg {
param(
[string]$LambdaName
)
return (Get-LMFunctionConfiguration -Credential (Get-AWSCredential) -FunctionName $LambdaName).VpcConfig -ne $null;
}

<#
 .DESCRIPTION
 Check whether a lamdba has an associated s3 policy enabled.

 .PARAMETER LambdaName
 Name of the function used for the relevant check.
 #>
Function Test-S3Enabled {
param(
[string]$LambdaName
)
$lambdapol = Get-LMPolicy -Credential (Get-AWSCredential) -FunctionName $LambdaName -Region (Get-DefaultAWSRegion);
$policy = $lambdapol.Policy | ConvertFrom-Json;
return (($policy.Statement.Principal.Service | ?{$_ -ilike "*s3*"}).Length -ne 0)
}