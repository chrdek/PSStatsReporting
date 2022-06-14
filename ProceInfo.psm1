$ProceInfo = New-Module -ScriptBlock {

$cfgSetup = @();
$cfgMsg   = "Setting up process values..";
$expMsg   = "Retrieving system processes information...";
$htmlMsg  = "Microsoft system processes sizes > 20MB";
$time     =  "[{4}/{5}/{6}, {0}:{1}:{2} - {3} ms]  " -f (Get-Date).Hour,(Get-Date).Minute,(Get-Date).Second,(Get-Date).Millisecond,(Get-Date).Day,(Get-Date).Month,(Get-Date).Year;
$log      =  "";

function validateCfg() {
$this.log = "$($this.time+$this.cfgMsg)"; $this.log | Out-File -FilePath ".\application.log" -Append
$this.cfgSetup += (20.500,"**");
}

function exportInfo() {
try {
if (Test-Path -Path ".\process_data.json") {return;}
$this.log = "$($this.time+$this.expMsg)"; $this.log | Out-File -FilePath ".\application.log" -Append
Get-Process -ErrorAction SilentlyContinue | Where {[Math]::Round($_.WorkingSet/1MB,4) -gt $this.cfgSetup[0] -and $_.Name -ilike $this.cfgSetup[1]} -ErrorAction SilentlyContinue | Select ProcessName,WorkingSet,Id, @{name='name';expression={$_.ProcessName}},
                                                                                                                                                                                                                     @{name='value';expression={[Math]::Round($_.WorkingSet/1MB,4)}},
                                                                                                                                                                                                                     @{name='colorValue';expression={[Math]::Round($_.WorkingSet/1MB,4)}} | Invoke-Parallel -ScriptBlock {$_} -ThrottleLimit 50 -ProgressActivity "Exporting processes.." | ConvertTo-Json | Set-Content ".\process_data.json";
}
catch {
 Write-Error -Message "Error - Cannot retrieve system processes. $_" -ErrorVariable 'processError' | Out-File -FilePath ".\application.log" -Append
 }
finally{
 $error.Clear();
 }
}

function genContentWithTitle() {
$processizes = Get-Content -Path ".\process_data.json";
$chartTitle = [Regex]::Replace((@{title=@{text=$this.htmlMsg}} | ConvertTo-Json),"^(\{)|(\})$","");
Copy-Item -Path ".\index.html" ".\tmpl.html";

$htmlfmt = Get-Content -Path ".\tmpl.html" | %{$_ -replace "%RESULT%", $processizes -replace "%TITLE%", $chartTitle }
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

Export-ModuleMember -Variable 'ProceInfo'