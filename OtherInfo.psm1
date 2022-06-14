$OtherInfo = New-Module -ScriptBlock {

$cfgSetup = @();
$cfgMsg   = "Setting up config for retrieving installations..";
$expMsg   = "Exporting local installs..";
$htmlMsg  = "Program installations sizes - (MB)";
$time     =  "[{4}/{5}/{6}, {0}:{1}:{2} - {3} ms]  " -f (Get-Date).Hour,(Get-Date).Minute,(Get-Date).Second,(Get-Date).Millisecond,(Get-Date).Day,(Get-Date).Month,(Get-Date).Year;
$log      =  "";

function validateCfg() {
$this.log = "$($this.time+$this.cfgMsg)"; $this.log | Out-File -FilePath ".\application.log" -Append
$this.cfgSetup +=  ("HKLM:\software\Microsoft\windows\CurrentVersion\Uninstall\*","DisplayName","estimatedsize","Publisher");
}

function exportInfo() {
try {
if (Test-Path -Path ".\programs_data.json") {return;}
$this.log = "$($this.time+$this.expMsg)"; $this.log | Out-File -FilePath ".\application.log" -Append
Get-ItemProperty  $this.cfgSetup[0] | Select $this.cfgSetup[1],$this.cfgSetup[2],$this.cfgSetup[3], @{name='name';expression={$_.DisplayName}}, 
                                                                                                    @{name='value';expression={[Math]::Round($_.estimatedsize/1KB,4)}},
                                                                                                    @{name='colorValue';expression={[Math]::Round($_.estimatedsize/1KB,4)}} | Invoke-Parallel -ScriptBlock {$_} -ThrottleLimit 50 -ProgressActivity "Exporting Programs.." | ConvertTo-Json | Set-Content ".\programs_data.json"
}
catch {
 Write-Error -Message "Error - Cannot retrieve software installs. $_" -ErrorVariable 'otherError' | Out-File -FilePath ".\application.log" -Append
 }
finally {
 $error.Clear();
 }
}

function genContentWithTitle() {
$programsizes = Get-Content -Path ".\programs_data.json";
$chartTitle = [Regex]::Replace((@{title=@{text=$this.htmlMsg}} | ConvertTo-Json),"^(\{)|(\})$","");
Copy-Item -Path ".\index.html" ".\tmpl.html";

$htmlfmt = Get-Content -Path ".\tmpl.html" | %{$_ -replace "%RESULT%", $programsizes -replace "%TITLE%", $chartTitle } 
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

Export-ModuleMember -Variable 'OtherInfo'