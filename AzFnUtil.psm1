<#
 # Module that includes utility functions that make use of 
 #
 # AzureRM and relevant SDKs in order to
 #
 # help with azure functions management.
 #>

<#
 .DESCRIPTION
 Used for validating whether an azure web app is a function.

 .PARAMETER appSvc
 The web app used to perform the relevant checks by.
 #>
Function Test-AzFn {
param(
[Parameter(Mandatory=$true,Position=0)]
[PSCustomObject]$appSvc
)
return $appSvc.kind -ilike "*function*";
}

<#
 .DESCRIPTION
 Used to check the running status of a specific azure function from an azure web app list.

 .PARAMETER fnName
 The azure function name to check.
 
 .PARAMETER webapp
 The list of azure functions app services to perform the necessary checks based on the function name.
 #>
Function Test-FnStopped {
param(
[Parameter(Mandatory=$true,Position=0)]
[string]$fnName,
[Parameter(Mandatory=$true,Position=1)]
[PSCustomObject[]]$webapp
)
$reswebApp = $webApp | ?{Test-AzFn -appSvc $_}
return ($reswebapp | ?{$_.Name -eq $fnName}).state -eq "Stopped";
}

<#
 .SYNOPSIS
 Retrieve a nested listing of all azure function apps and relevant functions -with details-

 .DESCRIPTION
 Get all azure function apps from list of web apps and all inner function data that are a  
 part of a function project. This includes basic top level information and the 
 extended functions data of the web application such as: invokable url, inner function name, language.
 #>
Function Get-AzureFn {

if(((Get-Module -ListAvailable Azure) -ne $null) -and ($env:PSModulePath -ilike "*\Microsoft SDKs\Azure\*")) {
Write-Host "Azure SDK detected OK.." -ForegroundColor Cyan -BackgroundColor DarkBlue
    $is32bit = (Test-Path "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell");
    $is64bit = (Test-Path "$env:ProgramFiles\Microsoft SDKs\Azure\PowerShell");
    $sdkval ="";
if ($is32bit) {
 $sdkval = "32-bit";
 }
 if ($is64bit) {
 $sdkval ="64-bit";
 }
 Write-Host "Running script with $($sdkval) SDK.." -ForegroundColor Cyan -BackgroundColor DarkBlue
}

Try {
 if (((Get-Module AzureRM.Profile) -eq $null) -or ((Get-Module AzureRM.Websites) -eq $null)) {
  Write-Warning "`r`nSetting Azure SDK Modules..";
    Import-Module AzureRM.Profile,AzureRM.Websites -ErrorVariable "testmodule" -Force
 }
}
Catch {
    Write-Error "Cannot import modules properly, error $testmodule - Please make sure that the Azure SDK is installed properly.";
    return;
}

if ((Get-AzureRmContext -OutVariable 'azureRmCtx') -eq $null) {
Login-AzureRmAccount; return Write-Host "`r`n -- Login complete, re-run script. -- `r`n" -ErrorAction Stop;
}

$rgfnInfo = (Get-AzureRmResource | ?{$_.Kind -eq "web"});
if ($rgfnInfo -eq $null) {
Trap [System.Exception] {
return Write-Host "Could not retrieve azure resources, exiting.." -BackgroundColor Red -ForegroundColor DarkGray -ErrorAction Stop;
 }
}
$rgData = @{"rgName"=($rgfnInfo | Select -First 1 -ExpandProperty ResourceGroupName);
            "Plan"=$(($rgfnInfo | Select -First 1 -ExpandProperty Location)+"Plan")
            };

Try {
$appsvc = Get-AzureRmAppServicePlan -ResourceGroupName $rgData['rgName'] -Name $rgData['Plan']
$webAppsvcs = Get-AzureRmWebApp -AppServicePlan $appsvc
$subscr = (Get-AzureSubscription).SubscriptionId

# Azure profile modules v5.*
 $rmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile;
 $rmClient = [Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient]::new($rmProfile);
 $bearerAccess = $rmClient.AcquireAccessToken($azureRmCtx.Tenant.TenantId);

 $fnlisting = Invoke-WebRequest -Method Get -Uri "https://management.azure.com/subscriptions/$subscr/resourceGroups/$($rgData['rgName'])/providers/Microsoft.Web/sites/?api-version=2016-08-01" -UseDefaultCredentials -UseBasicParsing -Headers @{Authorization=("Bearer {0}" -f $bearerAccess.AccessToken)}
 $fns = ($fnlisting.Content | ConvertFrom-Json).Value.properties;
 $stoppedfns = $fns | %{ Test-FnStopped -fnName $_.name -webapp $_ } -ErrorAction SilentlyContinue

 $fnOutput = @();

 $stoppedfns | %{
 $fnObjOut = New-Object -TypeName PSCustomObject;
 $fnObjOut | Add-Member -MemberType NoteProperty -Name "Name" -Value $_.Name
 $fnObjOut | Add-Member -MemberType NoteProperty -Name "State" -Value $_.State;
 $fnObjOut | Add-Member -MemberType NoteProperty -Name "Enabled" -Value $_.Enabled;
 $fnObjOut | Add-Member -MemberType NoteProperty -Name "HttpsOnly" -Value $_.HttpsOnly;
 $fnObjOut | Add-Member -MemberType NoteProperty -Name "HostName" -Value $_.DefaultHostName;
 $fnObjOut | Add-Member -MemberType NoteProperty -Name "FunctionsDetail" -Value "";
 $fnOutput += $fnObjOut;
 }

 $datafnOut = @();
 $stoppedfns | %{
 $data = Invoke-WebRequest -Method Get -Uri "https://management.azure.com/subscriptions/$subscr/resourceGroups/$($rgData['rgName'])/providers/Microsoft.Web/sites/$($_.name)/functions?api-version=2016-08-01" -UseDefaultCredentials -UseBasicParsing -Headers @{Authorization=("Bearer {0}" -f $bearerAccess.AccessToken)};
 $datafnOut+=($data.Content | ConvertFrom-Json).value.properties;
    }

 [PSCustomObject[]]$fnInfo=@(); $r=0;
  $datafnOut | %{
  $fnInfo += @{"name"=$_.name;"href"=$_.href;"invoke_url"=$_.invoke_url;"language"=$_.language;"isDisabled"=$_.isDisabled};
  
  $fnOutput[$r].FunctionsDetail = $fnInfo;
  $r++;
  }
 }
Catch {
  Logout-AzureRmAccount;
  Clear-AzureRmContext -Force;
  Clear-AzureRmDefault -Force;
 return Write-Error "Exception Occured - $_" -ErrorAction Stop;
 }
 
# Terminate azure session and cmdlet process.
  Logout-AzureRmAccount;
  Clear-AzureRmContext -Force;
  Clear-AzureRmDefault -Force;
  return ($fnOutput | Format-Table)
}

<#
 .DESCRIPTION
 Calling an azure function directly from its url and perform
 error checks. An alternative response can be set via a blob container
 if there is an error on the function.

 .PARAMETER InvokeUrlPath
 The function's endpoint url used to make the http call and error checks.
 #>
Function Invoke-AzureFunctionEndPoint {
param(
[Parameter(Mandatory=$true,Position=0)]
[string]$InvokeUrlPath
)
Try {
$urlpath = "$InvokeUrlPath" -replace "\?","" -replace "<","" -replace ">","" -replace "@","" -replace "%", "" -replace "\\", "" -replace "&","" -replace "\*", "" -replace "-","" -replace "|","" -replace "`r`n","" -replace "\^","" -replace "\(", "" -replace "\)","" -replace ":{","" -replace ":\'","" -replace "\'}","" -replace ":\[","" -replace "\[\{","" -replace "\}\]" -replace "}","" -replace "\]","" -replace "\'","";
$response = Invoke-RestMethod -Uri $urlpath -ErrorVariable '$error' -UseDefaultCredentials -UseBasicParsing -ErrorAction SilentlyContinue
}
Catch {
Write-Host "Call to azure function failed, getting default response.." | Out-Null; $error | Out-File ".\error-azurefn.log"
$altern = ((Invoke-WebRequest -Uri "https://xxxxxx.blob.core.windows.net/xxxxxx/data.json").Content | ConvertFrom-Json);
return $altern; # Catch exception, retrieve alternative response from an azure blob container
}
return ($response.httpResponse | ConvertFrom-Json);
}