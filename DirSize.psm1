$DirSize = New-Module -ScriptBlock {

$dirs =      @($env:TEMP,
              "$env:LOCALAPPDATA\Packages",
              "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
              "$env:USERPROFILE\Downloads",
              "$env:USERPROFILE\Pictures",
              "$env:USERPROFILE\Music",
              "$env:USERPROFILE\Desktop",
              "$env:USERPROFILE\Videos");

$cfgSetup =  @();
$cfgMsg   =  "Setting/validating directories..";
$expMsg   =  "Exporting data..";
$htmlMsg  =  "Folders and directory sizes - (GB)";
$time     =  "[{4}/{5}/{6}, {0}:{1}:{2} - {3} ms] " -f (Get-Date).Hour,(Get-Date).Minute,(Get-Date).Second,(Get-Date).Millisecond,(Get-Date).Day,(Get-Date).Month,(Get-Date).Year;
$log      =  "";

function validateCfg() {
$this.log = "$($this.time+$this.cfgMsg)"; $this.log | Out-File -FilePath ".\application.log" -Append
$this.dirs | %{ $this.cfgSetup += (Test-Path -Path $_) -and ((Get-Item $_) | Get-ChildItem -Recurse -File | Select -First 5).Count -ne 0 }
}

function exportInfo() {
try {
if (Test-Path -Path ".\dir_data.json") {return;}
$this.log = "$($this.time+$this.expMsg)"; $this.log | Out-File -FilePath ".\application.log" -Append
$output = @();
$emptydata = @{name="";value=$null;colorValue=$null};
$k = 0;

$this.dirs | %{

$dirName = (Split-Path -Path $_ -Leaf);
 if ($this.cfgSetup[$k]) {
 $output += $_ | Get-ChildItem -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Sum Length -ErrorAction SilentlyContinue | Select temp, @{name='name';expression={$($dirName)}},
                                                                                                                              @{name='value';expression={[Math]::Round($_.Sum/1GB,4)}},
                                                                                                                              @{name='colorValue';expression={[Math]::Round($_.Sum/1GB,4)}} | Invoke-Parallel -ScriptBlock {$_} -ThrottleLimit 50 -ProgressActivity "Exporting Directories.."
  } else {$output += $emptydata; }
 $k++;
 }
 ($output | ConvertTo-Json) | Set-Content ".\dir_data.json"
}
catch {
 Write-Error -Message "Error - Cannot retrieve directories $_" -ErrorVariable 'dirError' | Out-File -FilePath ".\application.log" -Append
 }
finally {
 $error.Clear();
 }
}

function genContentWithTitle() {
$dirsizes = Get-Content -Path ".\dir_data.json";
$chartTitle = [Regex]::Replace((@{title=@{text=$this.htmlMsg}} | ConvertTo-Json),"^(\{)|(\})$","");
Copy-Item -Path ".\index.html" ".\tmpl.html";

$htmlfmt = Get-Content -Path ".\tmpl.html" | %{$_ -replace "%RESULT%", $dirsizes -replace "%TITLE%", $chartTitle } 
Set-Content -Value $htmlfmt ".\tmpl.html";
 }
    Export-ModuleMember -Function 'validateCfg'
    Export-ModuleMember -Function 'exportInfo'
    Export-ModuleMember -Function 'genContentWithTitle'
    
    Export-ModuleMember -Variable 'dirs'
    Export-ModuleMember -Variable 'cfgSetup'
    Export-ModuleMember -Variable 'cfgMsg'
    Export-ModuleMember -Variable 'expMsg'
    Export-ModuleMember -Variable 'htmlMsg'
    Export-ModuleMember -Variable 'time'
    Export-ModuleMember -Variable 'log'
    } -AsCustomObject

Export-ModuleMember -Variable 'DirSize'