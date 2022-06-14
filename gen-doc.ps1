$content = Select-String -Path (Get-Module mainapp).Path -Pattern @("^(<#){1}|(# )|(#>)","(Class)( )[a-zA-Z\{]","^(function)[ ,a-zA-Z\(\{]");

$classes = $content.Line | ?{ $_ -ilike "*Class *"} | %{$_ -ireplace "{","" -ireplace " ", ""}
$functions = $content.Line | ?{ $_ -ilike "*function *"} | %{$_ -ireplace "{","" -ireplace "\(\)",""}

$comments = $content.Line | ?{ $_ -ilike "*<#*"} | %{$_ -ireplace "<","" -ireplace ">","" -ireplace "#",""}  #| Select  -Last ($($comments).Length) #might need -1
$heading = $content.Line | ?{ $_ -ilike "*# *."} | %{$_ -ireplace "#",""}

$output=""
$heading | %{ $output+= $_+"<br/>" }
$header = "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'>
                <html xmlns='http://www.w3.org/1999/xhtml'><head>
                <h2 style='background-color:#f2f2f2;color:grey;font-size:21px;font-family:SegoeUI;border-radius:11px'>{0}</h2>
                </head>
                <body>
                " -f $output;

<# Main html menu links for classes and functions #>
$linkpart = @(); $doclinks = @(); 
$classes | %{$doclinks += "doc_$($_.Substring(5,10))";}
$classes | %{$linkpart += "<li style='list-style:none'><a href='.\doc_$($_.Substring(5,10)).html'>$($_)</a></li><br/>";}

<# Create htmls per link #>
for ($i=0; $i -lt $comments.Count; $i++) {
$maincontent = "<html><body><h3>{0} - {1}</h3><hr/><br/>Set by {2}</body></html>" -f $doclinks[$i], $comments[$i], $functions[$i];
  $maincontent | Set-Content ".\$($doclinks[$i]).html";
}

<# Generate additional html content for other modules #>
$modutitle = @(""); $moducont = @("");
$utilmodules = ((Get-ChildItem -Path "." -Filter "*Util.psm1").Name -replace ".psm1","");
 ($utilmodules | %{$modutitle += "<h3>{0}</h3>" -f $_; Get-Module $_}).ExportedCommands |
                                        Select Keys -ExpandProperty Keys | 
                                         %{$moducont += "<li style='list-style:none'>{0}</li></br>" -f $_};

    $modulfns = @($modutitle[1],($moducont | ?{$_ -ilike "*Az*" -or $_ -ilike "*Fn*"}), 
                  $modutitle[2],($moducont | ?{$_ -ilike "*Convert*" -or $_ -ilike "*Image*"}),
                  $modutitle[3],($moducont | ?{$_ -ilike "*AWS*" -or $_ -ilike "*S3*"}));
    $modulfns | %{$resmodules += $_ }

@($header,$linkpart,("<br/><br/><p><strong>Some additional functions that can be used are found in the modules shown below:</strong></p>{0}</body></html>" -f $resmodules)) | Set-Content -Path ".\main-doc.html"

<# CHM Section.. #>
$idxheader = @('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">','<meta name="GENERATOR" content="Index for Documentation">')
$mainidxcontent = @"
{0}
<html>
<head>
{1}
</head><body><UL>
"@ -replace "\{0\}", $idxheader[0] -replace "\{1\}", $idxheader[1];

$idxtmpl = @'
<LI> <OBJECT type="text/sitemap">
     <param name="Name" value="{0}">
     <param name="Name" value="{0} .\{0}.html">
     <param name="Local" value="{0}.html">
     </OBJECT>
'@;
 $doclinks | %{$mainidxcontent += [System.Environment]::NewLine+($idxtmpl -replace "\{0\}", $_)}
 $mainidxcontent += [System.Environment]::NewLine+"</UL></body></html>";
 $mainidxcontent | Set-Content ".\Index.hhk";
$proj = @"
[OPTIONS]
Compatibility=1.1 or later
Compiled file=main-doc.chm
Default topic=main-doc.html
Display compile progress=No
Index file=Index.hhk
Language=0x409 English (United States)
Title=Main Functionality Documentation (Generated CHM Document)


[FILES]
"@;
$proj | Set-Content ".\main-doc.hhp"
$doclinks | %{ "$($_).html" | Add-Content ".\main-doc.hhp"}
"main-doc.html" | Add-Content ".\main-doc.hhp"

Start-Process "${env:ProgramFiles(x86)}\HTML Help Workshop\hhc.exe" -ArgumentList @(".\main-doc.hhp");
Start-Sleep 5; Start-Process ".\main-doc.chm"