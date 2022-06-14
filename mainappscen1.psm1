<#  
 #  
 #  Main module used for calling other parts of the application.
 #  
 #  Includes utility classes with main functionality for scripts.
 #  
 #>
Import-Module -Force '.\DirSize.psm1'
Import-Module -Force '.\OtherInfo.psm1'
Import-Module -Force '.\PartInf.psm1'
Import-Module -Force '.\ProceInf.psm1'


Class MainConfig { 
    $configuration;
    $generatedhtml;
 }

<# Retrieve content with basic configuration for reporting operations. #>
Class DirModule : MainConfig {
    $exdirinfo;
}
Class ProgModule : MainConfig {
    $exprograminfo;
}
Class PartModule : MainConfig {
    $expartinfo;
}
Class ProcModule : MainConfig {
    $exprocessinfo;
}

[PSCustomObject[]]$importedInfo = @(
<# Retrieve content for basic directories. #>
[DirModule]@{
configuration        = $Script:DirSize.validateCfg()
exdirinfo            = $Script:DirSize.exportDirInfo()
generatedhtml        = $Script:DirSize.genContentWithTitle()
},
<# Retrieve content for local installs. #>
[ProgModule]@{
configuration        = $Script:OtherInfo.getCfg();
exprograminfo        = $Script:OtherInfo.exportOtherInfo();
generatedhtml        = $Script:OtherInfo.genContentWithTitle();
},
<# Retrieve content of local disk partitions. #>
[PartModule]@{
configuration        = $Script:PartInf.validateCfg();
expartinfo           = $Script:PartInf.exportPartInfo();
generatedhtml        = $Script:PartInf.genContentWithTitle();
},
<# Retrieve content of system processes. #>
[ProcModule]@{
configuration        = $Script:ProceInf.validateCfg();
exprocessinfo        = $Script:ProceInf.exportProceInf();
generatedhtml        = $Script:ProceInf.genContentWithTitle();
}
);

function getDirectorySizes() {
$($importedInfo[0]);
}

function getOtherSizes() {
$($importedInfo[1]);
}

function getPartitionSizes() {
$($importedInfo[2]);
}

function getProcessSizes() {
$($importedInfo[3]);
}

Export-ModuleMember -Function '*'
Export-ModuleMember -Variable '*'