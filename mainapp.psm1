<#  
 #  
 #  Main module used for calling other parts of the application.
 #  
 #  Includes utility classes with main functionality for scripts.
 #  
 #>
Import-Module -Force '.\DirSize.psm1'
Import-Module -Force '.\OtherInfo.psm1'
Import-Module -Force '.\PartInfo.psm1'
Import-Module -Force '.\ProceInfo.psm1'


<# Retrieve content for basic directories. #>
Class DirectoryModule {
    $dirconfig
    $exdirinfo
    $dirgenOutput

   DirectoryModule() {

    $this.dirconfig           =      $Global:DirSize.validateCfg();
    $this.exdirinfo           =      $Global:DirSize.exportInfo();
    $this.dirgenOutput        =      $Global:DirSize.genContentWithTitle();

    }
}


<# Retrieve content for local installs. #>
Class ProgramsModule {
    $programconfig
    $exprograminfo
    $programgenOutput

   ProgramsModule() {

    $this.programconfig        =      $Global:OtherInfo.validateCfg();
    $this.exprograminfo        =      $Global:OtherInfo.exportInfo();
    $this.programgenOutput     =      $Global:OtherInfo.genContentWithTitle();

    }

 }


<# Retrieve content of local disk partitions. #>
 Class PartitionModule {
    $partconfig
    $expartinfo
    $partgenOutput

  PartitionModule() {

    $this.partconfig           =      $Global:PartInfo.validateCfg();
    $this.expartinfo           =      $Global:PartInfo.exportInfo();
    $this.partgenOutput        =      $Global:PartInfo.genContentWithTitle();

    }
 
 }


<# Retrieve content of system processes. #>
 Class ProcessModule {
    $processconfig
    $exprocessinfo
    $processgenOutput

 ProcessModule() {

    $this.processconfig        =     $Global:ProceInfo.validateCfg();
    $this.exprocessinfo        =     $Global:ProceInfo.exportInfo();
    $this.processgenOutput     =     $Global:ProceInfo.genContentWithTitle();

   }

 }



function getDirectorySizes() {
  $directSizes = [DirectoryModule]::new();
  $directSizes.dirconfig;
  $directSizes.exdirinfo;
  $directSizes.dirgenOutput;
}

function getOtherSizes() {
  $otherSizes = [ProgramsModule]::new();
  $otherSizes.programconfig;
  $otherSizes.exprograminfo;
  $otherSizes.programgenOutput;
}

function getPartitionSizes() {
  $partSizes = [PartitionModule]::new();
  $partSizes.partconfig;
  $partSizes.expartinfo;
  $partSizes.partgenOutput;
}

function getProcessSizes() {
  $procSizes = [ProcessModule]::new();
  $procSizes.processconfig;
  $procSizes.exprocessinfo;
  $procSizes.processgenOutput;
}

Export-ModuleMember -Function '*'
Export-ModuleMember -Variable '*'