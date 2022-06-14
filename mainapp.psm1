<#  
 #  
 #  Main module used for calling other parts of the application.
 #  
 #  Includes utility classes with main functionality for scripts.
 #  
 #>
Import-Module '.\DirSize.psm1'   -Force
Import-Module '.\OtherInfo.psm1' -Force
Import-Module '.\PartInfo.psm1'  -Force 
Import-Module '.\ProceInfo.psm1' -Force 


<# Retrieve content for basic directories. #>
Class MainModule {
$_Cfg;
$_Export;
$_Content;
MainModule() {
  $this | Add-Member -MemberType ScriptProperty -Name Cfg     -Value  { return $this._Cfg }     -SecondValue { param($Value)$this._Cfg = $Value }
  $this | Add-Member -MemberType ScriptProperty -Name Export  -Value  { return $this._Export }  -SecondValue { param($Value)$this._Export = $Value }
  $this | Add-Member -MemberType ScriptProperty -Name Content -Value  { return $this._Content } -SecondValue { param($Value)$this._Content = $Value }
  }
}

<# All steps of core functions are performed here. #>
function infoRetrieval([Parameter(Mandatory=$false)][int]$r) {

$mainCaller = [MainModule]::new();

(Get-Variable  -Include *Info,*Size* -Scope Global -OutVariable "mod_vars") | %{
$mainCaller._Cfg = $_.Value.validateCfg();
$mainCaller._Cfg;

$mainCaller._Export = $_.Value.exportInfo();
$mainCaller._Export;

$mainCaller._Content = $_.Value.genContentWithTitle();
$mainCaller._Content;
 }
 if ($r -ne  $null) { $mod_vars[$($r)].Value.genContentWithTitle(); }
}

Export-ModuleMember -Function '*'
Export-ModuleMember -Variable '*'