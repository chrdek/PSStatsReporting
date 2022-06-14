$PartInfo = New-Module -ScriptBlock {

$cfgSetup = @();
$cfgMsg   = "Setting up parittion selections..";
$expMsg   = "Exporting partition info..";
$htmlMsg  = "Hard disk partition sizes - (GB)";
$time     =  "[{4}/{5}/{6}, {0}:{1}:{2} - {3} ms]  " -f (Get-Date).Hour,(Get-Date).Minute,(Get-Date).Second,(Get-Date).Millisecond,(Get-Date).Day,(Get-Date).Month,(Get-Date).Year;
$log      =  "";

function validateCfg() {
$this.log = "$($this.time+$this.cfgMsg)"; $this.log | Out-File -FilePath ".\application.log" -Append
$this.cfgSetup += ("Win32_DiskPartition","root/CIMv2");
}

function exportInfo() {
try {
if (Test-Path -Path ".\partition_data.json") {return;}
$this.log = "$($this.time+$this.expMsg)"; $this.log | Out-File -FilePath ".\application.log" -Append
$dpart = (Get-CimInstance -ClassName $this.cfgSetup[0]  -Namespace $this.cfgSetup[1]);

$dpart | Select name, Size, @{name='value';expression={[Math]::Round($_.Size/1GB,4)}},
                            @{name='colorValue';expression={[Math]::Round($_.Size/1GB,4)}},
                            Type | Invoke-Parallel -ScriptBlock {$_} -ThrottleLimit 50 -ProgressActivity "Exporting partitions.." | ConvertTo-Json | Set-Content ".\partition_data.json";
}
catch {
 Write-Error -Message "Error - Cannot get partition from drive. $_" -ErrorVariable 'partitionError' | Out-File -FilePath ".\application.log" -Append
 }
finally {
 $error.Clear();
 }
}

function genContentWithTitle() {
$partsizes = Get-Content -Path ".\partition_data.json";
$chartTitle = [Regex]::Replace((@{title=@{text=$this.htmlMsg}} | ConvertTo-Json),"^(\{)|(\})$","");
Copy-Item -Path ".\index.html" ".\tmpl.html";

$htmlfmt = Get-Content -Path ".\tmpl.html" | %{$_ -replace "%RESULT%", $partsizes -replace "%TITLE%", $chartTitle } 
Set-Content -Value $htmlfmt ".\tmpl.html";
 }
    Export-ModuleMember -Function 'validateCfg'
    Export-ModuleMember -Function 'exportInfo'
    Export-ModuleMember -Function 'genContentWithTitle'

    Export-ModuleMember -Variable 'cfgSetup'
    Export-ModuleMember -Variable 'cfgMsg'
    Export-ModuleMember -Variable 'expMsg'
    Export-ModuleMember -Variable 'htmlMsg'
    Export-ModuleMember -Variable 'time'
    Export-ModuleMember -Variable 'log'
} -AsCustomObject

Export-ModuleMember -Variable 'PartInfo'