﻿ # 
 # 
 #     Toolkit of image validation and image generation functions in powershell.
 #     Includes: input to grayscale imaging, brightness image checks, QR code creation and other features.
 # 
 # 
<#
.Synopsis
    Convert an input file name to an MD5 hash.

.Description
    Retrieve the counterpart hashed value based on specified input image name. Set to exclude file name extension.

.Parameter imgInput
    Input name of image.
#>
Function Convert-NameToMD5 {
[CmdLetBinding()]
param(
[Parameter(ValueFromPipeLine=$true)]
[string]$imgInput
)
Process {
$imgInput = $imgInput -ireplace "(\.){1}[a-zA-Z0-9].+","";
$str = ([String]::new($imgInput) -replace "=","" -replace "\*","" -replace "_","").ToString();
$out="";
$strd = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([String]::new($str).ToString().ToCharArray()));
$trimstrd = $strd -replace "=", "";

[System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($trimstrd.ToCharArray())) | %{
 $out += $_.ToString("x2").ToUpper()
 }
}
End {
 return $out;
 }
}


<#
.Synopsis
    Return the file size of an image in KB.

.Description
    Retrieve file size of specified input image, either as formatted text label or decimal.

.Parameter pathToImgInput
    Directory of the input image.

.Parameter toLabel
    Switch option to return a text label with byte size.
#>
Function Get-ImageSize {
[CmdLetBinding()]
param(
[Parameter(ValueFromPipeLine=$true)]
[string]$pathToImgInput,
[switch]$toLabel
)
if ($pathToImgInput.StartsWith(".\")) {$pathToImgInput = Resolve-Path $("$($pathToImgInput)")}
 if ($toLabel) {
   return ("$((Get-Content $pathToImgInput -Encoding Byte -ErrorAction SilentlyContinue).Length / 1KB)".Substring(0,4)+"KB");
  }
 return [Math]::Round((Get-ItemPropertyValue -Path $pathToImgInput -Name Length | %{$_/1KB}),2);
}


<#
.Synopsis
    Random pixel retrieval from image.

.Description
    Function used for retrieving pixel from random places from an image.

.Parameter imgrnd
    Input image path.

.Parameter filterzero
    Switch option, filter out zero pixels from return object.

.Parameter pixnum
    Number of random ARGB pixel values to return.
#>
Function Get-ImagePxRnd {
param(
[string]$imgrnd,
[switch]$filterzero,
[int]$pixnum=5
)
$dll = (Get-Command "System.Drawing.dll").Definition;
[System.Reflection.Assembly]::LoadFrom($dll) | Out-Null;
$mainImg = [System.Drawing.Image]::FromFile($(Resolve-Path -Path $imgrnd));

$pxsOut = @();
 for($p=0; $p -lt $pixnum; $p++) {
    $Xpxl = (Get-Random -Maximum $mainImg.Size.Width -Minimum 0);
    $Ypxl = (Get-Random -Maximum $mainImg.Size.Height -Minimum 0);
    $Imgpxs = "$($Xpxl),$($YPxl)";

    if (-not $filterzero) {
    [PSCustomObject[]]$pxsOut += @(@{Initpxs=$Imgpxs; pxls=($mainImg.GetPixel($Xpxl, $Ypxl) | Select R,G,B,A)});
     } else {
    [PSCustomObject[]]$pxsOut += @(@{Initpxs=$Imgpxs; pxls=($mainImg.GetPixel($Xpxl, $Ypxl) | Select R,G,B,A | Where-Object {$_.R -or $_.G -or $_.B -or $_.A})});
    }
 }
 return $pxsOut;
}


<#
.Synopsis
    Random pixel RGB values verification.

.Description
    Function used to compare random RGB values from an initial image to the target image's pixels. Returns true/false per pixel comparison operation.

.Parameter pxlsInput
    Object that holds the initial image's random pixels.

.Parameter baseimagepath
    The target image to validate the initial image pixels against.
#>
Function Resolve-RndPx {
[CmdLetBinding()]
param(
[PSCustomObject]$pxlsInput,
[string]$baseimagepath
)

$baseasm = (Get-Command "System.Drawing.dll").Definition;
[System.Reflection.Assembly]::LoadFrom($baseasm) | Out-Null;
$mainImg = [System.Drawing.Image]::FromFile($(Resolve-Path -Path $baseimagepath));

$pxlvect=$true;
 for ($h=0; $h -lt $pxlsInput.Count; $h++) {
    $pxlvect = $pxlvect -and (($pxlsInput[$h].pxls.R -bxor $mainImg.GetPixel(($pxlsInput[$h].Initpxs).Split(',')[0],($pxlsInput[$h].Initpxs).Split(',')[1]).R -eq 0) -as [bool]);
    $pxlvect = $pxlvect -and (($pxlsInput[$h].pxls.G -bxor $mainImg.GetPixel(($pxlsInput[$h].Initpxs).Split(',')[0],($pxlsInput[$h].Initpxs).Split(',')[1]).G -eq 0) -as [bool]);
    $pxlvect = $pxlvect -and (($pxlsInput[$h].pxls.B -bxor $mainImg.GetPixel(($pxlsInput[$h].Initpxs).Split(',')[0],($pxlsInput[$h].Initpxs).Split(',')[1]).B -eq 0) -as [bool]);
    $pxlvect = $pxlvect -and (($pxlsInput[$h].pxls.A -bxor $mainImg.GetPixel(($pxlsInput[$h].Initpxs).Split(',')[0],($pxlsInput[$h].Initpxs).Split(',')[1]).A -eq 0) -as [bool]);
   }
 $imgpartOK = $false;
 if (-not $pxlvect) {
 Write-Host "`r`n Some or all pixels don't match initial image";
 } else { $imgpartOK = $true; }
 return $imgpartOK;
}


<#
.Synopsis
    Retrieve a byte hash based on an image's selection area.

.Description
    Select a partial or full area of image bytes and generate a hash.

.Parameter imagepath
    Image input path for exporting the hashed bytes.

.Parameter arealimit
    Used to determine the extent of the hashed bytes area.

.Parameter setfullarea
    Switch, retrieves the full set of bytes for hashing.
#>
Function Get-ImagePxAreaHash {
param(
[Parameter(Mandatory=$true)]
[string]$imagepath,
[Parameter(Mandatory=$true)]
[int]$arealimit,
[Parameter(Mandatory=$false)]
[switch]$setfullarea
)

[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null;
$mainImg = [System.Drawing.Image]::FromFile($(Resolve-Path -Path $imagepath));

if (-not $setfullarea) {
 $diff = ($mainImg.Size.Height - $mainImg.Size.Width);
 $isrect = (($diff -lt 0) -or ($diff -gt 0));

if ($isrect) {
 $offset = [Math]::Round([Math]::Abs($diff) / $arealimit);
  } else {
 $offset = [Math]::Round($diff / $arealimit);
}

$outarray=@(); $k=0;
for($f=0; $f -lt $mainImg.Size.Height - $offset; $f++) {
 
 $mainImg | %{
 if ($k -ge $mainImg.Size.Width - $offset) {break;}
$outarray += @($($_.GetPixel($f, $k).R,$_.GetPixel($f, $k).G,$_.GetPixel($f, $k).B,$_.GetPixel($f, $k).A);$k++);
  }
}

$bytehash="";
[System.Security.Cryptography.MD5]::Create().ComputeHash($outarray) | %{
$bytehash +=$_.ToString("x2").ToUpper()
 }
 return $bytehash;
} else {
   rm -Path ".\base_10.bin" -ErrorAction SilentlyContinue
   Get-Content -Path $imagepath -Encoding Byte | Set-Content ".\base_10.bin";
   return (Get-FileHash -Path ".\base_10.bin").Hash
 }
}


<#
.Synopsis
    Retrieve metadata about an image file.

.Description
    Return an extended metadata object from an image file or standard file information.

.Parameter pathImg
    Input image to retrieve the metadata from.

.Parameter getextended
    Switch option, return object with extended metadata.
#>
Function Get-ImageMetadata {
 param(
 [Parameter(Mandatory=$true)]
 [string]$pathImg,
 [switch]$getextended
 )

$extension = (Split-Path -Path $pathImg -Leaf).Split('.')[1];
if ($extension -iin @("png","jpg","jpeg","img","ico","bmp")) {
 if ($getextended -eq $true) {

 $xtProperties = [PSCustomObject[]]@(@{
 Extattribs=[System.IO.File]::GetAttributes($pathImg);
 Extaccess=[System.IO.File]::GetAccessControl($pathImg) | Select Path, Owner, Group, Access, Sddl, AccessToString, AreAccessRulesProtected, AreAuditRulesProtected, AreAccessRulesCanonical, AreAuditRulesCanonical;
 Extauthorization=[System.IO.File]::GetAccessControl($pathImg).Access | Select *;
 Extcreationtime=[System.IO.File]::GetCreationTime($pathImg);
 Extcreationutc=[System.IO.File]::GetCreationTimeUtc($pathImg);
 Extlastwritetime=[System.IO.File]::GetLastWriteTime($pathImg);
 Extlastwriteutc=[System.IO.File]::GetLastWriteTimeUtc($pathImg);
 Extlastaccessutc=[System.IO.File]::GetLastAccessTimeUtc($pathImg);
 Extlastaccesstime=[System.IO.File]::GetLastAccessTime($pathImg);
 Extaccessidentity=[System.IO.File]::GetAccessControl($pathImg).Access.IdentityReference;
 });
 return $xtProperties;
 } else {
    return $(Get-ItemPropertyValue -Path $pathImg -Name Attributes,
    Name,
    Mode,
    Exists,
    LinkType,
    BaseName,
    LastWriteTime,
    LastAccessTime,
    CreationTime,
    Length -ErrorAction SilentlyContinue);
    }
  }
}


<#
.Synopsis
    Set one or more metadata info on an image.

.Description
    Function used for adding common or extended metadata on an image file. Supports multiple file types.

.Parameter pathInput
    File image path for metadata mod.

.Parameter setdata
    Setting for one ore more boolean file properties.

.Parameter setattribs
    Setting for multiple file attributes.

.Parameter num
    Selection order for specified metadata/attribute to change.

.Parameter setextdata
    Switch, set plain or extended metadata on image.
#>
Function Set-ImageMetadata {
 param (
 [Parameter(Mandatory=$true)]
 [string]$pathInput,
 [Parameter(Mandatory=$false)]
 [bool[]]$setdata,
 [Parameter(Mandatory=$false)]
 [string[]]$setattribs,
 [Parameter(Mandatory=$false)]
 [int]$num,
 [switch]$setextdata
 )

$extension = (Split-Path -Path $pathInput -Leaf).Split('.')[1];
if ($extension -iin @("png","jpg","jpeg","img","ico","bmp")) {
 if ($setextdata) {
 $attribs = @(
 [System.IO.FileAttributes]::Archive,
 [System.IO.FileAttributes]::Compressed,
 [System.IO.FileAttributes]::Device,
 [System.IO.FileAttributes]::Directory,
 [System.IO.FileAttributes]::Encrypted,
 [System.IO.FileAttributes]::Hidden,
 [System.IO.FileAttributes]::IntegrityStream,
 [System.IO.FileAttributes]::Normal,
 [System.IO.FileAttributes]::NoScrubData,
 [System.IO.FileAttributes]::NotContentIndexed,
 [System.IO.FileAttributes]::Offline,
 [System.IO.FileAttributes]::ReadOnly,
 [System.IO.FileAttributes]::ReparsePoint,
 [System.IO.FileAttributes]::SparseFile,
 [System.IO.FileAttributes]::System,
 [System.IO.FileAttributes]::Temporary
 );

 $ymd = $setattribs | Where-Object { $_ -ilike "*,*,*" }; $ymds += $ymd | %{$_.Split(",")};
 $dtcheck= (Get-Variable ym* -ErrorAction Continue).Value;
 
 if (-not $dtcheck -as [bool]) {
 $ymds = [System.DateTime]::Today.ToString("O").Split('-').Split('T') | Select -First 3;
 }
 [System.IO.File]::SetAttributes($pathInput,$attribs[$num -as [Int]]);

 Trap {
 [System.IO.File]::SetAccessControl($pathInput,[System.Security.AccessControl.FileSecurity]::new($pathInput,[System.Security.AccessControl.AccessControlActions]::Change));
 [System.IO.File]::SetAccessControl($pathInput,[System.Security.AccessControl.FileSecurity]::new($pathInput,[System.Security.AccessControl.AccessControlActions]::None));
 [System.IO.File]::SetAccessControl($pathInput,[System.Security.AccessControl.FileSecurity]::new($pathInput,[System.Security.AccessControl.AccessControlActions]::View));
 }

 [System.IO.File]::SetCreationTime($pathInput,[System.DateTime]::new([Int]::Parse($ymds[0]),[Int]::Parse($ymds[1]),[Int]::Parse($ymds[2])));
 [System.IO.File]::SetLastAccessTime($pathInput,[System.DateTime]::new([Int]::Parse($ymds[3]),[Int]::Parse($ymds[4]),[Int]::Parse($ymds[5])));
 [System.IO.File]::SetLastWriteTime($pathInput,[System.DateTime]::new([Int]::Parse($ymds[6]),[Int]::Parse($ymds[7]),[Int]::Parse($ymds[8])));
  } else {
  $num = $null;
  $yymmdd = $setattribs | Where-Object { $_ -ilike "*,*,*" }; $yymmdds += $yymmdd | %{$_.Split(",")};

 Set-ItemProperty -Path $pathInput -Name IsReadOnly -Value $setdata[0] -ErrorAction SilentlyContinue;

 Set-ItemProperty -Path $pathInput -Name Attributes -Value $setattribs[0] -ErrorAction SilentlyContinue;
 Set-ItemProperty -Path $pathInput -Name Attributes -Value $setattribs[1] -ErrorAction SilentlyContinue;
 Set-ItemProperty -Path $pathInput -Name CreationTime -Value $([System.DateTime]::new([Int]::Parse($yymmdds[0]),[Int]::Parse($yymmdds[1]),[Int]::Parse($yymmdds[2]) )) -ErrorAction SilentlyContinue;
 Set-ItemProperty -Path $pathInput -Name LastWriteTime -Value $([System.DateTime]::new([Int]::Parse($yymmdds[3]),[Int]::Parse($yymmdds[4]),[Int]::Parse($yymmdds[5]) )) -ErrorAction SilentlyContinue;
 Set-ItemProperty -Path $pathInput -Name LastAccessTime -Value $([System.DateTime]::new([Int]::Parse($yymmdds[6]),[Int]::Parse($yymmdds[7]),[Int]::Parse($yymmdds[8]) )) -ErrorAction SilentlyContinue;
  }
 }
}


<#
.Synopsis
    Convert a hexadecimal color to ARGB.

.Description
    Takes an hexadecimal color string in the form of "ffffffff" and exports a hashtable with A,R,G,B components.

.Parameter colorinput
    The hex color value to be converted to ARGB.
#>
Function ConvertFrom-ColorHexARGB {
[CmdLetBinding()]
 param(
 [Parameter(ValueFromPipeLine=$true)]
 [string]
 $colorinput
 )
 Process {
     $hexmap = New-Object System.Collections.Hashtable;
     $argbmap = New-Object System.Collections.Hashtable;
     $val = @(0,1,2,3,4,5,6,7,8,9,'a','b','c','d','e','f'); $hexoffset=0;
     $colval = @('A','R','G','B');
     $val | %{
     $hexmap.Add($_, $hexoffset);
     $hexoffset++;
     }
     
$hexv = @();
    for ($u=0; $u -lt $colorinput.Length; $u++) {
      if ($u % 2 -eq 0 -or $u -eq 0) {
          if ($u -ge 7) {break;}
       $hexv += $colorinput.Substring($u,2);
  }
}
     $rgbvals = @();
     $hexv | %{
     $lpart =  $_.Substring(0,1);
     $rpart =  $_.Substring(1,1);

     if ($lpart -as [Int] -eq $null -and ($lpart -in @('a','b','c','d','e','f'))) {
      $lpart = $hexmap["${lpart}"];
     } else { $lpart = $lpart -as [Int]; }
     if ($rpart -as [Int] -eq $null -and ($rpart -in @('a','b','c','d','e','f'))) {
      $rpart = $hexmap["${rpart}"];
     } else { $rpart = $rpart -as [Int]; }
     
     $rgbvals += $lpart * 16 + 
                 $rpart * 1;
   }
  }
   End {
   $c=0;
   $rgbvals | %{ $argbmap.Add($_,$colval[$c]); $c++ }
    return $argbmap;
    }
}


<#
.Synopsis
    Retrieve the greyscale values per rgb integer input.

.Description
    Function used to return the rgb integer values converted to grey color as bytes.

.Parameter red
    Byte representing red pixel value.

.Parameter green
    Byte representing green pixel value.

.Parameter blue
    Byte representing blue pixel value.
#>
Function Get-GreyValue {
param
(
[Parameter(Mandatory=$true)]
[Byte]$red,
[Parameter(Mandatory=$true)]
[Byte]$green,
[Parameter(Mandatory=$true)]
[Byte]$blue
)
$val=4;
[Double]$expval = [Math]::Sqrt($val)+.2;

[Double[]]$colfact = @((( (0.053 -as [Double]) * $val) *[Math]::Pow($red, $expval)),
          (( (0.1788 -as [Double]) * $val) *[Math]::Pow($green, $expval)),
          (( (0.1805 -as [Double]) * $val) *[Math]::Pow($blue, $expval)));
[Double]$grey = [Math]::Pow($colfact[0] + $colfact[1] + $colfact[2], 1 / $expval);
return [Math]::Max(0, [Math]::Round($grey,[MidpointRounding]::AwayFromZero)) -as [Byte];
}


<#
.Synopsis
    Retrieve the greyscale version of an input image.

.Description
    Converts an initial Image object to its greyscale counterpart. Returns a bitmap image.

.Parameter img
    Input image object used in the conversion.

.Parameter w
    Integer, width of the initial image.

.Parameter h
    Integer, height of initial image.
#>
Function Get-GreyScale {
param
(
[Parameter(Mandatory=$true)]
[System.Drawing.Image]$img,
[Parameter(Mandatory=$true)]
[int]$w,
[Parameter(Mandatory=$true)]
[int]$h
)
[System.Drawing.Bitmap]$finalbmp = [System.Drawing.Bitmap]::new($img, $w, $h);
[System.Drawing.Imaging.BitmapData]$sourceData = $finalbmp.LockBits([System.Drawing.Rectangle]::new(0, 0, $finalbmp.Width, $finalbmp.Height),[System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb);

[int]$stride = $sourceData.Stride;
[Byte[]]$data = [Byte[]]::new($stride * $finalbmp.Height);

[System.Runtime.InteropServices.Marshal]::Copy($sourceData.Scan0, $data, 0, $data.Length);

for ($y=0; $y -lt $h; $y++) {
  [int]$offset = $y * $stride;
  for ($x=0; $x -lt $w; $x++) {
	[Byte]$colB = $data[$offset + 0];
	[Byte]$colG = $data[$offset + 1];
	[Byte]$colR = $data[$offset + 2];
	[int]$colA = $data[$offset + 3];

	if ($colA -lt 128) { [Byte]$grayValue = 0 } else {
		[Byte]$grayValue = (Get-GreyValue -red $colR -green $colG -blue $colB);
         }
	$data[$offset + 0] = $grayValue; # Blue color
	$data[$offset + 1] = $grayValue; # Green color
	$data[$offset + 2] = $grayValue; # Red color
	$data[$offset + 3] = 0xFF;       # Alpha channel
	$offset += 4;
   }
 }
[System.Runtime.InteropServices.Marshal]::Copy($data, 0, $sourceData.Scan0, $data.Length);
$finalbmp.UnlockBits($sourceData);

return $finalbmp -as [System.Drawing.Bitmap];
}


<#
.Synopsis
    Resize an image based on a scale value.

.Description
    Function that changes the size of input image according to a specific scaling. Outputs a smaller version of the initial bitmap.
    
.Parameter imgRes
    Image object as input for resizing.

.Parameter scalefact
    Scale factor by which to resize the image input.
#>
Function Get-ImageScaledSize {
[CmdLetBinding()]
param (
[Parameter(ValueFromPipeLine=$true)]
[System.Drawing.Image]$imgRes,
[Parameter(Mandatory=$true)]
[Int]$scalefact
 )

 Process{
 if ($scalefact -notin @(2,3,4,5,6,7,8,9,10,20,50,100)) {$scalefact = 1;}
 [int]$resWidth = $imgRes.Width/$scalefact; [int]$resHeight = $imgRes.Height/$scalefact;
 $size = [System.Drawing.Size]::new($resWidth,$resHeight);
 $resizedImg = [System.Drawing.Bitmap]::new($imgRes,$size);
 } End { return $resizedImg; }
}


<#
.Synopsis
    Convert from an input image to histogram values array.

.Description
    Function used for converting image rgb to brightness histogram. Returns an array of decimal values.

.Parameter imgDirInput
    Initial image used in the conversion.

.Parameter toJson
    Switch option 1, output histogram in Json format.

.Parameter resize
    Switch option 2, initial input image is resized to reduce processing time.

.Parameter modValues
    Switch option 3, make numeric adjustments on decimal output values.
#>
Function ConvertTo-Histogram {
param (
[Parameter(Mandatory=$true)]
[string]$imgDirInput,
[Parameter(Mandatory=$false)]
[switch]$toJson,
[Parameter(Mandatory=$false)]
[switch]$resize,
[Parameter(Mandatory=$false)]
[switch]$modValues
)

 $hsgImg= [System.Drawing.Image]::FromFile("$($imgDirInput)");
 if ($resize) { $hsgImg = ($hsgImg | Get-ImageScaledSize -scalefact 2) -as [System.Drawing.Image]; }
 
 $i=0;$lum=@();
 (0..($hsgImg.Width-1 -as [Int])) | %{
   (0..($hsgImg.Height-1 -as [Int])) | %{
 $lum += ($hsgImg.GetPixel(($i),($_))).GetBrightness();
  }
  $i++;
 }

 $mean=@(); $k=0;
 $lum |  %{
 $val = ($val + $_);
if (($k % $hsgImg.Height) -eq 0) {
 $mean += $($val/$hsgImg.Height);
 $val=0;
 }
 $k++;
}

$meanModif = @();
if ($modValues) {
 $limit = [Math]::Ceiling(("($mean[0])".Split('.')[1]).Length/2); # Base value for setting trailing digits.
 $peakval = [Math]::Pow(10,[Math]::Floor($limit/2))*.01;          # Normalize digits for 1Ks ranges.

 $meanModif = ($mean | %{ [Math]::Round(($_*($peakval) -as [decimal]),($limit))});

 if ($toJson) {
  return ($meanModif | ConvertTo-Json -Depth 1);
 } else {
  return $meanModif;
 }
}
else { 
if ($toJson) {
 return ($mean | ConvertTo-Json -Depth 1);
} else {
return $mean;
  }
 }
}


<#
.Synopsis
    Used for validating brightness info on an image histogram.

.Description
    Takes as input a grayscale version of the initial image, modifies it with specific code and returns true/false accordingly.

.Parameter imgIn
    Input directory of the image to be validated.

.Parameter HSGMain
    Image histogram data comparison array.

.Parameter stampimage
    Switch option used for adding relevant control lines.
#>
Function Resolve-HistogramData {
 param(
 [Parameter(Mandatory=$true)]
 [string]$imgIn,
 [Parameter(Mandatory=$false)]
 [array]$HSGMain,
 [Parameter(Mandatory=$false)]
 [switch]$stampimage
 )
 
 $inputfilename = $((Split-Path $imgIn -Leaf).Split('.')[0]);
 $ext = $(Split-Path $imgIn -Leaf).Split('.')[1];

 $imagePath = $((Resolve-Path "$imgIn").Path).TrimEnd("$($inputfilename).$($ext)");
 
 $stream = [System.IO.FileStream]::new((Resolve-Path "$imgIn").Path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read) -as [System.IO.Stream];
 [System.Drawing.Image]$procImg = [System.Drawing.Image]::FromStream($stream);
 [System.Drawing.Bitmap]$outgrayscale = [System.Drawing.Bitmap]::new($procImg);
 
if ($stampimage) {
 # Additional control lines for validation.
 [System.Drawing.Graphics]$modImage = [System.Drawing.Graphics]::FromImage($outgrayscale);
 $midsect = ($procImg.Width/2);
 $offsetl = ($midsect)-25; $offsetr = ($midsect)+25;

 $penmiddle = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 15.0);
 $penlr = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 4.0);

 $modImage.DrawLine($penlr, ($offsetl -as [Int]),0,($offsetl -as [Int]),($procImg.Height -as [Int]));
 $modImage.DrawLine($penmiddle, ($midsect -as [Int]),0,($midsect -as [Int]),($procImg.Height -as [Int]));
 $modImage.DrawLine($penlr, ($offsetr -as [Int]),0,($offsetr -as [Int]),($procImg.Height -as [Int]));
 
if (-not (Test-Path "$($imagePath)$($inputfilename)_lines.$($ext)")) {
 $outgrayscale.Save("$($imagePath)$($inputfilename)_lines.$($ext)",$procImg.RawFormat);
}
 $outgrayscale.Dispose();
 $procImg.Dispose();
 $stream.Close();
 # Image preprocessing end.
 return $false;
} else {
  $hsgOut = (ConvertTo-Histogram -imgDirInput "$($imagePath)$($inputfilename)_lines.$($ext)" -resize);

  $b=0;
  return ($hsgOut | %{( ($_ -as [decimal]) -eq ($HSGMain[$b] -as [decimal]) );$b++} -ErrorAction SilentlyContinue) -notcontains $false;
  }
}


<#
.Synopsis
    Create your signature on the image.

.Description
    Used for adding watermark text in the center of the input image. Positioning is modified accordingly.

.Parameter image
    Input image for watermarking.

.Parameter signStr
    Text used as the signature.

.Parameter defaultoffset
    Starting point -from middle point of the image- to add the text.

.Parameter fntsize
    The text's font size.

.Parameter ovr
    Switch - Overwrite current image or create a new copy.
#>
Function Add-ImageWaterMark {
[CmdLetBinding()]
param (
[Parameter(ValueFromPipeLine=$true)]
[string]$image,
[Parameter(Mandatory=$true)]
[string]$signStr,
[Parameter(Mandatory=$false)]
[int]$defaultoffset,
[Parameter(Mandatory=$false)]
[decimal]$fntsize,
[switch]$ovr
)
Process {
$defaultoffset = $defaultoffset -as [int];$fntsize = $fntsize -as [decimal];
$copy = 169 -as [char];
$imageStream = [System.IO.FileStream]::new((Resolve-Path "$image").Path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read) -as [System.IO.Stream];
 [System.Drawing.Image]$imgWater = [System.Drawing.Image]::FromStream($imageStream);

 $bitmapOut = [System.Drawing.Bitmap]::new($imgWater);
 [System.Drawing.Graphics] $gfx = [System.Drawing.Graphics]::FromImage($bitmapOut);

 $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality;
 $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic;
 $gfx.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit;

 $waterFont = [System.Drawing.Font]::new([System.Drawing.FontFamily]::new("Courier New"),$fntsize,[System.Drawing.FontStyle]::Bold);
 $gfx.DrawString("$copy $($signStr)",$waterFont,[System.Drawing.Brushes]::SlateGray,($imgWater.Width*.5)-$defaultoffset,($imgWater.Height)-$defaultoffset);
 
 if (-not $imageStream.SafeFileHandle.IsClosed) {
 $imageStream.SafeFileHandle.Close();
 }
 if ($ovr) {
  if ($image.StartsWith(".\")) { $image = ((Resolve-Path $image).Path); }
  Write-Host "Running on process :"$([System.Diagnostics.Process]::GetCurrentProcess().Id)" with handles @"$([System.Diagnostics.Process]::GetCurrentProcess().Handles);

   $memStream = [System.IO.MemoryStream]::new();
   $fileOut = [System.IO.FileStream]::new("$($image)",[System.IO.FileMode]::Create,[System.IO.FileAccess]::ReadWrite);

   $bitmapOut.Save(($memStream), [System.Drawing.Imaging.ImageFormat]::Png);
   [Byte[]] $barray = $memStream.ToArray();
   
   $fileOut.Write($barray,0,$barray.Length);
 } else {
  $ext = $(Split-Path $image -Leaf).Split('.')[1];
   $fullPath = $image.TrimEnd(".$($ext)")+"_watermarked"+".$($ext)";
   $bitmapOut.Save($fullPath,$imgWater.RawFormat);
  }
 }
 End {

 $fileOut.SafeFileHandle.Close();
 }
}


<#
.Synopsis
    Function used for testing a cached image and a local image.

.Description
     Step-By-Step image verification via hashing and image checking methods.

.Parameter baseDir
    Main image path for local image.

.Parameter cached
    Stream used to retrieve a cached image instance.
#>
Function Test-ImageInfo {
param (
[Parameter(Mandatory=$true)]
[string]$baseDir,
[Parameter(Mandatory=$true)]
[System.IO.Stream]$cached
)

# Setting variables for validation..

 if (Test-Path ".\image_checks.log"){
  if ($([Math]::Round( ((gc ".\image_checks.log" -Encoding Byte).Length / 1KB),2 )) -ge 0) { rm ".\image_checks.log" }
   }
 $logfile = ".\image_checks.log";
 $imgname = $((Split-Path $baseDir -Leaf).Split('.')[0]);
 $imgdotrail = $(Split-Path $baseDir -Leaf).Split('.')[1];
 $imgPath = $($baseDir).TrimEnd("$($imgname).$($imgdotrail)");
 
 [System.Drawing.Image]$img = [System.Drawing.Image]::FromStream($cached);
 [System.Drawing.Image]$baseimg = [System.Drawing.Image]::FromFile((Resolve-Path $baseDir).Path);
 [System.Drawing.Image]$imgComp = $img.Clone();
 
# Creating temporary image storage for additional filesystem checks..

 $tempimg = "$($imgPath)$($imgname)_temp.$($imgdotrail)";
 if (-not (Test-Path "$($imgPath)$($imgname)_temp.$($imgdotrail)")) {
 Copy-Item -Path "$($baseDir)" -Destination $($tempimg);
 }

 $tmpimgname = $((Split-Path $tempimg -Leaf).Split('.')[0] -ireplace "_temp","");
 $tmpimgdotrail = $(Split-Path $tempimg -Leaf).Split('.')[1];
 $tmpimgPath = $((Resolve-Path "$($tempimg)").Path).TrimEnd("$($tmpimgname)_temp.$($tmpimgdotrail)");
 
 $checkimg = @("$($imgPath)$($imgname)_grey.$($imgdotrail)","$($tmpimgPath)$($tmpimgname)_temp_grey.$($tmpimgdotrail)");
 
Try {
 if (-not (Test-Path $checkimg[0])) {
  (Get-GreyScale -img $baseimg -w ($baseimg).Width -h ($baseimg).Height).Save("$($checkimg[0])");
  }
  if (-not (Test-Path $checkimg[1])) {
  (Get-GreyScale -img $imgComp -w ($imgComp).Width -h ($imgComp).Height).Save("$($checkimg[1])");
  }
 }
Catch {
Write-Host "Error occured in graphics lib, image not saved.";
}
$ingreyscale = "$($imgPath)$($imgname)_grey.$($imgdotrail)";
$tempgreyscale = "$($tmpimgPath)$($tmpimgname)_temp_grey.$($tmpimgdotrail)";

# Image data validation series starts here..
 
  <# 1 - Width, Height of image validations #>
 $dimCompare = (($imgComp.Height -eq $baseimg.Height) -and ($imgComp.Width -eq $baseimg.Width));
 $diminfo = "1 - Image dimensions check..";
 Write-Host $diminfo;
 if(-not $dimCompare) { "-----Error:Ended image dimensions-validations-----" | Out-File $logfile -Append; return $false }
 $diminfo | Out-File $logfile -Append;
 "`r`n$($dimCompare)" | Out-File $logfile -Append;

 <# 2 - Byte image size validations #>
 [Int]$sizebase = "$($baseDir)" | Get-ImageSize;
 [int]$sizecomp = "$($tempimg)" | Get-ImageSize;
 $sizeCompare = ($sizebase -eq $sizecomp);
 $sizeinfo = "2 - Image byte size check..";
 Write-Host $sizeinfo;
 if (-not $sizeCompare) { "-----Error:Ended byte size-validations-----" | Out-File $logfile -Append; return $false }
 $sizeinfo | Out-File $logfile -Append;
 "`r`n$($sizeCompare)" | Out-File $logfile -Append;

 <# 3 - Hashed name, hashed extension validations #>
 $encryptedName = Convert-NameToMD5 -imgInput "$($imgname)"; $encryptedtmpName = Convert-NameToMD5 -imgInput "$($tmpimgname)";
 $encryptedEx = Convert-NameToMD5 -imgInput "$($imgdotrail)"; $encryptedtmpEx = Convert-NameToMD5 -imgInput "$($tmpimgdotrail)";
 $hashnameCompare = (($encryptedName -eq $encryptedtmpName) -and ($encryptedEx -eq $encryptedtmpEx));
 $hashnameinfo = "3 - Name hashing check..";
 Write-Host $hashnameinfo;
 if(-not $hashnameCompare) { "-----Error:Ended file name hash-validations-----" | Out-File $logfile -Append; return $false }
 $hashnameinfo | Out-File $logfile -Append;
 "`r`n$($hashnameCompare)" | Out-File $logfile -Append;

 <# 4 - Image RGB xor validations #>
 $rndCachepx = Get-ImagePxRnd -imgrnd "$($tempimg)" -pixnum 50;
 $rndCompare = (Resolve-RndPx -pxlsInput $rndCachepx -baseimagepath "$($baseDir)" -ErrorAction SilentlyContinue);
 $rndinfo = "4 - Binary random px check..";
 Write-Host $rndinfo;
 if(-not $rndCompare) { "-----Error:Ended random RGB px-validations-----" | Out-File $logfile -Append; return $false }
 $rndinfo | Out-File $logfile -Append;
 "`r`n$($rndCompare)" | Out-File $logfile -Append;

 <# 5 - Luminence histogram validations #>
  # HSG initial greyscale image setup.
 $imghsg = (Resolve-HistogramData -imgIn $checkimg[0] -HSGMain $null -stampimage);
 $imgtemphsg = (Resolve-HistogramData -imgIn $checkimg[1] -HSGMain $null -stampimage);
 $hsgdata = (ConvertTo-Histogram -imgDirInput $($checkimg[1] -ireplace "_temp_grey","_temp_grey_lines") -resize);
 $hsgdataCompare = Resolve-HistogramData -imgIn $checkimg[0] -HSGMain $hsgdata;
 $hsginfo = "5 - Histogram data check..";
 Write-Host $hsginfo;
 if(-not $hsgdataCompare) { "-----Error:Ended histogram info-validations-----" | Out-File $logfile -Append; return $false }
 $hsginfo | Out-File $logfile -Append;
 "`r`n$($hsgdataCompare)" | Out-File $logfile -Append;

 <# 6 - Pixels hash validations #>
 $imgleft = (Get-ImagePxAreaHash -imagepath $tempimg -arealimit 1 -setfullarea);
 $imgright = (Get-ImagePxAreaHash -imagepath "$($baseDir)" -arealimit 1 -setfullarea);
 $hashCompare = ($imgleft -eq $imgright);
 $hashinfo = "6 - Bytes hashing check..";
 Write-Host $hashinfo;
 if(-not $hashCompare) { "-----Error:Ended bytes hash-validations-----" | Out-File $logfile -Append; return $false }
 $hashinfo | Out-File $logfile -Append;
 "`r`n$($hashCompare)" | Out-File $logfile -Append;

 <# 7 - File metadata validations #>
 $startimgdata = Get-ImageMetadata -pathImg $baseDir;
 $destimgdata = Get-ImageMetadata -pathImg "$($tempimg)";
 $metadataCompare = $($startimgdata -eq $destimgdata);
 $metadatainfo = "7 - Metadata check..";
 Write-Host $metadatainfo;
 if(-not $metadataCompare) { "-----Error:Ended metadata-validations-----" | Out-File $logfile -Append; return $false }
 $metadatainfo | Out-File $logfile -Append;
 "`r`n$($metadataCompare)" | Out-File $logfile -Append;


 $imageOK = @($sizeCompare,$hashnameCompare,$rndCompare,$dimCompare,$hashCompare,$metadataCompare,$hsgdataCompare);
 $imageRes = $imageOK -notcontains $false;
 if ($imageRes) {
 "`r`n=================================================================" | Out-File $logfile -Append;
 "Image validated OK, $($($imageOK).Length) tests pass" | Out-File $logfile -Append;
 "=================================================================" | Out-File $logfile -Append;
 Write-Host  -ForegroundColor Yellow "`r`nImage validated OK, $($($imageOK).Length) tests pass. Log file @ $($logfile)";
 }
return $imageRes;
}


<#
.Synopsis
    This function allows to convert an image to WPF's ImageSource data type definition.

.Description
    Creates a  new instance of an ImageSource type from a specified stream.

.Parameter imgbmp
    The stream generated from an image as an input.

.Parameter asimage
    Switch option to generate an Image type as output instead of ImageSource.
#>
Function Convert-ToImageSource {
[CmdLetBinding()]
param(
[Parameter(ValueFromPipeLine=$true)]
[System.IO.MemoryStream] $imgbmp,
[switch] $asimage
)
Process {
if ($asimage) {$bytestream = ($imgbmp -as [System.IO.Stream]); return $([System.Drawing.Image]::FromStream($bytestream));  }
$bmpsource = New-Object System.Drawing.Bitmap($imgbmp) -ErrorAction Stop;
$ptrBitmap = $bmpsource.GetHbitmap()
[System.Windows.Media.ImageSource]$imgsrc = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHBitmap($ptrBitmap, [System.IntPtr]::Zero, [System.Windows.Int32Rect]::Empty, [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions());
 }
End {
return $imgsrc;
 }
}


<#
.Synopsis
    Function that exports a base-64 string from a given input image.

.Description
    Generates the Base-64 Encoded counterpart of an image, or decodes a Base 64 string to image file.

.Parameter imgforenc
    The path of the image used as input for the decoding/encoding process.

.Parameter encode
    Switch option to export as base 64 or convert from base 64 to image, defaults to image decode.
#>
Function ConvertFrom-ToB64Image {
param(
[Parameter(Mandatory=$true,Position=0)]
[string]$imgforenc,
[Parameter(Mandatory=$false,Position=1)]
[switch]$encode
)
Begin {
if (Test-Path -LiteralPath $imgforenc -ErrorAction SilentlyContinue) {
$imgencfile = (Resolve-Path $(Get-ChildItem -Path "." -File -Filter "$($imgforenc)").FullName).Path;
$ext = "$(Split-Path -Leaf $imgforenc)".Split('.')[1];
 }
}
Process {
$b64img=null; 
if ($encode) {
if($ext -ieq "ico"){
$imgres = [System.Drawing.Icon]::ExtractAssociatedIcon("$($imgencfile)");
$memInit = New-Object System.IO.MemoryStream;
$imgres.Save($memInit);
$imgbytes = $memInit.ToArray();
$memInit.FlushAsync();
$memInit.Dispose(); $b64img = [System.Convert]::ToBase64String($imgbytes);
 }
 if(($ext -ieq "png") -or ($ext -ieq "jpg") -or ($ext -ieq "jpeg") -or ($ext -ieq "bmp")) {
 $b64img = [System.Convert]::ToBase64String((Get-Content -Path "$($imgencfile)" -Encoding Byte));
  }
 }
 else {
 $ImgFinalSource = [System.Windows.Media.Imaging.BitmapImage]::new()
 $ImgFinalSource.BeginInit()
 $ImgFinalSource.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($imgforenc)
 $ImgFinalSource.EndInit()
 $ImgFinalSource.Freeze()

 $b64img = $ImgFinalSource;
 }
}
 End {
 return $b64img;
 }
}


<#
.Synopsis
    Return an image from a given url.

.Description
    Used to perform a GET operation for a remote image and export to an ImageSource.

.Parameter remotepath
    Uri object used for performing the GET request.
#>
Function Get-ImageFromUri {
[CmdLetBinding()]
param(
[Parameter(ValueFromPipeLine=$true)]
[System.Uri]$remotepath
)


# Start remote web request..
Process {

 Try {
$image = (Invoke-WebRequest -Uri $remotepath -Method GET -ErrorAction SilentlyContinue -ErrorVariable "errorRequest").Content;
 }
 Catch { Write-Host "Resource unavailable or bad request - EXCEPTION OUTPUT : $($errorRequest)"}

}
 End {
# Close open sessions on error, handle exceptions..
  return (([System.IO.MemoryStream]::new($image)) | Convert-ToImageSource -asimage);
 }
}


<#
.Synopsis 
    Return a QR code from the corresponding input text.

.Description
    Can be utilized to export standard QR code as: PNG (default), SVG (option) or ascii text (option).

.Parameter toSVG
    Switch option, exports one or more QR code to SVG.

.Parameter toASCII
    Switch option, exports one or more QR code to ascii text.
#>
Function Get-QRFromText {
[CmdLetBinding()]
param(
[Parameter(ValueFromPipeLine=$true)]
[string]$qrtext,
[Parameter(Mandatory=$false)]
[switch]$toSVG,
[Parameter(Mandatory=$false)]
[switch]$toASCII
 )

# Pre-loading exernal libraries.
Begin {
 Try {
if (([System.Reflection.Assembly]::GetAssembly([ZXing.BarcodeFormat]).Count) -eq 1) {
 Write-Host "Asm 1 already loaded";
  }
 }
  Catch {
  }
  Try {
if (([System.Reflection.Assembly]::GetAssembly([QRCodeEncoderLibrary.QREncoder]).Count) -eq 1) {
 Write-Host  "Asm 2 already loaded";
  }
 }
  Catch {
[System.Reflection.Assembly]::Load("77,90,144,0,3,0,0,0,4,0,0,0,255,255,0,0,184,0,0,0,0,0,0,0,64,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,128,0,0,0,14,31,186,14,0,180,9,205,33,184,1,76,205,33,84,104,105,115,32,112,114,111,103,114,97,109,32,99,97,110,110,111,116,32,98,101,32,114,117,110,32,105,110,32,68,79,83,32,109,111,100,101,46,13,13,10,36,0,0,0,0,0,0,0,80,69,0,0,76,1,3,0,179,130,21,253,0,0,0,0,0,0,0,0,224,0,34,32,11,1,48,0,0,158,0,0,0,10,0,0,0,0,0,0,250,168,0,0,0,32,0,0,0,192,0,0,0,0,0,16,0,32,0,0,0,2,0,0,4,0,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,1,0,0,2,0,0,0,0,0,0,3,0,64,133,0,0,16,0,0,16,0,0,0,0,16,0,0,16,0,0,0,0,0,0,16,0,0,0,0,0,0,0,0,0,0,0,165,168,0,0,79,0,0,0,0,192,0,0,120,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,224,0,0,12,0,0,0,136,167,0,0,84,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32,0,0,8,0,0,0,0,0,0,0,0,0,0,0,8,32,0,0,72,0,0,0,0,0,0,0,0,0,0,0,46,116,101,120,116,0,0,0,56,157,0,0,0,32,0,0,0,158,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,32,0,0,96,46,114,115,114,99,0,0,0,120,6,0,0,0,192,0,0,0,8,0,0,0,160,0,0,0,0,0,0,0,0,0,0,0,0,0,0,64,0,0,64,46,114,101,108,111,99,0,0,12,0,0,0,0,224,0,0,0,2,0,0,0,168,0,0,0,0,0,0,0,0,0,0,0,0,0,0,64,0,0,66,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,217,168,0,0,0,0,0,0,72,0,0,0,2,0,5,0,244,93,0,0,148,73,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,19,48,5,0,104,0,0,0,1,0,0,17,0,23,10,22,11,43,74,0,4,32,176,21,0,0,50,7,32,176,21,0,0,43,1,4,12,4,8,89,16,2,43,17,0,6,2,3,37,23,88,16,1,145,88,10,7,6,88,11,0,8,23,89,37,12,22,254,4,22,254,1,13,9,45,224,6,32,241,255,0,0,94,10,7,32,241,255,0,0,94,11,0,4,22,254,2,19,4,17,4,45,172,7,31,16,98,6,96,19,5,43,0,17,5,42,19,48,6,0,52,0,0,0,2,0,0,17,0,21,10,43,32,126,1,0,0,4,6,2,3,37,23,88,16,1,145,97,32,255,0,0,0,95,149,6,30,100,97,10,4,23,89,16,2,4,22,254,2,11,7,45,216,6,102,12,43,0,8,42,110,32,0,1,0,0,141,25,0,0,1,37,208,137,0,0,4,40,15,0,0,10,128,1,0,0,4,42,19,48,5,0,249,0,0,0,3,0,0,17,0,2,31,34,111,16,0,0,10,22,254,4,19,4,17,4,44,29,0,2,23,141,30,0,0,1,37,22,31,32,157,111,17,0,0,10,40,5,0,0,6,0,56,201,0,0,0,115,18,0,0,10,10,22,11,22,12,22,13,56,165,0,0,0,0,43,5,0,7,23,88,11,7,2,111,19,0,0,10,47,13,2,7,111,20,0,0,10,31,32,254,1,43,1,22,19,5,17,5,45,222,7,2,111,19,0,0,10,254,1,19,6,17,6,44,2,43,116,2,7,111,20,0,0,10,31,34,254,1,19,7,17,7,44,43,0,7,23,88,11,2,31,34,7,111,21,0,0,10,12,8,22,254,4,19,8,17,8,44,11,114,1,0,0,112,115,22,0,0,10,122,8,23,88,13,0,43,31,0,2,31,32,7,111,21,0,0,10,12,8,22,254,4,19,9,17,9,44,7,2,111,19,0,0,10,12,8,13,0,6,2,7,8,7,89,111,23,0,0,10,111,24,0,0,10,0,9,11,0,56,86,255,255,255,6,111,25,0,0,10,40,5,0,0,6,0,43,0,42,0,0,0,19,48,4,0,69,4,0,0,4,0,0,17,0,2,44,8,2,142,105,24,254,4,43,1,23,19,6,17,6,44,11,114,49,0,0,112,115,22,0,0,10,122,22,10,20,11,20,12,115,60,0,0,6,19,5,22,19,7,56,197,3,0,0,0,2,17,7,154,19,8,17,8,22,111,20,0,0,10,31,47,46,17,17,8,22,111,20,0,0,10,31,45,254,1,22,254,1,43,1,22,19,10,17,10,44,64,0,7,20,254,1,19,11,17,11,44,9,0,17,8,11,56,128,3,0,0,8,20,254,1,19,12,17,12,44,9,0,17,8,12,56,109,3,0,0,114,59,0,0,112,17,7,23,88,140,32,0,0,1,40,26,0,0,10,115,22,0,0,10,122,17,8,31,58,111,16,0,0,10,19,9,17,9,22,254,4,19,13,17,13,44,11,17,8,31,61,111,16,0,0,10,19,9,17,9,22,254,2,19,14,17,14,44,30,0,17,8,23,17,9,23,89,111,23,0,0,10,13,17,8,17,9,23,88,111,27,0,0,10,19,4,0,43,18,0,17,8,23,111,27,0,0,10,13,126,28,0,0,10,19,4,0,9,111,29,0,0,10,13,17,4,111,29,0,0,10,19,4,9,19,15,17,15,40,64,0,0,6,19,16,17,16,32,224,34,12,224,53,62,17,16,32,62,78,230,189,53,28,17,16,32,81,135,145,33,46,106,43,0,17,16,32,62,78,230,189,59,224,0,0,0,56,147,2,0,0,17,16,32,157,144,159,215,46,122,43,0,17,16,32,224,34,12,224,46,89,56,122,2,0,0,17,16,32,23,50,53,234,53,25,17,16,32,120,47,12,232,46,110,43,0,17,16,32,23,50,53,234,46,121,56,88,2,0,0,17,16,32,163,61,12,241,59,170,0,0,0,43,0,17,16,32,92,66,12,244,46,115,56,60,2,0,0,17,15,114,117,0,0,112,40,30,0,0,10,58,159,0,0,0,56,38,2,0,0,17,15,114,129,0,0,112,40,30,0,0,10,58,137,0,0,0,56,16,2,0,0,17,15,114,133,0,0,112,40,30,0,0,10,58,185,1,0,0,56,250,1,0,0,17,15,114,147,0,0,112,40,30,0,0,10,58,163,1,0,0,56,228,1,0,0,17,15,114,151,0,0,112,40,30,0,0,10,58,174,1,0,0,56,206,1,0,0,17,15,114,163,0,0,112,40,30,0,0,10,58,152,1,0,0,56,184,1,0,0,17,15,114,167,0,0,112,40,30,0,0,10,58,163,1,0,0,56,162,1,0,0,17,15,114,177,0,0,112,40,30,0,0,10,58,141,1,0,0,56,140,1,0,0,17,4,19,20,17,20,40,64,0,0,6,19,16,17,16,32,231,202,194,89,53,68,17,16,32,253,185,221,61,53,31,17,16,32,118,215,175,53,59,144,0,0,0,43,0,17,16,32,253,185,221,61,59,194,0,0,0,56,241,0,0,0,17,16,32,129,106,81,79,46,81,43,0,17,16,32,231,202,194,89,59,134,0,0,0,56,213,0,0,0,17,16,32,11,49,12,233,53,25,17,16,32,120,47,12,232,46,95,43,0,17,16,32,11,49,12,233,46,52,56,179,0,0,0,17,16,32,87,55,12,237,59,131,0,0,0,43,0,17,16,32,92,66,12,244,46,88,56,151,0,0,0,17,20,114,181,0,0,112,40,30,0,0,10,45,117,56,132,0,0,0,17,20,114,189,0,0,112,40,30,0,0,10,45,98,43,116,17,20,114,193,0,0,112,40,30,0,0,10,45,87,43,100,17,20,114,147,0,0,112,40,30,0,0,10,45,71,43,84,17,20,114,207,0,0,112,40,30,0,0,10,45,60,43,68,17,20,114,163,0,0,112,40,30,0,0,10,45,44,43,52,17,20,114,223,0,0,112,40,30,0,0,10,45,33,43,36,17,20,114,233,0,0,112,40,30,0,0,10,45,17,43,20,22,19,17,43,26,23,19,17,43,21,24,19,17,43,16,25,19,17,43,11,114,237,0,0,112,115,22,0,0,10,122,17,5,17,17,111,18,0,0,6,0,43,96,17,4,18,18,40,31,0,0,10,22,254,1,19,21,17,21,44,3,21,19,18,17,5,17,18,111,20,0,0,6,0,43,63,17,4,18,19,40,31,0,0,10,22,254,1,19,22,17,22,44,3,21,19,19,17,5,17,19,111,22,0,0,6,0,43,30,23,10,43,26,114,47,1,0,112,17,7,23,88,140,32,0,0,1,9,40,32,0,0,10,115,33,0,0,10,122,0,17,7,23,88,19,7,17,7,2,142,105,254,4,19,23,17,23,58,43,252,255,255,6,19,24,17,24,44,22,0,7,40,34,0,0,10,19,25,17,5,17,25,111,23,0,0,6,0,0,43,20,0,7,40,35,0,0,10,19,26,17,5,17,26,111,25,0,0,6,0,0,17,5,8,111,27,0,0,6,0,43,0,42,46,114,115,1,0,112,128,2,0,0,4,42,30,2,123,26,0,0,4,42,34,2,3,125,26,0,0,4,42,30,2,123,27,0,0,4,42,34,2,3,125,27,0,0,4,42,30,2,123,28,0,0,4,42,34,2,3,125,28,0,0,4,42,30,2,123,29,0,0,4,42,34,2,3,125,29,0,0,4,42,30,2,123,30,0,0,4,42,34,2,3,125,30,0,0,4,42,0,0,19,48,1,0,12,0,0,0,5,0,0,17,0,2,123,51,0,0,4,10,43,0,6,42,19,48,2,0,37,0,0,0,6,0,0,17,0,3,22,50,6,3,25,254,2,43,1,23,10,6,44,11,114,248,5,0,112,115,22,0,0,10,122,2,3,125,51,0,0,4,43,0,42,0,0,0,19,48,1,0,12,0,0,0,7,0,0,17,0,2,123,52,0,0,4,10,43,0,6,42,19,48,4,0,91,0,0,0,8,0,0,17,0,3,23,50,7,3,31,100,254,2,43,1,23,10,6,44,11,114,120,6,0,112,115,22,0,0,10,122,2,3,125,52,0,0,4,2,123,53,0,0,4,26,3,90,254,4,11,7,44,9,2,26,3,90,125,53,0,0,4,2,24,2,123,53,0,0,4,90,2,40,11,0,0,6,2,123,52,0,0,4,90,88,40,14,0,0,6,0,43,0,42,0,19,48,1,0,12,0,0,0,7,0,0,17,0,2,123,53,0,0,4,10,43,0,6,42,19,48,4,0,77,0,0,0,6,0,0,17,0,3,26,2,123,52,0,0,4,90,50,10,3,32,144,1,0,0,254,2,43,1,23,10,6,44,11,114,186,6,0,112,115,22,0,0,10,122,2,3,125,53,0,0,4,2,24,2,123,53,0,0,4,90,2,40,11,0,0,6,2,123,52,0,0,4,90,88,40,14,0,0,6,0,43,0,42,0,0,0,19,48,5,0,54,0,0,0,9,0,0,17,0,3,40,36,0,0,10,11,7,44,11,114,65,7,0,112,115,37,0,0,10,122,40,38,0,0,10,3,111,39,0,0,10,10,2,23,141,2,0,0,27,37,22,6,162,40,26,0,0,6,0,43,0,42,0,0,19,48,5,0,134,0,0,0,10,0,0,17,0,3,44,7,3,142,22,254,1,43,1,23,11,7,44,11,114,143,7,0,112,115,37,0,0,10,122,22,12,43,27,0,3,8,154,20,254,1,13,9,44,11,114,221,7,0,112,115,37,0,0,10,122,0,8,23,88,12,8,3,142,105,254,4,19,4,17,4,45,217,3,142,105,141,2,0,0,27,10,22,19,5,43,26,0,6,17,5,40,38,0,0,10,3,17,5,154,111,39,0,0,10,162,0,17,5,23,88,19,5,17,5,3,142,105,254,4,19,6,17,6,45,217,2,6,40,26,0,0,6,0,43,0,42,0,0,19,48,5,0,47,0,0,0,6,0,0,17,0,3,44,7,3,142,22,254,1,43,1,23,10,6,44,11,114,63,8,0,112,115,37,0,0,10,122,2,23,141,2,0,0,27,37,22,3,162,40,26,0,0,6,0,43,0,42,0,19,48,4,0,69,1,0,0,11,0,0,17,0,3,44,7,3,142,22,254,1,43,1,23,11,7,44,11,114,155,8,0,112,115,37,0,0,10,122,2,20,40,8,0,0,6,0,2,22,40,10,0,0,6,0,2,22,40,12,0,0,6,0,2,22,40,14,0,0,6,0,22,10,22,12,43,37,0,3,8,154,13,9,20,254,1,19,4,17,4,44,11,3,8,22,141,37,0,0,1,162,43,6,6,9,142,105,88,10,0,8,23,88,12,8,3,142,105,254,4,19,5,17,5,45,207,6,22,254,1,19,6,17,6,44,11,114,235,8,0,112,115,22,0,0,10,122,2,3,125,31,0,0,4,2,40,30,0,0,6,0,2,40,31,0,0,6,0,2,40,33,0,0,6,0,2,40,35,0,0,6,0,2,40,47,0,0,6,0,2,40,36,0,0,6,0,2,40,37,0,0,6,0,2,40,44,0,0,6,0,2,2,40,11,0,0,6,2,40,11,0,0,6,115,40,0,0,10,40,8,0,0,6,0,22,19,7,43,79,0,22,19,8,43,50,0,2,123,48,0,0,4,17,7,17,8,40,41,0,0,10,23,95,22,254,3,19,9,17,9,44,16,2,40,7,0,0,6,17,7,17,8,23,40,42,0,0,10,0,17,8,23,88,19,8,17,8,2,40,11,0,0,6,254,4,19,10,17,10,45,190,0,17,7,23,88,19,7,17,7,2,40,11,0,0,6,254,4,19,11,17,11,45,161,43,0,42,0,0,0,27,48,4,0,110,0,0,0,12,0,0,17,0,3,20,254,1,10,6,44,11,114,35,9,0,112,115,37,0,0,10,122,3,114,111,9,0,112,27,111,43,0,0,10,22,254,1,11,7,44,11,114,121,9,0,112,115,22,0,0,10,122,2,40,7,0,0,6,20,254,1,12,8,44,11,114,227,9,0,112,115,33,0,0,10,122,3,24,24,22,115,44,0,0,10,13,0,2,9,40,28,0,0,6,0,0,222,11,9,44,7,9,111,45,0,0,10,0,220,43,0,42,0,0,1,16,0,0,2,0,84,0,12,96,0,11,0,0,0,0,19,48,4,0,129,0,0,0,13,0,0,17,0,2,40,7,0,0,6,20,254,1,19,4,17,4,44,11,114,227,9,0,112,115,33,0,0,10,122,2,40,57,0,0,6,10,2,40,59,0,0,6,11,7,40,58,0,0,6,12,3,115,46,0,0,10,13,9,126,49,0,0,4,22,126,49,0,0,4,142,105,111,47,0,0,10,0,9,6,22,6,142,105,111,47,0,0,10,0,9,8,22,8,142,105,111,47,0,0,10,0,9,126,50,0,0,4,22,126,50,0,0,4,142,105,111,47,0,0,10,0,9,111,48,0,0,10,0,43,0,42,0,0,0,19,48,4,0,247,0,0,0,14,0,0,17,0,2,40,7,0,0,6,20,254,1,19,4,17,4,44,11,114,227,9,0,112,115,33,0,0,10,122,2,40,13,0,0,6,10,6,6,115,40,0,0,10,11,2,123,53,0,0,4,12,2,123,53,0,0,4,13,22,19,5,56,156,0,0,0,0,22,19,6,43,111,0,2,40,7,0,0,6,17,5,17,6,40,49,0,0,10,19,7,17,7,44,73,0,22,19,8,43,50,0,22,19,9,43,21,7,9,17,8,88,8,17,9,88,23,40,42,0,0,10,17,9,23,88,19,9,17,9,2,40,19,0,0,6,254,4,19,10,17,10,45,219,0,17,8,23,88,19,8,17,8,2,40,19,0,0,6,254,4,19,11,17,11,45,190,0,8,2,40,19,0,0,6,88,12,0,17,6,23,88,19,6,17,6,2,40,11,0,0,6,254,4,19,12,17,12,45,129,2,123,53,0,0,4,12,9,2,40,19,0,0,6,88,13,0,17,5,23,88,19,5,17,5,2,40,11,0,0,6,254,4,19,13,17,13,58,81,255,255,255,7,19,14,43,0,17,14,42,0,19,48,4,0,19,2,0,0,15,0,0,17,0,2,2,123,31,0,0,4,142,105,141,6,0,0,2,125,41,0,0,4,2,22,125,32,0,0,4,22,11,56,245,0,0,0,0,2,123,31,0,0,4,7,154,12,8,142,105,13,23,19,4,22,19,6,43,56,0,126,56,0,0,4,8,17,6,145,145,19,7,17,7,31,10,254,4,19,8,17,8,44,2,43,23,17,7,31,45,254,4,19,9,17,9,44,6,0,24,19,4,43,5,26,19,4,43,17,17,6,23,88,19,6,17,6,9,254,4,19,10,17,10,45,189,26,19,5,17,4,19,11,17,11,23,89,69,4,0,0,0,2,0,0,0,53,0,0,0,94,0,0,0,84,0,0,0,43,92,17,5,31,10,9,25,91,90,88,19,5,9,25,93,23,254,1,19,12,17,12,44,8,17,5,26,88,19,5,43,18,9,25,93,24,254,1,19,13,17,13,44,6,17,5,29,88,19,5,43,41,17,5,31,11,9,24,91,90,88,19,5,9,23,95,22,254,3,19,14,17,14,44,6,17,5,28,88,19,5,43,10,17,5,30,9,90,88,19,5,43,0,2,123,41,0,0,4,7,17,4,158,2,2,123,32,0,0,4,17,5,88,125,32,0,0,4,0,7,23,88,11,7,2,123,31,0,0,4,142,105,254,4,19,15,17,15,58,247,254,255,255,22,10,2,23,40,10,0,0,6,0,56,151,0,0,0,0,2,31,17,26,2,40,9,0,0,6,90,88,40,12,0,0,6,0,2,24,2,123,53,0,0,4,90,2,40,11,0,0,6,2,123,52,0,0,4,90,88,40,14,0,0,6,0,2,40,46,0,0,6,0,22,10,22,19,16,43,24,6,2,2,123,41,0,0,4,17,16,148,40,45,0,0,6,88,10,17,16,23,88,19,16,17,16,2,123,41,0,0,4,142,105,254,4,19,17,17,17,45,214,2,123,32,0,0,4,6,88,2,123,35,0,0,4,254,2,22,254,1,19,18,17,18,44,2,43,42,0,2,40,9,0,0,6,19,19,2,17,19,23,88,40,10,0,0,6,0,2,40,9,0,0,6,31,40,254,2,22,254,1,19,20,17,20,58,83,255,255,255,2,40,9,0,0,6,31,40,254,2,19,21,17,21,44,11,114,29,10,0,112,115,33,0,0,10,122,2,2,123,32,0,0,4,6,88,125,32,0,0,4,43,0,42,0,19,48,7,0,134,2,0,0,16,0,0,17,0,2,2,123,33,0,0,4,141,37,0,0,1,125,42,0,0,4,2,22,125,43,0,0,4,2,22,125,44,0,0,4,2,22,125,45,0,0,4,22,11,56,141,1,0,0,0,2,123,31,0,0,4,7,154,12,8,142,105,13,2,2,123,41,0,0,4,7,148,26,40,32,0,0,6,0,2,9,2,2,123,41,0,0,4,7,148,40,45,0,0,6,40,32,0,0,6,0,2,123,41,0,0,4,7,148,19,4,17,4,23,89,69,4,0,0,0,5,0,0,0,171,0,0,0,49,1,0,0,13,1,0,0,56,44,1,0,0,9,25,91,25,90,19,5,22,19,7,43,57,2,31,100,126,56,0,0,4,8,17,7,145,145,90,31,10,126,56,0,0,4,8,17,7,23,88,145,145,90,88,126,56,0,0,4,8,17,7,24,88,145,145,88,31,10,40,32,0,0,6,0,17,7,25,88,19,7,17,7,17,5,254,4,19,8,17,8,45,187,9,17,5,89,23,254,1,19,9,17,9,44,20,2,126,56,0,0,4,8,17,5,145,145,26,40,32,0,0,6,0,43,47,9,17,5,89,24,254,1,19,10,17,10,44,34,2,31,10,126,56,0,0,4,8,17,5,145,145,90,126,56,0,0,4,8,17,5,23,88,145,145,88,29,40,32,0,0,6,0,56,134,0,0,0,9,24,91,24,90,19,6,22,19,11,43,41,2,31,45,126,56,0,0,4,8,17,11,145,145,90,126,56,0,0,4,8,17,11,23,88,145,145,88,31,11,40,32,0,0,6,0,17,11,24,88,19,11,17,11,17,6,254,4,19,12,17,12,45,203,9,17,6,89,23,254,1,19,13,17,13,44,18,2,126,56,0,0,4,8,17,6,145,145,28,40,32,0,0,6,0,43,36,22,19,14,43,18,2,8,17,14,145,30,40,32,0,0,6,0,17,14,23,88,19,14,17,14,9,254,4,19,15,17,15,45,227,43,0,0,7,23,88,11,7,2,123,31,0,0,4,142,105,254,4,19,16,17,16,58,95,254,255,255,2,123,32,0,0,4,2,123,35,0,0,4,254,4,19,17,17,17,44,40,2,22,2,123,35,0,0,4,2,123,32,0,0,4,89,26,50,3,26,43,13,2,123,35,0,0,4,2,123,32,0,0,4,89,40,32,0,0,6,0,2,123,45,0,0,4,22,254,2,19,18,17,18,44,37,2,123,42,0,0,4,2,2,123,43,0,0,4,19,19,17,19,23,88,125,43,0,0,4,17,19,2,123,44,0,0,4,31,24,100,210,156,2,123,34,0,0,4,2,123,43,0,0,4,89,10,22,19,20,43,38,2,123,42,0,0,4,2,123,43,0,0,4,17,20,88,17,20,23,95,44,4,31,17,43,5,32,236,0,0,0,210,156,17,20,23,88,19,20,17,20,6,254,4,19,21,17,21,45,207,43,0,42,0,0,19,48,5,0,129,0,0,0,17,0,0,17,0,2,2,123,44,0,0,4,3,31,32,2,123,45,0,0,4,89,4,89,31,31,95,98,96,125,44,0,0,4,2,2,123,45,0,0,4,4,88,125,45,0,0,4,43,64,0,2,123,42,0,0,4,2,2,123,43,0,0,4,10,6,23,88,125,43,0,0,4,6,2,123,44,0,0,4,31,24,100,210,156,2,2,123,44,0,0,4,30,98,125,44,0,0,4,2,2,123,45,0,0,4,30,89,125,45,0,0,4,0,2,123,45,0,0,4,30,254,4,22,254,1,11,7,45,176,43,0,42,0,0,0,19,48,5,0,246,0,0,0,18,0,0,17,0,126,93,0,0,4,2,123,36,0,0,4,29,89,154,10,2,123,38,0,0,4,2,123,40,0,0,4,40,50,0,0,10,2,123,36,0,0,4,88,11,7,141,37,0,0,1,12,2,123,38,0,0,4,13,9,2,123,36,0,0,4,88,19,4,22,19,5,2,123,34,0,0,4,19,6,2,123,37,0,0,4,2,123,39,0,0,4,88,19,7,22,19,8,56,129,0,0,0,0,17,8,2,123,37,0,0,4,254,1,19,9,17,9,44,19,0,2,123,40,0,0,4,13,9,2,123,36,0,0,4,88,19,4,0,2,123,42,0,0,4,17,5,8,22,9,40,51,0,0,10,0,8,9,2,123,36,0,0,4,40,52,0,0,10,0,17,5,9,88,19,5,8,17,4,6,2,123,36,0,0,4,40,34,0,0,6,0,8,9,2,123,42,0,0,4,17,6,2,123,36,0,0,4,40,51,0,0,10,0,17,6,2,123,36,0,0,4,88,19,6,0,17,8,23,88,19,8,17,8,17,7,254,4,19,10,17,10,58,112,255,255,255,43,0,42,0,0,19,48,6,0,104,0,0,0,19,0,0,17,0,3,5,89,10,22,11,43,82,0,2,7,145,22,254,1,13,9,44,2,43,65,126,95,0,0,4,2,7,145,145,12,22,19,4,43,38,0,2,7,23,88,17,4,88,2,7,23,88,17,4,88,145,126,94,0,0,4,4,17,4,145,8,88,145,97,210,156,0,17,4,23,88,19,4,17,4,5,254,4,19,5,17,5,45,207,0,7,23,88,11,7,6,254,4,19,6,17,6,45,164,43,0,42,19,48,5,0,167,1,0,0,20,0,0,17,0,2,123,33,0,0,4,141,37,0,0,1,10,2,123,37,0,0,4,2,123,39,0,0,4,88,11,7,141,32,0,0,1,12,23,19,6,43,41,8,17,6,8,17,6,23,89,148,17,6,2,123,37,0,0,4,49,8,2,123,40,0,0,4,43,6,2,123,38,0,0,4,88,158,17,6,23,88,19,6,17,6,7,254,4,19,7,17,7,45,204,2,123,38,0,0,4,7,90,13,22,19,5,22,19,4,43,56,0,6,17,4,2,123,42,0,0,4,8,17,5,148,145,156,8,17,5,143,32,0,0,1,37,74,23,88,84,17,5,23,88,19,5,17,5,7,254,1,19,8,17,8,44,3,22,19,5,0,17,4,23,88,19,4,17,4,9,254,4,19,9,17,9,45,189,2,123,40,0,0,4,2,123,38,0,0,4,254,2,19,10,17,10,44,91,0,2,123,34,0,0,4,13,2,123,37,0,0,4,19,5,43,61,0,6,17,4,2,123,42,0,0,4,8,17,5,148,145,156,8,17,5,143,32,0,0,1,37,74,23,88,84,17,5,23,88,19,5,17,5,7,254,1,19,11,17,11,44,8,2,123,37,0,0,4,19,5,0,17,4,23,88,19,4,17,4,9,254,4,19,12,17,12,45,184,0,8,22,2,123,34,0,0,4,158,23,19,13,43,23,8,17,13,8,17,13,23,89,148,2,123,36,0,0,4,88,158,17,13,23,88,19,13,17,13,7,254,4,19,14,17,14,45,222,2,123,33,0,0,4,13,22,19,5,43,56,0,6,17,4,2,123,42,0,0,4,8,17,5,148,145,156,8,17,5,143,32,0,0,1,37,74,23,88,84,17,5,23,88,19,5,17,5,7,254,1,19,15,17,15,44,3,22,19,5,0,17,4,23,88,19,4,17,4,9,254,4,19,16,17,16,45,189,2,6,125,42,0,0,4,43,0,42,0,19,48,5,0,29,1,0,0,21,0,0,17,0,22,10,30,2,123,33,0,0,4,90,11,2,40,11,0,0,6,23,89,12,2,40,11,0,0,6,23,89,13,22,19,4,56,239,0,0,0,0,2,123,46,0,0,4,8,9,40,41,0,0,10,24,95,22,254,1,19,5,17,5,44,67,0,2,123,42,0,0,4,6,25,99,145,23,29,6,29,95,89,31,31,95,98,95,22,254,3,19,6,17,6,44,14,2,123,46,0,0,4,8,9,23,40,53,0,0,10,6,23,88,37,10,7,254,1,19,7,17,7,44,5,56,155,0,0,0,0,43,14,9,28,254,1,19,8,17,8,44,4,9,23,89,13,17,4,19,9,17,9,69,4,0,0,0,2,0,0,0,11,0,0,0,49,0,0,0,58,0,0,0,43,103,9,23,89,13,23,19,4,43,95,9,23,88,13,8,23,89,12,8,22,254,4,22,254,1,19,10,17,10,44,6,0,22,19,4,43,68,9,24,89,13,22,12,24,19,4,43,57,9,23,89,13,25,19,4,43,48,9,23,88,13,8,23,88,12,8,2,40,11,0,0,6,254,4,19,11,17,11,44,6,0,24,19,4,43,19,9,24,89,13,2,40,11,0,0,6,23,89,12,22,19,4,43,1,0,56,12,255,255,255,43,0,42,0,0,0,19,48,2,0,173,0,0,0,22,0,0,17,0,32,255,255,255,127,10,2,22,40,16,0,0,6,0,22,11,56,135,0,0,0,0,2,7,40,48,0,0,6,0,2,40,38,0,0,6,12,8,6,254,4,22,254,1,13,9,44,2,43,102,8,2,40,39,0,0,6,88,12,8,6,254,4,22,254,1,19,4,17,4,44,2,43,78,8,2,40,40,0,0,6,88,12,8,6,254,4,22,254,1,19,5,17,5,44,2,43,54,8,2,40,41,0,0,6,88,12,8,6,254,4,22,254,1,19,6,17,6,44,2,43,30,2,2,123,47,0,0,4,125,48,0,0,4,2,20,125,47,0,0,4,8,10,2,7,40,16,0,0,6,0,0,7,23,88,11,7,30,254,4,19,7,17,7,58,108,255,255,255,43,0,42,0,0,0,19,48,4,0,60,1,0,0,23,0,0,17,0,22,10,22,11,43,119,0,23,12,23,13,43,73,0,2,123,47,0,0,4,7,9,23,89,40,41,0,0,10,2,123,47,0,0,4,7,9,40,41,0,0,10,97,23,95,22,254,3,19,4,17,4,44,23,0,8,27,254,4,22,254,1,19,5,17,5,44,6,6,8,24,89,88,10,22,12,0,8,23,88,12,0,9,23,88,13,9,2,40,11,0,0,6,254,4,19,6,17,6,45,168,8,27,254,4,22,254,1,19,7,17,7,44,6,6,8,24,89,88,10,0,7,23,88,11,7,2,40,11,0,0,6,254,4,19,8,17,8,58,119,255,255,255,22,19,9,56,137,0,0,0,0,23,19,10,23,19,11,43,84,0,2,123,47,0,0,4,17,11,23,89,17,9,40,41,0,0,10,2,123,47,0,0,4,17,11,17,9,40,41,0,0,10,97,23,95,22,254,3,19,12,17,12,44,26,0,17,10,27,254,4,22,254,1,19,13,17,13,44,7,6,17,10,24,89,88,10,22,19,10,0,17,10,23,88,19,10,0,17,11,23,88,19,11,17,11,2,40,11,0,0,6,254,4,19,14,17,14,45,156,17,10,27,254,4,22,254,1,19,15,17,15,44,7,6,17,10,24,89,88,10,0,17,9,23,88,19,9,17,9,2,40,11,0,0,6,254,4,19,16,17,16,58,100,255,255,255,6,19,17,43,0,17,17,42,19,48,5,0,227,0,0,0,24,0,0,17,0,22,10,23,11,56,191,0,0,0,23,12,56,162,0,0,0,0,2,123,47,0,0,4,7,23,89,8,23,89,40,41,0,0,10,2,123,47,0,0,4,7,23,89,8,40,41,0,0,10,95,2,123,47,0,0,4,7,8,23,89,40,41,0,0,10,95,2,123,47,0,0,4,7,8,40,41,0,0,10,95,23,95,22,254,3,13,9,44,6,6,25,88,10,43,78,2,123,47,0,0,4,7,23,89,8,23,89,40,41,0,0,10,2,123,47,0,0,4,7,23,89,8,40,41,0,0,10,96,2,123,47,0,0,4,7,8,23,89,40,41,0,0,10,96,2,123,47,0,0,4,7,8,40,41,0,0,10,96,23,95,22,254,1,19,4,17,4,44,4,6,25,88,10,0,8,23,88,12,8,2,40,11,0,0,6,254,4,19,5,17,5,58,76,255,255,255,7,23,88,11,7,2,40,11,0,0,6,254,4,19,6,17,6,58,47,255,255,255,6,19,7,43,0,17,7,42,0,19,48,4,0,213,1,0,0,25,0,0,17,0,22,10,22,11,56,189,0,0,0,0,22,12,22,13,43,120,0,2,123,47,0,0,4,7,9,40,41,0,0,10,23,95,22,254,1,19,4,17,4,44,2,43,89,9,8,89,26,254,4,22,254,1,19,5,17,5,44,69,0,8,29,50,12,2,7,8,29,89,40,42,0,0,6,43,1,22,19,6,17,6,44,5,6,31,40,88,10,2,40,11,0,0,6,9,89,29,50,10,2,7,9,40,42,0,0,6,43,1,22,19,7,17,7,44,11,0,6,31,40,88,10,9,28,88,13,0,0,9,23,88,12,0,9,23,88,13,9,2,40,11,0,0,6,254,4,19,8,17,8,58,118,255,255,255,2,40,11,0,0,6,8,89,26,50,16,8,29,50,12,2,7,8,29,89,40,42,0,0,6,43,1,22,19,9,17,9,44,5,6,31,40,88,10,0,7,23,88,11,7,2,40,11,0,0,6,254,4,19,10,17,10,58,49,255,255,255,22,19,11,56,217,0,0,0,0,22,19,12,22,19,13,56,136,0,0,0,0,2,123,47,0,0,4,17,13,17,11,40,41,0,0,10,23,95,22,254,1,19,14,17,14,44,2,43,101,17,13,17,12,89,26,254,4,22,254,1,19,15,17,15,44,77,0,17,12,29,50,14,2,17,12,29,89,17,11,40,43,0,0,6,43,1,22,19,16,17,16,44,5,6,31,40,88,10,2,40,11,0,0,6,17,13,89,29,50,12,2,17,13,17,11,40,43,0,0,6,43,1,22,19,17,17,17,44,13,0,6,31,40,88,10,17,13,28,88,19,13,0,0,17,13,23,88,19,12,0,17,13,23,88,19,13,17,13,2,40,11,0,0,6,254,4,19,18,17,18,58,101,255,255,255,2,40,11,0,0,6,17,12,89,26,50,19,17,12,29,50,14,2,17,12,29,89,17,11,40,43,0,0,6,43,1,22,19,19,17,19,44,5,6,31,40,88,10,0,17,11,23,88,19,11,17,11,2,40,11,0,0,6,254,4,19,20,17,20,58,20,255,255,255,6,19,21,43,0,17,21,42,0,0,0,19,48,3,0,197,0,0,0,26,0,0,17,0,22,10,22,12,43,55,22,13,43,32,2,123,47,0,0,4,8,9,40,41,0,0,10,23,95,22,254,3,19,4,17,4,44,4,6,23,88,10,9,23,88,13,9,2,40,11,0,0,6,254,4,19,5,17,5,45,209,8,23,88,12,8,2,40,11,0,0,6,254,4,19,6,17,6,45,186,6,108,2,40,11,0,0,6,2,40,11,0,0,6,90,108,91,11,7,35,154,153,153,153,153,153,225,63,254,2,19,7,17,7,44,29,35,0,0,0,0,0,0,52,64,7,35,0,0,0,0,0,0,224,63,89,90,105,31,10,90,19,8,43,52,7,35,205,204,204,204,204,204,220,63,254,4,19,9,17,9,44,29,35,0,0,0,0,0,0,52,64,35,0,0,0,0,0,0,224,63,7,89,90,105,31,10,90,19,8,43,5,22,19,8,43,0,17,8,42,0,0,0,19,48,5,0,122,0,0,0,6,0,0,17,0,2,123,47,0,0,4,3,4,40,41,0,0,10,2,123,47,0,0,4,3,4,23,88,40,41,0,0,10,102,95,2,123,47,0,0,4,3,4,24,88,40,41,0,0,10,95,2,123,47,0,0,4,3,4,25,88,40,41,0,0,10,95,2,123,47,0,0,4,3,4,26,88,40,41,0,0,10,95,2,123,47,0,0,4,3,4,27,88,40,41,0,0,10,102,95,2,123,47,0,0,4,3,4,28,88,40,41,0,0,10,95,23,95,22,254,3,10,43,0,6,42,0,0,19,48,4,0,122,0,0,0,6,0,0,17,0,2,123,47,0,0,4,3,4,40,41,0,0,10,2,123,47,0,0,4,3,23,88,4,40,41,0,0,10,102,95,2,123,47,0,0,4,3,24,88,4,40,41,0,0,10,95,2,123,47,0,0,4,3,25,88,4,40,41,0,0,10,95,2,123,47,0,0,4,3,26,88,4,40,41,0,0,10,95,2,123,47,0,0,4,3,27,88,4,40,41,0,0,10,102,95,2,123,47,0,0,4,3,28,88,4,40,41,0,0,10,95,23,95,22,254,3,10,43,0,6,42,0,0,19,48,5,0,200,1,0,0,27,0,0,17,0,2,40,9,0,0,6,29,254,4,22,254,1,13,9,57,189,0,0,0,0,2,40,11,0,0,6,31,11,89,19,4,126,99,0,0,4,2,40,9,0,0,6,29,89,148,19,5,23,10,22,19,6,43,62,22,19,7,43,40,0,2,123,48,0,0,4,17,6,17,4,17,7,88,17,5,6,95,45,3,28,43,1,29,40,53,0,0,10,6,23,98,10,0,17,7,23,88,19,7,17,7,25,254,4,19,8,17,8,45,205,17,6,23,88,19,6,17,6,28,254,4,19,9,17,9,45,183,23,10,22,19,10,43,62,22,19,11,43,40,0,2,123,48,0,0,4,17,4,17,11,88,17,10,17,5,6,95,45,3,28,43,1,29,40,53,0,0,10,6,23,98,10,0,17,11,23,88,19,11,17,11,25,254,4,19,12,17,12,45,205,17,10,23,88,19,10,17,10,28,254,4,19,13,17,13,45,183,0,22,11,2,123,51,0,0,4,19,14,17,14,69,4,0,0,0,2,0,0,0,16,0,0,0,6,0,0,0,11,0,0,0,43,14,30,11,43,10,31,24,11,43,5,31,16,11,43,0,126,96,0,0,4,7,2,40,15,0,0,6,88,148,12,23,10,22,19,15,56,155,0,0,0,0,8,6,95,45,3,28,43,1,29,19,16,6,23,98,10,2,123,48,0,0,4,126,97,0,0,4,17,15,22,40,54,0,0,10,126,97,0,0,4,17,15,23,40,54,0,0,10,17,16,210,40,53,0,0,10,126,98,0,0,4,17,15,22,40,54,0,0,10,19,17,17,17,22,254,4,19,19,17,19,44,11,17,17,2,40,11,0,0,6,88,19,17,126,98,0,0,4,17,15,23,40,54,0,0,10,19,18,17,18,22,254,4,19,20,17,20,44,11,17,18,2,40,11,0,0,6,88,19,18,2,123,48,0,0,4,17,17,17,18,17,16,210,40,53,0,0,10,0,17,15,23,88,19,15,17,15,31,15,254,4,19,21,17,21,58,86,255,255,255,43,0,42,19,48,2,0,126,0,0,0,28,0,0,17,0,3,10,6,23,89,69,4,0,0,0,2,0,0,0,35,0,0,0,86,0,0,0,68,0,0,0,43,84,2,40,9,0,0,6,31,10,50,18,2,40,9,0,0,6,31,27,50,4,31,14,43,2,31,12,43,2,31,10,11,43,62,2,40,9,0,0,6,31,10,50,18,2,40,9,0,0,6,31,27,50,4,31,13,43,2,31,11,43,2,31,9,11,43,29,2,40,9,0,0,6,31,10,50,4,31,16,43,1,30,11,43,11,114,89,10,0,112,115,33,0,0,10,122,7,42,0,0,19,48,4,0,192,0,0,0,7,0,0,17,0,2,40,9,0,0,6,23,89,26,90,2,123,51,0,0,4,88,10,2,126,61,0,0,4,6,22,40,41,0,0,10,125,37,0,0,4,2,126,61,0,0,4,6,23,40,41,0,0,10,125,38,0,0,4,2,126,61,0,0,4,6,24,40,41,0,0,10,125,39,0,0,4,2,126,61,0,0,4,6,25,40,41,0,0,10,125,40,0,0,4,2,2,123,37,0,0,4,2,123,38,0,0,4,90,2,123,39,0,0,4,2,123,40,0,0,4,90,88,125,34,0,0,4,2,30,2,123,34,0,0,4,90,125,35,0,0,4,2,126,55,0,0,4,2,40,9,0,0,6,148,125,33,0,0,4,2,2,123,33,0,0,4,2,123,34,0,0,4,89,2,123,37,0,0,4,2,123,39,0,0,4,88,91,125,36,0,0,4,43,0,42,19,48,8,0,217,2,0,0,29,0,0,17,0,2,2,40,11,0,0,6,27,88,2,40,11,0,0,6,27,88,115,55,0,0,10,125,46,0,0,4,22,11,43,46,22,12,43,29,2,123,46,0,0,4,7,8,126,110,0,0,4,7,8,40,41,0,0,10,40,53,0,0,10,8,23,88,12,8,31,9,254,4,13,9,45,218,7,23,88,11,7,31,9,254,4,19,4,17,4,45,199,2,40,11,0,0,6,30,89,10,22,19,5,43,59,22,19,6,43,37,2,123,46,0,0,4,17,5,6,17,6,88,126,111,0,0,4,17,5,17,6,40,41,0,0,10,40,53,0,0,10,17,6,23,88,19,6,17,6,30,254,4,19,7,17,7,45,208,17,5,23,88,19,5,17,5,31,9,254,4,19,8,17,8,45,185,22,19,9,43,60,22,19,10,43,37,2,123,46,0,0,4,6,17,9,88,17,10,126,112,0,0,4,17,9,17,10,40,41,0,0,10,40,53,0,0,10,17,10,23,88,19,10,17,10,31,9,254,4,19,11,17,11,45,207,17,9,23,88,19,9,17,9,30,254,4,19,12,17,12,45,185,30,19,13,43,49,2,123,46,0,0,4,17,13,28,2,123,46,0,0,4,28,17,13,17,13,23,95,44,3,28,43,1,29,37,19,14,40,53,0,0,10,17,14,40,53,0,0,10,17,13,23,88,19,13,17,13,2,40,11,0,0,6,30,89,254,4,19,15,17,15,45,189,2,40,9,0,0,6,23,254,2,19,16,17,16,57,229,0,0,0,0,126,54,0,0,4,2,40,9,0,0,6,154,19,17,17,17,142,105,19,18,22,19,19,56,184,0,0,0,22,19,20,56,155,0,0,0,0,17,20,45,4,17,19,44,29,17,20,17,18,23,89,51,4,17,19,44,17,17,20,45,10,17,19,17,18,23,89,254,1,43,1,22,43,1,23,19,23,17,23,44,2,43,102,17,17,17,19,145,19,21,17,17,17,20,145,19,22,31,254,19,24,43,70,31,254,19,25,43,47,0,2,123,46,0,0,4,17,21,17,24,88,17,22,17,25,88,126,113,0,0,4,17,24,24,88,17,25,24,88,40,41,0,0,10,40,53,0,0,10,0,17,25,23,88,19,25,17,25,25,254,4,19,26,17,26,45,198,17,24,23,88,19,24,17,24,25,254,4,19,27,17,27,45,175,0,17,20,23,88,19,20,17,20,17,18,254,4,19,28,17,28,58,86,255,255,255,17,19,23,88,19,19,17,19,17,18,254,4,19,29,17,29,58,57,255,255,255,0,2,40,9,0,0,6,29,254,4,22,254,1,19,30,17,30,57,136,0,0,0,0,2,40,11,0,0,6,31,11,89,10,22,19,31,43,46,22,19,32,43,24,2,123,46,0,0,4,17,31,6,17,32,88,24,40,53,0,0,10,17,32,23,88,19,32,17,32,25,254,4,19,33,17,33,45,221,17,31,23,88,19,31,17,31,28,254,4,19,34,17,34,45,199,22,19,35,43,46,22,19,36,43,24,2,123,46,0,0,4,6,17,36,88,17,35,24,40,53,0,0,10,17,36,23,88,19,36,17,36,25,254,4,19,37,17,37,45,221,17,35,23,88,19,35,17,35,28,254,4,19,38,17,38,45,199,0,43,0,42,0,0,0,19,48,2,0,140,0,0,0,7,0,0,17,0,2,2,123,46,0,0,4,111,56,0,0,10,116,4,0,0,27,125,47,0,0,4,3,10,6,69,8,0,0,0,2,0,0,0,11,0,0,0,20,0,0,0,29,0,0,0,38,0,0,0,47,0,0,0,56,0,0,0,65,0,0,0,43,72,2,40,49,0,0,6,0,43,63,2,40,50,0,0,6,0,43,54,2,40,51,0,0,6,0,43,45,2,40,52,0,0,6,0,43,36,2,40,53,0,0,6,0,43,27,2,40,54,0,0,6,0,43,18,2,40,55,0,0,6,0,43,9,2,40,56,0,0,6,0,43,0,43,0,42,19,48,4,0,145,0,0,0,30,0,0,17,0,22,10,43,119,22,11,43,96,0,2,123,47,0,0,4,6,7,40,41,0,0,10,24,95,22,254,1,12,8,44,19,2,123,47,0,0,4,6,7,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,23,88,40,41,0,0,10,24,95,22,254,1,13,9,44,23,2,123,47,0,0,4,6,23,88,7,23,88,40,57,0,0,10,37,71,23,97,210,82,0,7,24,88,11,7,2,40,11,0,0,6,254,4,19,4,17,4,45,145,6,24,88,10,6,2,40,11,0,0,6,254,4,19,5,17,5,58,119,255,255,255,43,0,42,0,0,0,19,48,3,0,89,0,0,0,31,0,0,17,0,22,10,43,66,22,11,43,45,2,123,47,0,0,4,6,7,40,41,0,0,10,24,95,22,254,1,12,8,44,19,2,123,47,0,0,4,6,7,40,57,0,0,10,37,71,23,97,210,82,7,23,88,11,7,2,40,11,0,0,6,254,4,13,9,45,198,6,24,88,10,6,2,40,11,0,0,6,254,4,19,4,17,4,45,175,43,0,42,0,0,0,19,48,3,0,89,0,0,0,31,0,0,17,0,22,10,43,66,22,11,43,45,2,123,47,0,0,4,6,7,40,41,0,0,10,24,95,22,254,1,12,8,44,19,2,123,47,0,0,4,6,7,40,57,0,0,10,37,71,23,97,210,82,7,25,88,11,7,2,40,11,0,0,6,254,4,13,9,45,198,6,23,88,10,6,2,40,11,0,0,6,254,4,19,4,17,4,45,175,43,0,42,0,0,0,19,48,4,0,205,0,0,0,32,0,0,17,0,22,10,56,176,0,0,0,22,11,56,147,0,0,0,0,2,123,47,0,0,4,6,7,40,41,0,0,10,24,95,22,254,1,12,8,44,19,2,123,47,0,0,4,6,7,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,24,88,40,41,0,0,10,24,95,22,254,1,13,9,44,23,2,123,47,0,0,4,6,23,88,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,23,88,40,41,0,0,10,24,95,22,254,1,19,4,17,4,44,23,2,123,47,0,0,4,6,24,88,7,23,88,40,57,0,0,10,37,71,23,97,210,82,0,7,25,88,11,7,2,40,11,0,0,6,254,4,19,5,17,5,58,91,255,255,255,6,25,88,10,6,2,40,11,0,0,6,254,4,19,6,17,6,58,62,255,255,255,43,0,42,0,0,0,19,48,4,0,140,2,0,0,33,0,0,17,0,22,10,56,111,2,0,0,22,11,56,82,2,0,0,0,2,123,47,0,0,4,6,7,40,41,0,0,10,24,95,22,254,1,12,8,44,19,2,123,47,0,0,4,6,7,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,7,23,88,40,41,0,0,10,24,95,22,254,1,13,9,44,21,2,123,47,0,0,4,6,7,23,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,7,24,88,40,41,0,0,10,24,95,22,254,1,19,4,17,4,44,21,2,123,47,0,0,4,6,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,40,41,0,0,10,24,95,22,254,1,19,5,17,5,44,21,2,123,47,0,0,4,6,23,88,7,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,23,88,40,41,0,0,10,24,95,22,254,1,19,6,17,6,44,23,2,123,47,0,0,4,6,23,88,7,23,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,24,88,40,41,0,0,10,24,95,22,254,1,19,7,17,7,44,23,2,123,47,0,0,4,6,23,88,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,8,17,8,44,23,2,123,47,0,0,4,6,24,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,26,88,40,41,0,0,10,24,95,22,254,1,19,9,17,9,44,23,2,123,47,0,0,4,6,24,88,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,27,88,40,41,0,0,10,24,95,22,254,1,19,10,17,10,44,23,2,123,47,0,0,4,6,24,88,7,27,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,11,17,11,44,23,2,123,47,0,0,4,6,25,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,26,88,40,41,0,0,10,24,95,22,254,1,19,12,17,12,44,23,2,123,47,0,0,4,6,25,88,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,27,88,40,41,0,0,10,24,95,22,254,1,19,13,17,13,44,23,2,123,47,0,0,4,6,25,88,7,27,88,40,57,0,0,10,37,71,23,97,210,82,0,7,28,88,11,7,2,40,11,0,0,6,254,4,19,14,17,14,58,156,253,255,255,6,26,88,10,6,2,40,11,0,0,6,254,4,19,15,17,15,58,127,253,255,255,43,0,42,19,48,4,0,146,1,0,0,34,0,0,17,0,22,10,56,117,1,0,0,22,11,56,88,1,0,0,0,22,12,43,49,2,123,47,0,0,4,6,7,8,88,40,41,0,0,10,24,95,22,254,1,13,9,44,21,2,123,47,0,0,4,6,7,8,88,40,57,0,0,10,37,71,23,97,210,82,8,23,88,12,8,28,254,4,19,4,17,4,45,197,23,19,5,43,55,2,123,47,0,0,4,6,17,5,88,7,40,41,0,0,10,24,95,22,254,1,19,6,17,6,44,22,2,123,47,0,0,4,6,17,5,88,7,40,57,0,0,10,37,71,23,97,210,82,17,5,23,88,19,5,17,5,28,254,4,19,7,17,7,45,190,2,123,47,0,0,4,6,24,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,8,17,8,44,23,2,123,47,0,0,4,6,24,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,24,88,40,41,0,0,10,24,95,22,254,1,19,9,17,9,44,23,2,123,47,0,0,4,6,25,88,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,26,88,40,41,0,0,10,24,95,22,254,1,19,10,17,10,44,23,2,123,47,0,0,4,6,25,88,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,26,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,11,17,11,44,23,2,123,47,0,0,4,6,26,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,0,7,28,88,11,7,2,40,11,0,0,6,254,4,19,12,17,12,58,150,254,255,255,6,28,88,10,6,2,40,11,0,0,6,254,4,19,13,17,13,58,121,254,255,255,43,0,42,0,0,19,48,4,0,42,3,0,0,35,0,0,17,0,22,10,56,13,3,0,0,22,11,56,240,2,0,0,0,22,12,43,49,2,123,47,0,0,4,6,7,8,88,40,41,0,0,10,24,95,22,254,1,13,9,44,21,2,123,47,0,0,4,6,7,8,88,40,57,0,0,10,37,71,23,97,210,82,8,23,88,12,8,28,254,4,19,4,17,4,45,197,23,19,5,43,55,2,123,47,0,0,4,6,17,5,88,7,40,41,0,0,10,24,95,22,254,1,19,6,17,6,44,22,2,123,47,0,0,4,6,17,5,88,7,40,57,0,0,10,37,71,23,97,210,82,17,5,23,88,19,5,17,5,28,254,4,19,7,17,7,45,190,2,123,47,0,0,4,6,23,88,7,23,88,40,41,0,0,10,24,95,22,254,1,19,8,17,8,44,23,2,123,47,0,0,4,6,23,88,7,23,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,24,88,40,41,0,0,10,24,95,22,254,1,19,9,17,9,44,23,2,123,47,0,0,4,6,23,88,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,23,88,40,41,0,0,10,24,95,22,254,1,19,10,17,10,44,23,2,123,47,0,0,4,6,24,88,7,23,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,11,17,11,44,23,2,123,47,0,0,4,6,24,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,26,88,40,41,0,0,10,24,95,22,254,1,19,12,17,12,44,23,2,123,47,0,0,4,6,24,88,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,24,88,40,41,0,0,10,24,95,22,254,1,19,13,17,13,44,23,2,123,47,0,0,4,6,25,88,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,26,88,40,41,0,0,10,24,95,22,254,1,19,14,17,14,44,23,2,123,47,0,0,4,6,25,88,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,26,88,7,24,88,40,41,0,0,10,24,95,22,254,1,19,15,17,15,44,23,2,123,47,0,0,4,6,26,88,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,26,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,16,17,16,44,23,2,123,47,0,0,4,6,26,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,26,88,7,27,88,40,41,0,0,10,24,95,22,254,1,19,17,17,17,44,23,2,123,47,0,0,4,6,26,88,7,27,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,27,88,7,26,88,40,41,0,0,10,24,95,22,254,1,19,18,17,18,44,23,2,123,47,0,0,4,6,27,88,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,27,88,7,27,88,40,41,0,0,10,24,95,22,254,1,19,19,17,19,44,23,2,123,47,0,0,4,6,27,88,7,27,88,40,57,0,0,10,37,71,23,97,210,82,0,7,28,88,11,7,2,40,11,0,0,6,254,4,19,20,17,20,58,254,252,255,255,6,28,88,10,6,2,40,11,0,0,6,254,4,19,21,17,21,58,225,252,255,255,43,0,42,0,0,19,48,4,0,186,3,0,0,36,0,0,17,0,22,10,56,157,3,0,0,22,11,56,128,3,0,0,0,2,123,47,0,0,4,6,7,40,41,0,0,10,24,95,22,254,1,12,8,44,19,2,123,47,0,0,4,6,7,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,7,24,88,40,41,0,0,10,24,95,22,254,1,13,9,44,21,2,123,47,0,0,4,6,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,7,26,88,40,41,0,0,10,24,95,22,254,1,19,4,17,4,44,21,2,123,47,0,0,4,6,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,5,17,5,44,23,2,123,47,0,0,4,6,23,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,26,88,40,41,0,0,10,24,95,22,254,1,19,6,17,6,44,23,2,123,47,0,0,4,6,23,88,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,23,88,7,27,88,40,41,0,0,10,24,95,22,254,1,19,7,17,7,44,23,2,123,47,0,0,4,6,23,88,7,27,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,40,41,0,0,10,24,95,22,254,1,19,8,17,8,44,21,2,123,47,0,0,4,6,24,88,7,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,26,88,40,41,0,0,10,24,95,22,254,1,19,9,17,9,44,23,2,123,47,0,0,4,6,24,88,7,26,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,24,88,7,27,88,40,41,0,0,10,24,95,22,254,1,19,10,17,10,44,23,2,123,47,0,0,4,6,24,88,7,27,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,23,88,40,41,0,0,10,24,95,22,254,1,19,11,17,11,44,23,2,123,47,0,0,4,6,25,88,7,23,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,12,17,12,44,23,2,123,47,0,0,4,6,25,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,25,88,7,27,88,40,41,0,0,10,24,95,22,254,1,19,13,17,13,44,23,2,123,47,0,0,4,6,25,88,7,27,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,26,88,7,40,41,0,0,10,24,95,22,254,1,19,14,17,14,44,21,2,123,47,0,0,4,6,26,88,7,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,26,88,7,23,88,40,41,0,0,10,24,95,22,254,1,19,15,17,15,44,23,2,123,47,0,0,4,6,26,88,7,23,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,26,88,7,24,88,40,41,0,0,10,24,95,22,254,1,19,16,17,16,44,23,2,123,47,0,0,4,6,26,88,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,27,88,7,23,88,40,41,0,0,10,24,95,22,254,1,19,17,17,17,44,23,2,123,47,0,0,4,6,27,88,7,23,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,27,88,7,24,88,40,41,0,0,10,24,95,22,254,1,19,18,17,18,44,23,2,123,47,0,0,4,6,27,88,7,24,88,40,57,0,0,10,37,71,23,97,210,82,2,123,47,0,0,4,6,27,88,7,25,88,40,41,0,0,10,24,95,22,254,1,19,19,17,19,44,23,2,123,47,0,0,4,6,27,88,7,25,88,40,57,0,0,10,37,71,23,97,210,82,0,7,28,88,11,7,2,40,11,0,0,6,254,4,19,20,17,20,58,110,252,255,255,6,28,88,10,6,2,40,11,0,0,6,254,4,19,21,17,21,58,81,252,255,255,43,0,42,0,0,19,48,4,0,189,0,0,0,37,0,0,17,0,31,25,141,37,0,0,1,10,6,22,22,156,6,23,22,156,6,24,22,156,6,25,31,13,156,6,26,31,73,156,6,27,31,72,156,6,28,31,68,156,6,29,31,82,156,2,40,13,0,0,6,11,6,30,7,31,24,99,210,156,6,31,9,7,31,16,99,210,156,6,31,10,7,30,99,210,156,6,31,11,7,210,156,6,31,12,7,31,24,99,210,156,6,31,13,7,31,16,99,210,156,6,31,14,7,30,99,210,156,6,31,15,7,210,156,6,31,16,23,156,6,31,17,22,156,6,31,18,22,156,6,31,19,22,156,6,31,20,22,156,6,26,31,17,40,2,0,0,6,12,6,31,21,8,31,24,100,210,156,6,31,22,8,31,16,100,210,156,6,31,23,8,30,100,210,156,6,31,24,8,210,156,6,13,43,0,9,42,0,0,0,19,48,4,0,205,0,0,0,38,0,0,17,0,2,40,63,0,0,6,10,6,142,105,31,12,89,11,6,22,7,31,24,99,210,156,6,23,7,31,16,99,210,156,6,24,7,30,99,210,156,6,25,7,210,156,6,26,31,73,156,6,27,31,68,156,6,28,31,65,156,6,29,31,84,156,2,22,2,142,105,40,1,0,0,6,12,6,142,105,30,89,13,6,9,37,23,88,13,8,31,24,100,210,156,6,9,37,23,88,13,8,31,16,100,210,156,6,9,37,23,88,13,8,30,100,210,156,6,9,8,210,156,6,26,6,142,105,30,89,40,2,0,0,6,19,4,6,142,105,26,89,19,5,6,17,5,37,23,88,19,5,17,4,31,24,100,210,156,6,17,5,37,23,88,19,5,17,4,31,16,100,210,156,6,17,5,37,23,88,19,5,17,4,30,100,210,156,6,17,5,37,23,88,19,5,17,4,210,156,6,19,6,43,0,17,6,42,0,0,0,19,48,6,0,172,1,0,0,39,0,0,17,0,2,40,13,0,0,6,10,6,29,88,30,91,23,88,11,7,6,90,12,8,141,37,0,0,1,13,23,19,4,43,15,9,17,4,32,255,0,0,0,156,17,4,23,88,19,4,17,4,7,254,4,19,6,17,6,45,230,2,40,21,0,0,6,7,90,19,5,43,11,9,17,4,24,156,17,4,7,88,19,4,17,4,17,5,254,4,19,7,17,7,45,233,22,19,8,56,235,0,0,0,0,17,4,7,88,19,5,17,4,23,88,19,9,43,15,9,17,9,32,255,0,0,0,156,17,9,23,88,19,9,17,9,17,5,254,4,19,10,17,10,45,229,22,19,11,43,118,0,2,40,7,0,0,6,17,8,17,11,40,49,0,0,10,22,254,1,19,14,17,14,44,2,43,85,2,40,19,0,0,6,17,11,90,2,40,21,0,0,6,88,19,12,17,12,2,40,19,0,0,6,88,19,13,43,41,0,9,17,4,23,17,12,30,91,88,88,143,37,0,0,1,37,71,23,29,17,12,29,95,89,31,31,95,98,102,210,95,210,82,0,17,12,23,88,19,12,17,12,17,13,254,4,19,15,17,15,45,203,0,17,11,23,88,19,11,17,11,2,40,11,0,0,6,254,4,19,16,17,16,58,119,255,255,255,17,4,2,40,19,0,0,6,7,90,88,19,5,17,4,7,88,19,4,43,11,9,17,4,24,156,17,4,7,88,19,4,17,4,17,5,254,4,19,17,17,17,45,233,0,17,8,23,88,19,8,17,8,2,40,11,0,0,6,254,4,19,18,17,18,58,2,255,255,255,17,4,7,88,19,5,17,4,23,88,19,4,43,15,9,17,4,32,255,0,0,0,156,17,4,23,88,19,4,17,4,17,5,254,4,19,19,17,19,45,229,43,11,9,17,4,24,156,17,4,7,88,19,4,17,4,8,254,4,19,20,17,20,45,234,9,19,21,43,0,17,21,42,118,2,23,125,51,0,0,4,2,24,125,52,0,0,4,2,30,125,53,0,0,4,2,40,58,0,0,10,0,42,186,30,141,37,0,0,1,37,208,150,0,0,4,40,15,0,0,10,128,49,0,0,4,31,12,141,37,0,0,1,37,208,181,0,0,4,40,15,0,0,10,128,50,0,0,4,42,0,0,0,19,48,7,0,84,8,0,0,0,0,0,0,31,41,141,2,0,0,27,37,24,24,141,37,0,0,1,37,22,28,156,37,23,31,18,156,162,37,25,24,141,37,0,0,1,37,22,28,156,37,23,31,22,156,162,37,26,24,141,37,0,0,1,37,22,28,156,37,23,31,26,156,162,37,27,24,141,37,0,0,1,37,22,28,156,37,23,31,30,156,162,37,28,24,141,37,0,0,1,37,22,28,156,37,23,31,34,156,162,37,29,25,141,37,0,0,1,37,208,177,0,0,4,40,15,0,0,10,162,37,30,25,141,37,0,0,1,37,208,184,0,0,4,40,15,0,0,10,162,37,31,9,25,141,37,0,0,1,37,208,134,0,0,4,40,15,0,0,10,162,37,31,10,25,141,37,0,0,1,37,208,114,0,0,4,40,15,0,0,10,162,37,31,11,25,141,37,0,0,1,37,208,148,0,0,4,40,15,0,0,10,162,37,31,12,25,141,37,0,0,1,37,208,187,0,0,4,40,15,0,0,10,162,37,31,13,25,141,37,0,0,1,37,208,165,0,0,4,40,15,0,0,10,162,37,31,14,26,141,37,0,0,1,37,208,156,0,0,4,40,15,0,0,10,162,37,31,15,26,141,37,0,0,1,37,208,132,0,0,4,40,15,0,0,10,162,37,31,16,26,141,37,0,0,1,37,208,151,0,0,4,40,15,0,0,10,162,37,31,17,26,141,37,0,0,1,37,208,186,0,0,4,40,15,0,0,10,162,37,31,18,26,141,37,0,0,1,37,208,168,0,0,4,40,15,0,0,10,162,37,31,19,26,141,37,0,0,1,37,208,125,0,0,4,40,15,0,0,10,162,37,31,20,26,141,37,0,0,1,37,208,117,0,0,4,40,15,0,0,10,162,37,31,21,27,141,37,0,0,1,37,208,153,0,0,4,40,15,0,0,10,162,37,31,22,27,141,37,0,0,1,37,208,183,0,0,4,40,15,0,0,10,162,37,31,23,27,141,37,0,0,1,37,208,179,0,0,4,40,15,0,0,10,162,37,31,24,27,141,37,0,0,1,37,208,120,0,0,4,40,15,0,0,10,162,37,31,25,27,141,37,0,0,1,37,208,192,0,0,4,40,15,0,0,10,162,37,31,26,27,141,37,0,0,1,37,208,122,0,0,4,40,15,0,0,10,162,37,31,27,27,141,37,0,0,1,37,208,178,0,0,4,40,15,0,0,10,162,37,31,28,28,141,37,0,0,1,37,208,163,0,0,4,40,15,0,0,10,162,37,31,29,28,141,37,0,0,1,37,208,194,0,0,4,40,15,0,0,10,162,37,31,30,28,141,37,0,0,1,37,208,170,0,0,4,40,15,0,0,10,162,37,31,31,28,141,37,0,0,1,37,208,133,0,0,4,40,15,0,0,10,162,37,31,32,28,141,37,0,0,1,37,208,169,0,0,4,40,15,0,0,10,162,37,31,33,28,141,37,0,0,1,37,208,193,0,0,4,40,15,0,0,10,162,37,31,34,28,141,37,0,0,1,37,208,115,0,0,4,40,15,0,0,10,162,37,31,35,29,141,37,0,0,1,37,208,164,0,0,4,40,15,0,0,10,162,37,31,36,29,141,37,0,0,1,37,208,175,0,0,4,40,15,0,0,10,162,37,31,37,29,141,37,0,0,1,37,208,139,0,0,4,40,15,0,0,10,162,37,31,38,29,141,37,0,0,1,37,208,136,0,0,4,40,15,0,0,10,162,37,31,39,29,141,37,0,0,1,37,208,130,0,0,4,40,15,0,0,10,162,37,31,40,29,141,37,0,0,1,37,208,123,0,0,4,40,15,0,0,10,162,128,54,0,0,4,31,41,141,32,0,0,1,37,208,147,0,0,4,40,15,0,0,10,128,55,0,0,4,32,0,1,0,0,141,37,0,0,1,37,208,189,0,0,4,40,15,0,0,10,128,56,0,0,4,32,160,0,0,0,26,115,55,0,0,10,37,208,143,0,0,4,40,15,0,0,10,128,61,0,0,4,29,141,37,0,0,1,37,208,176,0,0,4,40,15,0,0,10,128,62,0,0,4,31,10,141,37,0,0,1,37,208,144,0,0,4,40,15,0,0,10,128,63,0,0,4,31,13,141,37,0,0,1,37,208,180,0,0,4,40,15,0,0,10,128,64,0,0,4,31,15,141,37,0,0,1,37,208,159,0,0,4,40,15,0,0,10,128,65,0,0,4,31,16,141,37,0,0,1,37,208,140,0,0,4,40,15,0,0,10,128,66,0,0,4,31,17,141,37,0,0,1,37,208,172,0,0,4,40,15,0,0,10,128,67,0,0,4,31,18,141,37,0,0,1,37,208,118,0,0,4,40,15,0,0,10,128,68,0,0,4,31,20,141,37,0,0,1,37,208,157,0,0,4,40,15,0,0,10,128,69,0,0,4,31,22,141,37,0,0,1,37,208,155,0,0,4,40,15,0,0,10,128,70,0,0,4,31,24,141,37,0,0,1,37,208,191,0,0,4,40,15,0,0,10,128,71,0,0,4,31,26,141,37,0,0,1,37,208,152,0,0,4,40,15,0,0,10,128,72,0,0,4,31,28,141,37,0,0,1,37,208,119,0,0,4,40,15,0,0,10,128,73,0,0,4,31,30,141,37,0,0,1,37,208,146,0,0,4,40,15,0,0,10,128,74,0,0,4,31,32,141,37,0,0,1,37,208,149,0,0,4,40,15,0,0,10,128,75,0,0,4,31,34,141,37,0,0,1,37,208,171,0,0,4,40,15,0,0,10,128,76,0,0,4,31,36,141,37,0,0,1,37,208,182,0,0,4,40,15,0,0,10,128,77,0,0,4,31,40,141,37,0,0,1,37,208,121,0,0,4,40,15,0,0,10,128,78,0,0,4,31,42,141,37,0,0,1,37,208,116,0,0,4,40,15,0,0,10,128,79,0,0,4,31,44,141,37,0,0,1,37,208,188,0,0,4,40,15,0,0,10,128,80,0,0,4,31,46,141,37,0,0,1,37,208,128,0,0,4,40,15,0,0,10,128,81,0,0,4,31,48,141,37,0,0,1,37,208,185,0,0,4,40,15,0,0,10,128,82,0,0,4,31,50,141,37,0,0,1,37,208,161,0,0,4,40,15,0,0,10,128,83,0,0,4,31,52,141,37,0,0,1,37,208,154,0,0,4,40,15,0,0,10,128,84,0,0,4,31,54,141,37,0,0,1,37,208,127,0,0,4,40,15,0,0,10,128,85,0,0,4,31,56,141,37,0,0,1,37,208,190,0,0,4,40,15,0,0,10,128,86,0,0,4,31,58,141,37,0,0,1,37,208,124,0,0,4,40,15,0,0,10,128,87,0,0,4,31,60,141,37,0,0,1,37,208,131,0,0,4,40,15,0,0,10,128,88,0,0,4,31,62,141,37,0,0,1,37,208,174,0,0,4,40,15,0,0,10,128,89,0,0,4,31,64,141,37,0,0,1,37,208,167,0,0,4,40,15,0,0,10,128,90,0,0,4,31,66,141,37,0,0,1,37,208,126,0,0,4,40,15,0,0,10,128,91,0,0,4,31,68,141,37,0,0,1,37,208,162,0,0,4,40,15,0,0,10,128,92,0,0,4,31,62,141,2,0,0,27,37,22,126,62,0,0,4,162,37,25,126,63,0,0,4,162,37,28,126,64,0,0,4,162,37,30,126,65,0,0,4,162,37,31,9,126,66,0,0,4,162,37,31,10,126,67,0,0,4,162,37,31,11,126,68,0,0,4,162,37,31,13,126,69,0,0,4,162,37,31,15,126,70,0,0,4,162,37,31,17,126,71,0,0,4,162,37,31,19,126,72,0,0,4,162,37,31,21,126,73,0,0,4,162,37,31,23,126,74,0,0,4,162,37,31,25,126,75,0,0,4,162,37,31,27,126,76,0,0,4,162,37,31,29,126,77,0,0,4,162,37,31,33,126,78,0,0,4,162,37,31,35,126,79,0,0,4,162,37,31,37,126,80,0,0,4,162,37,31,39,126,81,0,0,4,162,37,31,41,126,82,0,0,4,162,37,31,43,126,83,0,0,4,162,37,31,45,126,84,0,0,4,162,37,31,47,126,85,0,0,4,162,37,31,49,126,86,0,0,4,162,37,31,51,126,87,0,0,4,162,37,31,53,126,88,0,0,4,162,37,31,55,126,89,0,0,4,162,37,31,57,126,90,0,0,4,162,37,31,59,126,91,0,0,4,162,37,31,61,126,92,0,0,4,162,128,93,0,0,4,32,255,1,0,0,141,37,0,0,1,37,208,173,0,0,4,40,15,0,0,10,128,94,0,0,4,32,0,1,0,0,141,37,0,0,1,37,208,166,0,0,4,40,15,0,0,10,128,95,0,0,4,31,32,141,32,0,0,1,37,208,145,0,0,4,40,15,0,0,10,128,96,0,0,4,31,15,24,115,59,0,0,10,37,208,129,0,0,4,40,15,0,0,10,128,97,0,0,4,31,15,24,115,59,0,0,10,37,208,141,0,0,4,40,15,0,0,10,128,98,0,0,4,31,34,141,32,0,0,1,37,208,142,0,0,4,40,15,0,0,10,128,99,0,0,4,31,9,31,9,115,55,0,0,10,37,208,138,0,0,4,40,15,0,0,10,128,110,0,0,4,31,9,30,115,55,0,0,10,37,208,160,0,0,4,40,15,0,0,10,128,111,0,0,4,30,31,9,115,55,0,0,10,37,208,158,0,0,4,40,15,0,0,10,128,112,0,0,4,27,27,115,55,0,0,10,37,208,135,0,0,4,40,15,0,0,10,128,113,0,0,4,42,19,48,4,0,110,0,0,0,40,0,0,17,0,2,142,105,10,115,60,0,0,10,11,7,23,23,115,61,0,0,10,12,8,2,22,6,111,62,0,0,10,0,8,111,63,0,0,10,0,7,111,64,0,0,10,105,13,9,31,18,88,141,37,0,0,1,19,4,17,4,30,31,120,156,17,4,31,9,32,156,0,0,0,156,7,22,106,22,111,65,0,0,10,38,7,17,4,31,10,9,111,66,0,0,10,38,7,111,63,0,0,10,0,17,4,19,5,43,0,17,5,42,0,0,19,48,2,0,46,0,0,0,41,0,0,17,2,44,41,32,197,157,28,129,10,22,11,43,20,2,7,111,20,0,0,10,6,97,32,147,1,0,1,90,10,7,23,88,11,7,2,111,19,0,0,10,47,2,43,225,6,42,0,0,66,83,74,66,1,0,1,0,0,0,0,0,12,0,0,0,118,52,46,48,46,51,48,51,49,57,0,0,0,0,5,0,108,0,0,0,204,21,0,0,35,126,0,0,56,22,0,0,180,32,0,0,35,83,116,114,105,110,103,115,0,0,0,0,236,54,0,0,132,10,0,0,35,85,83,0,112,65,0,0,16,0,0,0,35,71,85,73,68,0,0,0,128,65,0,0,20,8,0,0,35,66,108,111,98,0,0,0,0,0,0,0,2,0,0,1,87,157,162,41,9,2,0,0,0,250,1,51,0,22,0,0,1,0,0,0,46,0,0,0,56,0,0,0,194,0,0,0,64,0,0,0,37,0,0,0,66,0,0,0,35,0,0,0,33,0,0,0,46,0,0,0,41,0,0,0,1,0,0,0,8,0,0,0,16,0,0,0,5,0,0,0,81,0,0,0,1,0,0,0,1,0,0,0,46,0,0,0,0,0,227,26,1,0,0,0,0,0,6,0,26,25,216,29,6,0,135,25,216,29,6,0,60,24,150,29,15,0,248,29,0,0,6,0,130,24,8,26,6,0,110,25,60,28,6,0,222,24,60,28,6,0,83,25,60,28,6,0,253,24,60,28,6,0,155,24,60,28,6,0,184,24,60,28,6,0,58,25,60,28,6,0,107,24,60,28,6,0,218,30,51,27,6,0,198,3,211,21,6,0,58,27,51,27,6,0,33,24,216,29,6,0,227,23,150,29,6,0,80,24,150,29,6,0,44,27,127,21,6,0,82,29,127,21,6,0,38,27,127,21,6,0,11,27,242,27,6,0,167,23,51,27,6,0,149,4,51,27,6,0,106,30,216,29,6,0,122,32,51,27,6,0,53,23,51,27,6,0,34,26,51,27,6,0,28,29,51,27,6,0,186,28,51,27,6,0,150,4,51,27,6,0,165,28,51,27,6,0,87,23,127,21,6,0,143,28,51,27,6,0,255,25,133,31,6,0,165,25,51,27,6,0,204,28,51,27,6,0,0,27,127,21,6,0,211,22,127,21,6,0,121,30,127,21,6,0,177,23,127,21,6,0,41,23,51,27,6,0,75,26,51,27,6,0,249,22,242,27,6,0,85,27,127,21,0,0,0,0,39,17,0,0,0,0,1,0,1,0,128,1,16,0,129,4,133,32,57,0,1,0,1,0,128,1,16,0,123,4,133,32,57,0,1,0,2,0,129,1,16,0,115,23,133,32,57,0,2,0,4,0,1,1,0,0,127,28,133,32,65,0,3,0,7,0,1,1,0,0,236,22,133,32,65,0,8,0,7,0,1,0,16,0,62,29,133,32,57,0,25,0,7,0,128,1,16,0,7,30,133,32,57,0,54,0,62,0,128,1,16,0,8,28,133,32,57,0,114,0,63,0,0,1,0,0,48,17,0,0,57,0,114,0,64,0,19,1,0,0,184,7,0,0,97,0,195,0,65,0,19,1,0,0,233,10,0,0,97,0,195,0,65,0,19,1,0,0,15,13,0,0,97,0,195,0,65,0,19,1,0,0,135,14,0,0,97,0,195,0,65,0,19,1,0,0,1,0,0,0,97,0,195,0,65,0,19,1,0,0,14,4,0,0,97,0,195,0,65,0,19,1,0,0,143,6,0,0,97,0,195,0,65,0,19,1,0,0,71,10,0,0,97,0,195,0,65,0,19,1,0,0,57,11,0,0,97,0,195,0,65,0,19,1,0,0,145,13,0,0,97,0,195,0,65,0,19,1,0,0,20,15,0,0,97,0,195,0,65,0,19,1,0,0,82,0,0,0,97,0,195,0,65,0,19,1,0,0,53,4,0,0,97,0,195,0,65,0,19,1,0,0,152,8,0,0,97,0,195,0,65,0,19,1,0,0,122,10,0,0,97,0,195,0,65,0,19,1,0,0,98,11,0,0,97,0,195,0,65,0,19,1,0,0,91,15,0,0,97,0,195,0,65,0,19,1,0,0,123,0,0,0,97,0,195,0,65,0,19,1,0,0,94,4,0,0,97,0,195,0,65,0,19,1,0,0,193,8,0,0,97,0,195,0,65,0,19,1,0,0,169,11,0,0,97,0,195,0,65,0,19,1,0,0,194,0,0,0,97,0,195,0,65,0,19,1,0,0,156,4,0,0,97,0,195,0,65,0,19,1,0,0,234,8,0,0,97,0,195,0,65,0,19,1,0,0,251,11,0,0,97,0,195,0,65,0,19,1,0,0,132,15,0,0,97,0,195,0,65,0,19,1,0,0,235,0,0,0,97,0,195,0,65,0,19,1,0,0,238,4,0,0,97,0,195,0,65,0,19,1,0,0,19,9,0,0,97,0,195,0,65,0,19,1,0,0,66,12,0,0,97,0,195,0,65,0,19,1,0,0,173,15,0,0,97,0,195,0,65,0,19,1,0,0,61,1,0,0,97,0,195,0,65,0,19,1,0,0,64,5,0,0,97,0,195,0,65,0,19,1,0,0,90,9,0,0,97,0,195,0,65,0,19,1,0,0,148,12,0,0,97,0,195,0,65,0,19,1,0,0,255,15,0,0,97,0,195,0,65,0,19,1,0,0,146,5,0,0,97,0,195,0,65,0,19,1,0,0,92,3,0,0,97,0,195,0,65,0,19,1,0,0,52,0,0,0,97,0,195,0,65,0,19,1,0,0,61,15,0,0,97,0,195,0,65,0,19,1,0,0,139,11,0,0,97,0,195,0,65,0,19,1,0,0,60,9,0,0,97,0,195,0,65,0,19,1,0,0,36,12,0,0,97,0,195,0,65,0,19,1,0,0,144,2,0,0,97,0,195,0,65,0,19,1,0,0,164,0,0,0,97,0,195,0,65,0,19,1,0,0,121,8,0,0,97,0,195,0,65,0,17,0,16,23,68,4,54,0,8,29,162,0,6,6,139,21,72,4,86,128,123,21,75,4,86,128,125,21,75,4,86,128,137,21,75,4,86,128,121,21,75,4,6,6,139,21,72,4,86,128,103,29,79,4,86,128,203,21,79,4,86,128,198,21,79,4,86,128,155,22,79,4,86,128,165,25,79,4,86,128,123,31,79,4,86,128,95,13,79,4,86,128,215,14,79,4,86,128,134,26,79,4,86,128,162,22,79,4,86,128,30,0,79,4,86,128,174,2,79,4,86,128,43,4,79,4,86,128,172,6,79,4,86,128,111,8,79,4,86,128,100,10,79,4,86,128,33,29,162,0,1,0,125,22,83,4,1,0,94,22,72,4,1,0,23,22,72,4,1,0,56,22,72,4,1,0,253,21,72,4,3,0,16,32,92,4,3,0,149,30,72,4,3,0,203,29,72,4,3,0,169,29,72,4,3,0,165,30,72,4,3,0,186,29,72,4,3,0,1,4,72,4,3,0,237,3,72,4,3,0,130,6,72,4,3,0,110,6,72,4,3,0,220,22,97,4,3,0,113,32,102,4,3,0,137,29,72,4,3,0,72,29,106,4,3,0,72,27,72,4,3,0,204,31,109,4,3,0,215,31,109,4,3,0,226,31,109,4,49,0,187,23,102,4,49,0,178,26,102,4,1,0,101,28,75,4,1,0,194,25,72,4,1,0,150,23,72,4,51,0,38,32,92,4,51,0,110,32,118,4,51,0,27,23,102,4,83,128,184,3,72,4,83,128,162,3,72,4,83,128,64,6,72,4,83,128,42,6,72,4,51,0,238,28,109,4,49,0,224,14,102,4,49,0,40,0,102,4,49,0,182,6,102,4,49,0,110,10,102,4,49,0,86,11,102,4,49,0,174,13,102,4,49,0,49,15,102,4,49,0,111,0,102,4,49,0,82,4,102,4,49,0,181,8,102,4,49,0,127,11,102,4,49,0,120,15,102,4,49,0,152,0,102,4,49,0,137,4,102,4,49,0,222,8,102,4,49,0,198,11,102,4,49,0,223,0,102,4,49,0,185,4,102,4,49,0,7,9,102,4,49,0,24,12,102,4,49,0,161,15,102,4,49,0,8,1,102,4,49,0,11,5,102,4,49,0,48,9,102,4,49,0,136,12,102,4,49,0,202,15,102,4,49,0,90,1,102,4,49,0,93,5,102,4,49,0,119,9,102,4,49,0,218,12,102,4,49,0,28,16,102,4,51,0,29,32,92,4,51,0,96,31,102,4,51,0,13,29,102,4,51,0,69,32,118,4,51,0,101,23,122,4,51,0,250,28,122,4,51,0,239,31,118,4,83,128,21,24,131,4,83,128,167,26,131,4,83,128,190,21,131,4,83,128,247,21,131,4,83,128,250,23,131,4,83,128,140,26,131,4,83,128,15,24,131,4,83,128,161,26,131,4,83,128,4,24,131,4,83,128,150,26,131,4,51,0,1,31,109,4,51,0,68,31,109,4,51,0,233,30,109,4,51,0,221,28,109,4,51,1,141,19,134,4,51,1,5,11,138,4,51,1,59,19,142,4,51,1,104,13,72,4,51,1,254,20,147,4,51,1,12,14,151,4,51,1,172,9,155,4,51,1,90,16,159,4,51,1,227,13,155,4,51,1,161,17,164,4,51,1,235,14,168,4,51,1,29,8,72,4,51,1,143,7,173,4,51,1,51,3,178,4,51,1,69,18,183,4,51,1,184,2,188,4,51,1,10,3,164,4,51,1,254,16,193,4,51,1,177,12,72,4,51,1,70,8,138,4,51,1,49,16,134,4,51,1,121,3,198,4,51,1,43,13,164,4,51,1,20,7,202,4,51,1,223,19,207,4,51,1,51,2,164,4,51,1,80,21,212,4,51,1,105,5,188,4,51,1,100,19,216,4,51,1,61,7,221,4,51,1,210,11,226,4,51,1,243,17,230,4,51,1,172,20,235,4,51,1,8,20,239,4,51,1,225,2,134,4,51,1,163,14,244,4,51,1,30,10,248,4,51,1,102,7,72,4,51,1,102,1,251,4,51,1,175,5,155,4,51,1,1,6,255,4,51,1,131,9,4,5,51,1,94,14,72,4,51,1,214,15,8,5,51,1,131,20,12,5,51,1,20,1,17,5,51,1,151,10,12,5,51,1,192,10,21,5,51,1,202,17,26,5,51,1,90,20,138,4,51,1,92,2,164,4,51,1,213,20,134,4,51,1,225,1,31,5,51,1,230,12,36,5,51,1,186,13,72,4,51,1,10,2,138,4,51,1,95,12,138,4,51,1,28,18,41,5,51,1,120,17,45,5,51,1,131,16,49,5,51,1,212,7,54,5,51,1,79,17,164,4,51,1,213,16,164,4,51,1,213,9,134,4,51,1,184,1,155,4,51,1,197,4,155,4,51,1,18,19,59,5,51,1,192,18,63,5,51,1,233,18,67,5,51,1,23,5,155,4,51,1,151,18,134,4,51,1,143,1,71,5,51,1,216,5,72,4,51,1,235,6,134,4,51,1,110,18,76,5,51,1,172,16,31,5,51,1,53,14,81,5,51,1,182,19,86,5,51,1,49,20,155,4,51,1,39,21,138,4,51,1,194,6,138,4,80,32,0,0,0,0,147,0,63,27,90,5,1,0,196,32,0,0,0,0,147,0,63,27,90,5,4,0,4,33,0,0,0,0,145,24,130,29,98,5,7,0,32,33,0,0,0,0,150,0,9,23,102,5,7,0,40,34,0,0,0,0,150,0,9,23,107,5,8,0,121,38,0,0,0,0,145,24,130,29,98,5,9,0,133,38,0,0,0,0,134,8,165,31,113,5,9,0,141,38,0,0,0,0,131,8,182,31,123,5,9,0,150,38,0,0,0,0,134,8,206,27,85,0,10,0,158,38,0,0,0,0,131,8,224,27,1,0,10,0,167,38,0,0,0,0,134,8,116,27,85,0,11,0,175,38,0,0,0,0,131,8,136,27,1,0,11,0,184,38,0,0,0,0,134,8,156,27,85,0,12,0,192,38,0,0,0,0,131,8,181,27,1,0,12,0,201,38,0,0,0,0,134,8,185,22,85,0,13,0,209,38,0,0,0,0,131,8,198,22,1,0,13,0,220,38,0,0,0,0,134,8,78,28,134,5,14,0,244,38,0,0,0,0,134,8,98,28,139,5,14,0,40,39,0,0,0,0,134,8,176,25,85,0,15,0,64,39,0,0,0,0,134,8,191,25,1,0,15,0,168,39,0,0,0,0,134,8,133,23,85,0,16,0,192,39,0,0,0,0,134,8,147,23,1,0,16,0,28,40,0,0,0,0,134,0,9,23,16,0,17,0,96,40,0,0,0,0,134,0,9,23,145,5,18,0,244,40,0,0,0,0,134,0,9,23,151,5,19,0,48,41,0,0,0,0,134,0,9,23,157,5,20,0,132,42,0,0,0,0,134,0,72,23,16,0,21,0,16,43,0,0,0,0,134,0,72,23,93,1,22,0,160,43,0,0,0,0,134,0,64,30,113,5,23,0,164,44,0,0,0,0,131,0,45,28,6,0,23,0,196,46,0,0,0,0,131,0,147,21,6,0,23,0,88,49,0,0,0,0,131,0,85,32,24,1,23,0,232,49,0,0,0,0,131,0,118,28,6,0,25,0,236,50,0,0,0,0,147,0,96,27,164,5,25,0,96,51,0,0,0,0,131,0,47,30,6,0,29,0,20,53,0,0,0,0,131,0,171,21,6,0,29,0,64,54,0,0,0,0,131,0,191,26,6,0,29,0,252,54,0,0,0,0,131,0,216,3,85,0,29,0,68,56,0,0,0,0,131,0,89,6,85,0,29,0,52,57,0,0,0,0,131,0,8,8,85,0,29,0,24,59,0,0,0,0,131,0,9,10,85,0,29,0,236,59,0,0,0,0,131,0,44,31,137,1,29,0,116,60,0,0,0,0,131,0,22,31,137,1,31,0,252,60,0,0,0,0,131,0,24,28,6,0,33,0,208,62,0,0,0,0,131,0,177,30,174,5,33,0,92,63,0,0,0,0,131,0,91,26,6,0,34,0,40,64,0,0,0,0,131,0,199,31,6,0,34,0,16,67,0,0,0,0,131,0,206,26,1,0,34,0,168,67,0,0,0,0,131,0,133,2,6,0,35,0,72,68,0,0,0,0,131,0,205,3,6,0,35,0,176,68,0,0,0,0,131,0,78,6,6,0,35,0,24,69,0,0,0,0,131,0,253,7,6,0,35,0,244,69,0,0,0,0,131,0,254,9,6,0,35,0,140,72,0,0,0,0,131,0,46,11,6,0,35,0,44,74,0,0,0,0,131,0,84,13,6,0,35,0,100,77,0,0,0,0,131,0,204,14,6,0,35,0,44,81,0,0,0,0,129,0,47,29,180,5,35,0,248,81,0,0,0,0,147,0,158,21,185,5,35,0,212,82,0,0,0,0,131,0,237,25,180,5,36,0,140,84,0,0,0,0,134,24,124,29,6,0,36,0,170,84,0,0,0,0,145,24,130,29,98,5,36,0,220,84,0,0,0,0,145,24,130,29,98,5,36,0,60,93,0,0,0,0,147,0,140,30,185,5,36,0,184,93,0,0,0,0,147,0,51,26,192,5,37,0,0,0,1,0,75,29,0,0,2,0,92,30,0,0,3,0,81,27,0,0,1,0,75,29,0,0,2,0,92,30,0,0,3,0,81,27,0,0,1,0,121,23,0,0,1,0,42,30,0,0,1,0,170,25,0,0,1,0,170,25,0,0,1,0,170,25,0,0,1,0,170,25,0,0,1,0,170,25,0,0,1,0,170,25,0,0,1,0,170,25,0,0,1,0,170,25,0,0,1,0,105,31,0,0,1,0,192,30,0,0,1,0,223,25,0,0,1,0,16,32,0,0,1,0,92,23,0,0,1,0,25,27,0,0,1,0,193,21,0,0,2,0,187,30,0,0,1,0,216,26,0,0,2,0,114,26,0,0,3,0,114,29,0,0,4,0,186,29,0,0,1,0,157,31,0,0,2,0,252,26,0,0,1,0,157,31,0,0,2,0,252,26,0,0,1,0,236,22,0,0,1,0,211,26,0,0,1,0,214,25,0,0,1,0,214,25,0,0,1,0,209,30,9,0,124,29,1,0,17,0,124,29,6,0,25,0,124,29,10,0,41,0,124,29,16,0,49,0,124,29,16,0,57,0,124,29,16,0,65,0,124,29,16,0,73,0,124,29,16,0,81,0,124,29,16,0,89,0,124,29,16,0,97,0,124,29,16,0,105,0,124,29,16,0,137,0,124,29,6,0,153,0,124,29,21,0,209,0,0,32,42,0,233,0,206,25,67,0,233,0,90,31,72,0,12,0,124,29,6,0,233,0,80,26,85,0,233,0,96,30,89,0,233,0,206,25,94,0,249,0,124,29,16,0,233,0,41,26,100,0,12,0,243,21,106,0,12,0,61,32,112,0,233,0,211,30,151,0,233,0,41,26,157,0,233,0,174,32,162,0,233,0,95,29,165,0,233,0,154,32,169,0,1,1,218,23,175,0,233,0,211,30,182,0,9,1,124,29,16,0,17,1,145,31,189,0,17,1,20,30,194,0,233,0,166,32,224,0,25,1,124,29,16,0,33,1,40,16,229,0,33,1,33,30,235,0,28,0,124,29,24,1,36,0,225,30,38,1,28,0,229,30,44,1,233,0,125,26,59,1,57,1,124,29,67,1,89,1,210,23,6,0,169,0,124,29,93,1,169,0,27,24,99,1,169,0,69,26,6,0,28,0,225,30,137,1,97,1,161,31,219,1,217,0,128,32,225,1,217,0,22,29,236,1,36,0,229,30,35,2,44,0,225,30,157,2,36,0,124,29,24,1,217,0,161,23,212,2,36,0,132,30,225,2,113,0,124,29,6,0,44,0,124,29,24,1,177,0,124,29,6,0,185,0,124,29,141,3,161,0,27,24,99,1,161,0,204,23,6,0,161,0,80,26,151,3,161,0,173,26,155,3,161,0,238,21,163,3,8,0,16,0,185,3,8,0,20,0,190,3,8,0,24,0,195,3,8,0,28,0,200,3,8,0,36,0,185,3,8,0,40,0,190,3,8,0,44,0,195,3,8,0,48,0,200,3,8,0,52,0,205,3,8,0,56,0,210,3,8,0,60,0,215,3,8,0,64,0,220,3,8,0,68,0,225,3,8,0,72,0,230,3,8,0,76,0,235,3,8,0,80,0,240,3,8,0,84,0,245,3,8,0,88,0,250,3,8,0,92,0,255,3,8,0,96,0,4,4,14,0,100,0,9,4,8,0,228,0,185,3,8,0,232,0,190,3,8,0,236,0,195,3,8,0,240,0,200,3,5,0,144,1,54,4,5,0,148,1,56,4,5,0,152,1,58,4,5,0,156,1,60,4,5,0,160,1,54,4,5,0,164,1,56,4,5,0,168,1,58,4,5,0,172,1,62,4,5,0,176,1,64,4,5,0,180,1,66,4,46,0,11,0,216,5,46,0,19,0,225,5,46,0,27,0,0,6,46,0,35,0,9,6,46,0,43,0,64,6,46,0,51,0,80,6,46,0,59,0,91,6,46,0,67,0,146,6,46,0,75,0,217,7,46,0,83,0,230,7,46,0,91,0,241,7,46,0,99,0,241,7,224,0,107,0,190,3,0,1,107,0,190,3,32,1,107,0,190,3,64,1,107,0,190,3,67,1,107,0,190,3,96,1,107,0,190,3,128,1,107,0,190,3,160,1,107,0,190,3,192,1,107,0,190,3,224,1,107,0,190,3,0,2,107,0,190,3,65,3,107,0,190,3,65,3,115,0,11,8,97,3,107,0,190,3,97,3,115,0,11,8,129,3,107,0,190,3,129,3,115,0,11,8,161,3,107,0,190,3,161,3,115,0,11,8,193,3,107,0,190,3,193,3,115,0,11,8,1,0,3,0,0,0,11,0,1,0,5,0,0,0,12,0,1,0,6,0,0,0,13,0,1,0,7,0,0,0,14,0,1,0,10,0,0,0,15,0,1,0,12,0,0,0,16,0,1,0,13,0,0,0,17,0,1,0,15,0,0,0,18,0,1,0,16,0,0,0,19,0,1,0,17,0,0,0,20,0,1,0,18,0,0,0,21,0,1,0,20,0,0,0,22,0,1,0,22,0,0,0,23,0,1,0,24,0,0,0,24,0,1,0,25,0,0,0,25,0,1,0,26,0,0,0,26,0,1,0,28,0,0,0,27,0,1,0,30,0,0,0,28,0,1,0,32,0,0,0,29,0,1,0,34,0,0,0,30,0,1,0,36,0,0,0,31,0,1,0,40,0,0,0,32,0,1,0,42,0,0,0,33,0,1,0,44,0,0,0,34,0,1,0,46,0,0,0,35,0,1,0,48,0,0,0,36,0,1,0,50,0,0,0,37,0,1,0,52,0,0,0,38,0,1,0,54,0,0,0,39,0,1,0,56,0,0,0,40,0,1,0,58,0,0,0,41,0,1,0,60,0,0,0,42,0,1,0,62,0,0,0,43,0,1,0,64,0,0,0,44,0,1,0,66,0,0,0,45,0,1,0,68,0,0,0,46,0,1,0,72,0,0,0,47,0,1,0,81,0,0,0,48,0,1,0,120,0,0,0,49,0,1,0,128,0,0,0,50,0,1,0,136,0,0,0,51,0,1,0,164,0,0,0,52,0,1,0,0,1,0,0,53,0,1,0,255,1,0,0,54,0,1,0,128,2,0,0,55,0,1,0,0,4,0,0,56,0,27,0,36,0,50,0,118,0,200,0,205,0,209,0,213,0,218,0,244,0,0,1,51,1,81,1,107,1,143,1,171,1,198,1,203,1,244,1,254,1,20,2,42,2,53,2,74,2,85,2,110,2,123,2,163,2,169,2,216,2,232,2,240,2,250,2,13,3,30,3,55,3,80,3,89,3,101,3,128,3,171,3,7,0,1,0,0,0,186,31,197,5,0,0,228,27,207,5,0,0,140,27,207,5,0,0,185,27,207,5,0,0,202,22,207,5,0,0,127,28,211,5,0,0,195,25,207,5,0,0,151,23,207,5,2,0,7,0,3,0,1,0,8,0,3,0,2,0,9,0,5,0,1,0,10,0,5,0,2,0,11,0,7,0,1,0,12,0,7,0,2,0,13,0,9,0,1,0,14,0,9,0,2,0,15,0,11,0,1,0,16,0,11,0,2,0,17,0,13,0,1,0,18,0,13,0,2,0,19,0,15,0,1,0,20,0,15,0,2,0,21,0,17,0,1,0,22,0,17,0,79,0,241,0,16,1,30,1,149,2,0,169,0,0,114,0,8,169,0,0,115,0,16,169,0,0,116,0,64,169,0,0,117,0,72,169,0,0,118,0,96,169,0,0,119,0,128,169,0,0,120,0,136,169,0,0,121,0,176,169,0,0,122,0,184,169,0,0,123,0,192,169,0,0,124,0,0,170,0,0,125,0,8,170,0,0,126,0,80,170,0,0,127,0,136,170,0,0,128,0,184,170,0,0,129,0,48,171,0,0,130,0,56,171,0,0,131,0,120,171,0,0,132,0,128,171,0,0,133,0,136,171,0,0,134,0,144,171,0,0,135,0,176,171,0,0,136,0,184,171,0,0,137,0,184,175,0,0,138,0,16,176,0,0,139,0,24,176,0,0,140,0,40,176,0,0,141,0,160,176,0,0,142,0,40,177,0,0,143,0,168,179,0,0,144,0,184,179,0,0,145,0,56,180,0,0,146,0,88,180,0,0,147,0,0,181,0,0,148,0,8,181,0,0,149,0,40,181,0,0,150,0,48,181,0,0,151,0,56,181,0,0,152,0,88,181,0,0,153,0,96,181,0,0,154,0,152,181,0,0,155,0,176,181,0,0,156,0,184,181,0,0,157,0,208,181,0,0,158,0,24,182,0,0,159,0,40,182,0,0,160,0,112,182,0,0,161,0,168,182,0,0,162,0,240,182,0,0,163,0,248,182,0,0,164,0,0,183,0,0,165,0,8,183,0,0,166,0,8,184,0,0,167,0,72,184,0,0,168,0,80,184,0,0,169,0,88,184,0,0,170,0,96,184,0,0,171,0,136,184,0,0,172,0,160,184,0,0,173,0,160,186,0,0,174,0,224,186,0,0,175,0,232,186,0,0,176,0,240,186,0,0,177,0,248,186,0,0,178,0,0,187,0,0,179,0,8,187,0,0,180,0,24,187,0,0,181,0,40,187,0,0,182,0,80,187,0,0,183,0,88,187,0,0,184,0,96,187,0,0,185,0,144,187,0,0,186,0,152,187,0,0,187,0,160,187,0,0,188,0,208,187,0,0,189,0,208,188,0,0,190,0,8,189,0,0,191,0,32,189,0,0,192,0,40,189,0,0,193,0,48,189,0,0,194,0,4,128,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,133,32,0,0,2,0,0,0,0,0,0,0,0,0,0,0,176,3,173,22,0,0,0,0,11,0,10,0,12,0,10,0,13,0,10,0,14,0,10,0,15,0,10,0,16,0,10,0,17,0,10,0,18,0,10,0,19,0,10,0,20,0,10,0,21,0,10,0,22,0,10,0,23,0,10,0,24,0,10,0,25,0,10,0,26,0,10,0,27,0,10,0,28,0,10,0,29,0,10,0,30,0,10,0,31,0,10,0,32,0,10,0,33,0,10,0,34,0,10,0,35,0,10,0,36,0,10,0,37,0,10,0,38,0,10,0,39,0,10,0,40,0,10,0,41,0,10,0,42,0,10,0,43,0,10,0,44,0,10,0,45,0,10,0,46,0,10,0,47,0,10,0,48,0,10,0,49,0,10,0,50,0,10,0,51,0,10,0,52,0,10,0,53,0,10,0,54,0,10,0,55,0,10,0,56,0,10,0,0,0,0,0,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,48,0,85,110,107,110,111,119,110,49,48,0,71,101,110,101,114,97,116,111,114,49,48,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,50,48,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,50,48,0,71,101,110,101,114,97,116,111,114,50,48,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,51,48,0,71,101,110,101,114,97,116,111,114,51,48,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,54,52,48,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,52,48,0,71,101,110,101,114,97,116,111,114,52,48,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,53,48,0,71,101,110,101,114,97,116,111,114,53,48,0,54,66,56,56,67,69,69,53,48,53,69,51,53,54,56,69,54,70,65,57,52,50,70,56,70,50,70,50,57,55,55,55,54,55,54,54,53,48,54,48,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,54,48,0,71,101,110,101,114,97,116,111,114,54,48,0,53,51,57,57,56,56,55,53,56,51,48,50,54,48,52,50,69,69,67,52,51,69,53,69,56,49,52,54,55,67,48,54,67,53,66,56,50,52,55,48,0,68,65,66,54,55,57,57,52,55,50,49,69,57,56,52,69,49,65,65,53,67,50,67,54,67,65,68,66,66,70,54,68,55,66,68,50,56,65,55,48,0,66,55,51,70,67,52,66,69,54,66,49,67,68,69,51,51,56,51,56,70,70,56,57,49,54,53,52,53,68,50,69,53,51,68,57,66,68,55,57,48,0,56,69,51,65,67,52,55,52,52,53,68,57,57,50,52,57,48,65,52,69,68,68,50,53,52,49,53,56,54,48,69,55,69,53,48,55,52,51,66,48,0,57,48,65,54,57,69,52,65,55,53,57,67,54,54,57,65,65,56,48,55,70,49,52,53,65,67,55,68,51,55,57,53,68,49,54,65,54,51,67,48,0,51,65,65,69,68,57,48,67,51,55,51,52,66,70,56,53,66,55,51,50,55,65,69,65,68,65,70,66,57,66,53,66,57,49,57,53,52,53,67,48,0,56,55,68,65,49,68,69,70,54,68,70,48,67,66,67,49,69,50,50,65,48,70,54,70,57,57,53,66,68,70,53,49,68,66,52,50,49,56,69,48,0,65,112,112,108,121,77,97,115,107,48,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,53,49,49,0,85,110,107,110,111,119,110,49,49,0,49,70,54,66,52,50,54,55,56,49,54,56,69,53,66,67,54,67,57,54,70,55,53,48,53,54,56,66,50,52,54,48,48,65,69,49,51,51,50,49,0,52,55,68,50,53,56,68,69,51,70,54,51,66,48,65,67,49,55,56,69,49,68,69,54,68,49,52,67,49,52,53,69,69,53,51,49,54,52,52,49,0,50,48,68,49,48,52,67,56,68,49,51,51,53,51,48,65,68,68,56,65,69,67,70,54,68,55,68,56,48,69,68,55,49,70,70,55,66,65,52,49,0,49,66,51,50,49,51,65,66,57,52,51,55,52,67,54,55,49,69,67,67,56,56,68,49,55,56,65,65,68,53,48,70,56,49,54,51,57,51,55,49,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,56,49,0,51,52,54,48,53,48,57,66,55,69,50,51,69,54,68,53,65,50,48,48,54,49,54,51,57,49,67,66,65,48,65,51,65,50,67,55,66,69,68,49,0,68,65,84,65,95,67,79,68,69,87,79,82,68,83,95,71,82,79,85,80,49,0,66,76,79,67,75,83,95,71,82,79,85,80,49,0,76,105,115,116,96,49,0,65,112,112,108,121,77,97,115,107,49,0,69,118,97,108,117,97,116,105,111,110,67,111,110,100,105,116,105,111,110,49,0,68,97,116,97,67,111,100,101,119,111,114,100,115,71,114,111,117,112,49,0,66,108,111,99,107,115,71,114,111,117,112,49,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,50,0,85,110,107,110,111,119,110,49,50,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,50,50,0,71,101,110,101,114,97,116,111,114,50,50,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,51,50,0,67,82,67,51,50,0,65,100,108,101,114,51,50,0,71,101,110,101,114,97,116,111,114,51,50,0,85,73,110,116,51,50,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,52,50,0,71,101,110,101,114,97,116,111,114,52,50,0,67,50,52,54,54,53,52,57,51,48,51,66,54,53,70,68,69,49,56,54,57,49,50,54,50,57,66,49,53,54,51,54,51,65,49,55,67,53,53,50,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,53,50,0,71,101,110,101,114,97,116,111,114,53,50,0,68,49,50,54,50,68,55,69,65,53,51,67,67,57,65,51,52,51,50,55,51,57,48,49,53,51,56,48,69,66,48,65,55,49,68,56,57,56,54,50,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,54,50,0,71,101,110,101,114,97,116,111,114,54,50,0,51,68,54,65,56,53,55,56,49,66,51,56,52,55,65,65,57,70,49,52,68,57,67,68,53,70,49,68,56,65,51,57,66,51,68,67,65,52,55,50,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,55,50,0,53,56,53,69,50,68,69,66,57,55,67,70,52,67,51,67,56,55,50,66,70,57,49,48,69,69,69,52,66,49,66,49,55,48,50,70,48,48,65,50,0,69,51,48,56,54,70,49,65,48,65,57,68,50,54,65,67,57,69,52,70,55,56,68,57,52,50,70,57,70,70,68,57,51,57,70,55,57,52,69,50,0,53,57,67,56,69,53,51,57,70,70,48,50,52,68,53,49,48,69,57,55,57,68,54,53,55,57,68,48,70,49,53,53,50,57,53,67,49,70,70,50,0,68,65,84,65,95,67,79,68,69,87,79,82,68,83,95,71,82,79,85,80,50,0,66,76,79,67,75,83,95,71,82,79,85,80,50,0,65,112,112,108,121,77,97,115,107,50,0,69,118,97,108,117,97,116,105,111,110,67,111,110,100,105,116,105,111,110,50,0,68,97,116,97,67,111,100,101,119,111,114,100,115,71,114,111,117,112,50,0,66,108,111,99,107,115,71,114,111,117,112,50,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,51,0,85,110,107,110,111,119,110,49,51,0,71,101,110,101,114,97,116,111,114,49,51,0,70,70,67,70,57,51,53,70,50,57,57,53,53,69,50,49,65,55,66,50,66,51,67,69,49,56,56,57,68,66,52,66,69,67,48,49,56,70,50,51,0,69,52,48,51,52,67,70,54,50,65,52,50,69,53,52,51,65,51,51,56,67,49,55,69,51,53,54,70,69,48,56,65,57,69,69,52,55,56,51,51,0,51,55,51,66,52,57,52,70,50,49,48,67,54,53,54,49,51,52,67,53,55,50,56,68,53,53,49,68,52,67,57,55,66,48,49,51,69,66,51,51,0,52,48,66,56,70,65,48,67,48,51,50,69,69,68,54,56,49,54,48,48,55,50,67,48,52,51,69,49,50,49,57,66,48,55,56,49,51,68,51,51,0,52,70,67,68,56,67,54,50,48,68,50,67,54,66,53,48,51,67,51,48,51,51,53,49,53,56,53,55,54,70,55,56,66,69,52,49,57,53,55,51,0,49,65,69,65,65,57,67,65,52,57,70,55,54,48,66,54,70,50,54,53,52,65,51,54,48,49,51,54,57,56,54,48,49,69,53,67,56,51,56,51,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,51,0,65,67,53,69,54,68,69,52,54,50,53,67,50,53,54,70,56,65,67,65,52,49,49,68,66,52,55,70,49,70,67,70,67,50,70,48,70,51,66,51,0,65,112,112,108,121,77,97,115,107,51,0,69,118,97,108,117,97,116,105,111,110,67,111,110,100,105,116,105,111,110,51,0,49,65,66,66,52,50,49,52,51,50,51,53,55,57,49,48,67,52,51,49,66,57,66,54,55,57,70,54,69,56,65,70,65,49,67,54,55,48,48,52,0,50,70,55,57,51,66,56,48,50,55,56,56,57,65,65,48,69,52,54,55,55,57,52,53,68,50,54,68,52,56,65,50,69,54,51,53,49,66,48,52,0,85,110,107,110,111,119,110,49,52,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,48,50,52,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,50,52,0,71,101,110,101,114,97,116,111,114,50,52,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,51,52,0,71,101,110,101,114,97,116,111,114,51,52,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,52,52,0,71,101,110,101,114,97,116,111,114,52,52,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,53,52,0,71,101,110,101,114,97,116,111,114,53,52,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,54,52,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,54,52,0,71,101,110,101,114,97,116,111,114,54,52,0,53,68,57,52,69,65,52,69,67,57,70,65,51,55,69,49,49,48,55,65,56,54,52,55,66,49,52,57,49,57,52,65,67,55,52,50,69,51,55,52,0,48,70,67,56,50,65,67,52,52,68,48,49,48,55,52,53,55,51,48,66,51,67,67,65,48,67,70,57,70,66,69,56,70,48,65,67,50,69,56,52,0,66,51,67,54,67,67,68,66,52,66,50,54,55,68,66,51,57,67,67,55,68,67,68,55,69,65,67,67,54,51,55,67,68,49,49,57,48,66,66,52,0,65,112,112,108,121,77,97,115,107,52,0,69,118,97,108,117,97,116,105,111,110,67,111,110,100,105,116,105,111,110,52,0,52,67,65,69,67,69,53,51,57,66,48,51,57,66,49,54,69,49,54,50,48,54,69,65,50,52,55,56,70,56,67,53,70,70,66,50,67,65,48,53,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,53,0,85,110,107,110,111,119,110,49,53,0,71,101,110,101,114,97,116,111,114,49,53,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,50,53,0,55,68,55,68,65,52,68,50,65,48,51,54,65,49,56,65,48,49,51,66,49,56,51,48,54,66,55,66,50,65,57,55,52,57,57,51,48,53,53,53,0,55,69,48,70,50,65,56,54,66,65,68,69,67,69,48,49,56,67,68,50,54,65,50,54,65,65,55,53,51,48,48,65,54,50,66,53,50,49,57,53,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,53,0,48,53,54,50,53,56,67,50,52,66,54,69,68,48,55,56,54,50,51,56,51,51,49,70,54,54,52,67,55,65,56,56,69,48,48,69,66,57,69,53,0,65,112,112,108,121,77,97,115,107,53,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,54,0,71,101,110,101,114,97,116,111,114,49,54,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,50,54,0,71,101,110,101,114,97,116,111,114,50,54,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,51,54,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,51,54,0,71,101,110,101,114,97,116,111,114,51,54,0,52,49,54,53,68,65,55,69,51,67,57,53,48,48,51,57,49,70,54,51,56,67,54,48,67,55,53,69,65,66,57,49,48,69,52,56,52,55,52,54,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,52,54,0,71,101,110,101,114,97,116,111,114,52,54,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,50,53,54,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,53,54,0,57,50,51,51,69,50,56,70,52,55,65,70,55,49,52,57,48,52,50,67,57,50,68,50,50,54,57,67,55,65,48,53,70,65,51,48,55,65,53,54,0,71,101,110,101,114,97,116,111,114,53,54,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,54,54,0,50,56,57,68,52,70,57,49,66,69,51,57,70,53,48,55,48,70,69,70,66,66,53,49,51,70,66,70,65,48,52,52,66,56,49,49,69,68,54,54,0,71,101,110,101,114,97,116,111,114,54,54,0,56,70,49,56,67,57,55,56,70,50,66,54,53,68,69,52,54,70,50,55,65,69,50,48,68,57,68,69,50,67,56,50,57,68,49,55,69,51,55,54,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,54,0,51,54,56,54,53,69,53,67,68,53,57,55,56,48,68,56,69,50,66,53,56,51,50,57,67,52,65,56,55,56,54,67,54,53,65,70,48,54,70,54,0,65,112,112,108,121,77,97,115,107,54,0,85,110,107,110,111,119,110,54,0,48,54,49,51,56,54,57,65,52,50,68,67,51,51,70,54,53,70,48,52,49,69,69,57,53,48,65,50,57,68,56,49,54,49,56,50,49,56,48,55,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,55,0,71,101,110,101,114,97,116,111,114,49,55,0,56,70,70,56,56,54,54,68,55,51,67,65,53,67,65,56,69,68,51,68,65,57,66,70,56,53,70,65,52,68,65,52,57,53,50,50,69,56,50,55,0,49,51,51,56,48,67,69,65,66,56,69,69,57,51,52,67,49,67,56,54,50,57,54,54,66,50,55,53,49,48,57,66,56,52,55,69,56,66,50,55,0,48,70,56,65,54,52,67,51,66,48,53,56,48,56,65,66,52,52,55,68,66,50,51,69,55,51,70,50,66,51,68,52,50,53,56,67,49,67,50,55,0,70,48,53,57,50,68,66,67,57,70,70,51,66,69,66,56,65,50,53,55,55,48,65,48,57,55,51,66,66,65,52,69,53,65,49,54,53,52,53,55,0,54,51,56,68,66,50,48,48,55,67,69,55,53,51,53,52,54,51,65,67,65,69,56,55,65,67,65,50,65,52,67,48,55,52,54,67,65,70,55,55,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,55,0,52,56,54,50,51,55,48,50,65,70,48,65,66,50,70,56,50,52,70,51,51,57,51,67,53,53,52,66,54,70,67,67,53,54,55,48,52,52,69,55,0,65,112,112,108,121,77,97,115,107,55,0,85,110,107,110,111,119,110,55,0,71,101,110,101,114,97,116,111,114,55,0,49,56,50,50,68,48,69,65,70,54,69,69,54,69,54,69,48,55,50,48,50,57,65,52,70,53,69,57,57,55,56,51,51,66,65,66,51,48,48,56,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,56,0,71,101,110,101,114,97,116,111,114,49,56,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,49,50,56,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,50,56,0,71,101,110,101,114,97,116,111,114,50,56,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,52,56,0,71,101,110,101,114,97,116,111,114,52,56,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,53,56,0,71,101,110,101,114,97,116,111,114,53,56,0,54,52,50,70,50,52,53,57,52,55,66,54,54,48,67,68,65,65,57,53,56,57,57,56,55,55,69,70,53,69,57,66,66,66,70,67,56,51,54,56,0,95,95,83,116,97,116,105,99,65,114,114,97,121,73,110,105,116,84,121,112,101,83,105,122,101,61,54,56,0,71,101,110,101,114,97,116,111,114,54,56,0,103,101,116,95,85,84,70,56,0,51,52,48,70,54,57,48,66,50,65,55,48,56,54,69,49,55,65,52,67,50,50,65,70,49,51,49,48,50,55,69,65,67,55,48,65,57,65,50,57,0,49,50,66,50,67,68,49,56,52,54,50,65,67,69,50,69,66,67,51,54,66,51,49,65,66,67,48,57,55,68,69,52,53,50,69,53,48,53,53,57,0,65,66,49,65,69,55,56,67,48,53,68,49,54,70,65,69,49,48,49,51,51,55,54,55,57,70,51,48,70,68,49,54,53,52,50,50,66,55,53,57,0,69,67,70,68,69,52,55,54,52,65,70,66,66,70,50,54,56,65,51,49,53,65,49,49,56,65,56,50,54,54,66,70,55,55,52,52,65,57,54,57,0,65,69,65,55,48,51,55,67,54,57,70,55,65,50,53,53,68,65,48,55,55,48,52,56,49,50,52,65,68,70,67,55,53,69,55,52,51,53,55,57,0,50,55,56,51,57,68,54,69,66,48,50,68,52,53,50,48,55,53,52,52,55,53,65,48,54,48,66,48,70,70,56,49,55,54,53,67,51,66,66,57,0,60,77,111,100,117,108,101,62,0,60,80,114,105,118,97,116,101,73,109,112,108,101,109,101,110,116,97,116,105,111,110,68,101,116,97,105,108,115,62,0,65,68,50,50,48,54,70,68,69,51,52,53,65,66,57,69,69,56,50,55,52,52,55,69,56,70,50,52,48,70,57,53,70,49,57,69,67,49,49,65,0,57,69,56,66,53,51,70,55,53,70,53,50,68,66,55,54,67,52,49,51,65,54,70,54,65,52,55,49,69,67,55,65,66,65,56,49,49,67,49,65,0,49,54,51,67,54,52,48,49,69,67,69,68,56,54,70,52,54,53,48,57,53,49,69,67,67,54,68,49,65,48,66,68,65,56,66,48,55,70,52,65,0,56,48,67,51,52,50,65,67,65,53,49,48,65,68,52,56,48,69,54,55,55,66,69,70,67,67,68,48,49,52,55,66,53,52,56,57,66,55,57,65,0,52,51,70,51,57,48,53,68,70,54,69,52,48,65,50,52,49,48,54,69,52,57,49,48,50,52,50,48,50,68,50,70,53,53,55,68,67,54,69,65,0,57,50,67,66,56,51,48,57,68,70,69,68,56,57,68,53,51,68,70,65,69,53,56,52,50,55,51,54,65,65,56,52,49,67,70,67,50,49,52,66,0,49,66,69,53,53,51,50,50,50,49,57,50,69,50,65,66,70,49,65,65,51,53,52,68,69,51,54,51,70,57,51,68,51,56,50,51,67,65,53,66,0,69,67,69,56,66,51,65,69,67,56,69,55,54,53,50,57,65,48,66,65,66,50,53,68,68,51,56,66,70,54,52,55,57,55,65,52,55,69,53,66,0,68,56,65,70,54,50,57,65,67,55,56,70,66,54,53,69,50,53,70,52,53,50,51,69,55,66,56,70,55,66,53,55,66,67,52,50,57,66,57,66,0,67,56,51,54,56,56,54,56,57,49,48,57,65,70,52,66,65,67,49,66,69,50,54,53,57,67,67,53,54,52,54,51,53,53,52,68,66,69,67,66,0,68,48,49,69,51,51,70,51,54,66,67,70,52,56,55,54,50,56,48,52,50,54,68,48,57,56,51,66,54,57,57,67,52,49,70,51,69,56,48,67,0,67,51,53,50,53,52,53,65,50,67,52,52,68,50,53,48,65,66,51,49,52,65,53,69,65,57,70,67,70,50,68,55,50,53,49,67,52,69,48,67,0,48,54,48,53,70,67,49,51,68,48,54,70,67,67,54,54,67,65,65,67,54,67,57,65,57,50,65,57,53,57,70,56,65,53,69,53,55,50,49,67,0,52,48,66,56,50,67,67,70,48,51,55,66,57,54,54,69,50,65,54,66,53,70,52,66,65,67,56,54,57,48,52,55,57,54,57,54,53,65,49,67,0,48,52,68,52,50,70,70,69,57,53,48,67,48,68,48,68,67,51,54,70,53,48,66,56,70,56,49,49,48,70,56,55,50,48,56,55,48,65,50,67,0,70,52,54,54,70,54,49,55,66,52,69,54,54,53,48,68,50,69,52,51,67,56,54,57,48,67,50,48,50,70,49,66,70,70,49,67,54,67,48,68,0,51,65,50,50,55,68,55,53,57,55,56,56,69,55,67,50,50,49,69,66,66,69,51,54,67,55,52,66,52,68,55,55,51,53,52,65,57,66,53,68,0,52,55,68,48,55,57,55,54,67,65,56,53,54,52,70,52,65,54,68,50,57,67,65,53,52,55,55,70,67,67,66,51,70,55,56,66,50,69,65,68,0,70,53,56,56,66,65,54,51,53,69,69,51,65,57,52,56,53,53,70,66,49,50,57,48,56,51,49,70,57,70,57,65,57,68,48,52,68,48,66,68,0,56,55,67,66,69,69,53,49,52,66,70,54,56,54,68,70,65,54,65,66,53,65,70,68,56,48,53,49,49,67,56,70,50,50,51,54,51,69,67,68,0,54,66,55,56,53,57,70,50,70,51,48,68,49,66,50,49,52,50,52,55,57,49,67,69,67,50,53,55,49,49,53,53,51,51,69,56,52,48,53,69,0,52,52,57,55,51,53,53,66,68,67,68,66,54,57,50,67,68,54,50,67,70,55,56,49,53,55,57,54,50,53,51,48,56,53,70,68,65,56,53,69,0,56,67,70,56,51,52,70,55,70,67,51,67,49,53,65,51,52,69,51,67,55,66,51,55,67,55,68,67,66,65,52,70,52,70,70,55,54,54,55,69,0,48,54,57,69,51,53,70,53,56,51,51,50,55,57,52,56,49,55,57,48,50,70,50,66,67,53,69,67,49,69,68,55,51,48,66,49,49,70,56,69,0,70,57,70,54,66,56,51,51,48,48,53,55,53,56,48,48,68,52,56,55,65,57,66,70,52,69,48,50,51,69,66,54,66,57,48,68,69,56,57,70,0,51,66,48,49,54,56,69,68,52,66,69,68,48,56,55,70,66,49,53,51,51,48,65,50,48,48,68,48,50,65,68,65,69,65,57,65,50,56,69,70,0,72,0,76,0,77,0,83,121,115,116,101,109,46,73,79,0,81,0,118,97,108,117,101,95,95,0,69,110,99,111,100,101,68,97,116,97,0,80,110,103,73,109,97,103,101,68,97,116,97,0,76,111,97,100,77,97,116,114,105,120,87,105,116,104,68,97,116,97,0,78,111,110,68,97,116,97,0,65,108,112,104,97,78,117,109,101,114,105,99,0,83,121,115,116,101,109,46,67,111,108,108,101,99,116,105,111,110,115,46,71,101,110,101,114,105,99,0,82,101,97,100,0,65,100,100,0,70,105,120,101,100,0,60,77,97,115,107,67,111,100,101,62,107,95,95,66,97,99,107,105,110,103,70,105,101,108,100,0,60,81,82,67,111,100,101,68,105,109,101,110,115,105,111,110,62,107,95,95,66,97,99,107,105,110,103,70,105,101,108,100,0,60,81,82,67,111,100,101,73,109,97,103,101,68,105,109,101,110,115,105,111,110,62,107,95,95,66,97,99,107,105,110,103,70,105,101,108,100,0,60,81,82,67,111,100,101,86,101,114,115,105,111,110,62,107,95,95,66,97,99,107,105,110,103,70,105,101,108,100,0,60,81,82,67,111,100,101,77,97,116,114,105,120,62,107,95,95,66,97,99,107,105,110,103,70,105,101,108,100,0,65,112,112,101,110,100,0,70,78,67,49,83,101,99,111,110,100,0,110,101,116,115,116,97,110,100,97,114,100,0,103,101,116,95,77,97,115,107,67,111,100,101,0,115,101,116,95,77,97,115,107,67,111,100,101,0,70,105,108,101,77,111,100,101,0,69,110,99,111,100,105,110,103,83,101,103,77,111,100,101,0,69,110,99,111,100,105,110,103,77,111,100,101,0,67,111,109,112,114,101,115,115,105,111,110,77,111,100,101,0,69,110,99,111,100,101,0,67,82,67,51,50,84,97,98,108,101,0,69,110,99,111,100,105,110,103,84,97,98,108,101,0,73,68,105,115,112,111,115,97,98,108,101,0,82,117,110,116,105,109,101,70,105,101,108,100,72,97,110,100,108,101,0,83,97,118,101,81,82,67,111,100,101,84,111,80,110,103,70,105,108,101,0,70,105,108,101,78,97,109,101,0,70,111,114,109,97,116,73,110,102,111,79,110,101,0,81,82,67,111,100,101,67,111,109,109,97,110,100,76,105,110,101,0,103,101,116,95,81,117,105,101,116,90,111,110,101,0,115,101,116,95,81,117,105,101,116,90,111,110,101,0,67,108,111,110,101,0,86,97,108,117,101,84,121,112,101,0,70,105,108,101,83,104,97,114,101,0,80,110,103,70,105,108,101,83,105,103,110,97,116,117,114,101,0,67,108,111,115,101,0,68,105,115,112,111,115,101,0,84,114,121,80,97,114,115,101,0,68,101,98,117,103,103,101,114,66,114,111,119,115,97,98,108,101,83,116,97,116,101,0,68,97,116,97,87,104,105,116,101,0,70,105,120,101,100,87,104,105,116,101,0,70,111,114,109,97,116,87,104,105,116,101,0,87,114,105,116,101,0,67,111,109,112,105,108,101,114,71,101,110,101,114,97,116,101,100,65,116,116,114,105,98,117,116,101,0,68,101,98,117,103,103,97,98,108,101,65,116,116,114,105,98,117,116,101,0,68,101,98,117,103,103,101,114,66,114,111,119,115,97,98,108,101,65,116,116,114,105,98,117,116,101,0,65,115,115,101,109,98,108,121,84,105,116,108,101,65,116,116,114,105,98,117,116,101,0,84,97,114,103,101,116,70,114,97,109,101,119,111,114,107,65,116,116,114,105,98,117,116,101,0,65,115,115,101,109,98,108,121,70,105,108,101,86,101,114,115,105,111,110,65,116,116,114,105,98,117,116,101,0,65,115,115,101,109,98,108,121,73,110,102,111,114,109,97,116,105,111,110,97,108,86,101,114,115,105,111,110,65,116,116,114,105,98,117,116,101,0,65,115,115,101,109,98,108,121,67,111,110,102,105,103,117,114,97,116,105,111,110,65,116,116,114,105,98,117,116,101,0,65,115,115,101,109,98,108,121,68,101,115,99,114,105,112,116,105,111,110,65,116,116,114,105,98,117,116,101,0,67,111,109,112,105,108,97,116,105,111,110,82,101,108,97,120,97,116,105,111,110,115,65,116,116,114,105,98,117,116,101,0,65,115,115,101,109,98,108,121,80,114,111,100,117,99,116,65,116,116,114,105,98,117,116,101,0,65,115,115,101,109,98,108,121,67,111,112,121,114,105,103,104,116,65,116,116,114,105,98,117,116,101,0,65,115,115,101,109,98,108,121,67,111,109,112,97,110,121,65,116,116,114,105,98,117,116,101,0,82,117,110,116,105,109,101,67,111,109,112,97,116,105,98,105,108,105,116,121,65,116,116,114,105,98,117,116,101,0,66,121,116,101,0,118,97,108,117,101,0,103,101,116,95,77,111,100,117,108,101,83,105,122,101,0,115,101,116,95,77,111,100,117,108,101,83,105,122,101,0,73,110,100,101,120,79,102,0,73,110,112,117,116,66,117,102,0,83,105,110,103,108,101,68,97,116,97,83,101,103,0,81,82,67,111,100,101,77,97,116,114,105,120,84,111,80,110,103,0,69,110,99,111,100,105,110,103,0,83,121,115,116,101,109,46,82,117,110,116,105,109,101,46,86,101,114,115,105,111,110,105,110,103,0,83,116,114,105,110,103,0,83,117,98,115,116,114,105,110,103,0,67,111,109,112,117,116,101,83,116,114,105,110,103,72,97,115,104,0,70,108,117,115,104,0,77,97,116,104,0,103,101,116,95,76,101,110,103,116,104,0,83,101,116,68,97,116,97,67,111,100,101,119,111,114,100,115,76,101,110,103,116,104,0,80,111,108,121,76,101,110,103,116,104,0,69,110,100,115,87,105,116,104,0,75,97,110,106,105,0,68,97,116,97,66,108,97,99,107,0,70,105,120,101,100,66,108,97,99,107,0,70,111,114,109,97,116,66,108,97,99,107,0,83,101,101,107,0,80,110,103,73,101,110,100,67,104,117,110,107,0,83,101,108,101,99,116,66,97,115,116,77,97,115,107,0,65,112,112,108,121,77,97,115,107,0,80,111,108,121,110,111,109,105,97,108,0,81,82,67,111,100,101,69,110,99,111,100,101,114,76,105,98,114,97,114,121,46,100,108,108,0,67,111,108,0,70,105,108,101,83,116,114,101,97,109,0,68,101,102,108,97,116,101,83,116,114,101,97,109,0,79,117,116,112,117,116,83,116,114,101,97,109,0,77,101,109,111,114,121,83,116,114,101,97,109,0,83,121,115,116,101,109,0,69,110,117,109,0,67,104,101,99,107,115,117,109,0,66,105,116,66,117,102,102,101,114,76,101,110,0,83,101,101,107,79,114,105,103,105,110,0,80,111,108,121,110,111,109,105,110,97,108,68,105,118,105,115,105,111,110,0,103,101,116,95,81,82,67,111,100,101,68,105,109,101,110,115,105,111,110,0,115,101,116,95,81,82,67,111,100,101,68,105,109,101,110,115,105,111,110,0,103,101,116,95,81,82,67,111,100,101,73,109,97,103,101,68,105,109,101,110,115,105,111,110,0,115,101,116,95,81,82,67,111,100,101,73,109,97,103,101,68,105,109,101,110,115,105,111,110,0,103,101,116,95,81,82,67,111,100,101,86,101,114,115,105,111,110,0,115,101,116,95,81,82,67,111,100,101,86,101,114,115,105,111,110,0,83,121,115,116,101,109,46,73,79,46,67,111,109,112,114,101,115,115,105,111,110,0,90,76,105,98,67,111,109,112,114,101,115,115,105,111,110,0,65,100,100,70,111,114,109,97,116,73,110,102,111,114,109,97,116,105,111,110,0,73,110,105,116,105,97,108,105,122,97,116,105,111,110,0,83,121,115,116,101,109,46,82,101,102,108,101,99,116,105,111,110,0,103,101,116,95,69,114,114,111,114,67,111,114,114,101,99,116,105,111,110,0,115,101,116,95,69,114,114,111,114,67,111,114,114,101,99,116,105,111,110,0,67,97,108,99,117,108,97,116,101,69,114,114,111,114,67,111,114,114,101,99,116,105,111,110,0,65,114,103,117,109,101,110,116,78,117,108,108,69,120,99,101,112,116,105,111,110,0,65,112,112,108,105,99,97,116,105,111,110,69,120,99,101,112,116,105,111,110,0,65,114,103,117,109,101,110,116,69,120,99,101,112,116,105,111,110,0,83,116,114,105,110,103,67,111,109,112,97,114,105,115,111,110,0,65,108,105,103,110,109,101,110,116,80,97,116,116,101,114,110,0,69,67,66,108,111,99,107,73,110,102,111,0,70,111,114,109,97,116,73,110,102,111,84,119,111,0,72,101,108,112,0,73,110,116,84,111,69,120,112,0,67,108,101,97,114,0,67,104,97,114,0,86,101,114,115,105,111,110,78,117,109,98,101,114,0,66,117,105,108,100,80,110,103,72,101,97,100,101,114,0,81,82,69,110,99,111,100,101,114,0,66,105,116,66,117,102,102,101,114,0,66,105,110,97,114,121,87,114,105,116,101,114,0,84,111,76,111,119,101,114,0,84,101,114,109,105,110,97,116,111,114,0,71,101,110,101,114,97,116,111,114,0,46,99,116,111,114,0,46,99,99,116,111,114,0,67,111,100,101,119,111,114,100,115,80,116,114,0,83,121,115,116,101,109,46,68,105,97,103,110,111,115,116,105,99,115,0,77,97,120,68,97,116,97,67,111,100,101,119,111,114,100,115,0,69,114,114,67,111,114,114,67,111,100,101,119,111,114,100,115,0,77,97,120,67,111,100,101,119,111,114,100,115,0,83,121,115,116,101,109,46,82,117,110,116,105,109,101,46,67,111,109,112,105,108,101,114,83,101,114,118,105,99,101,115,0,68,101,98,117,103,103,105,110,103,77,111,100,101,115,0,83,116,97,116,105,99,84,97,98,108,101,115,0,82,101,97,100,65,108,108,66,121,116,101,115,0,71,101,116,66,121,116,101,115,0,65,114,103,115,0,73,110,116,101,114,108,101,97,118,101,66,108,111,99,107,115,0,67,111,110,118,101,114,116,81,82,67,111,100,101,77,97,116,114,105,120,84,111,80,105,120,101,108,115,0,80,111,115,0,103,101,116,95,67,104,97,114,115,0,82,117,110,116,105,109,101,72,101,108,112,101,114,115,0,70,105,108,101,65,99,99,101,115,115,0,65,100,100,114,101,115,115,0,67,111,109,112,114,101,115,115,0,69,110,99,111,100,101,100,68,97,116,97,66,105,116,115,0,77,97,120,68,97,116,97,66,105,116,115,0,68,97,116,97,76,101,110,103,116,104,66,105,116,115,0,83,116,114,105,110,103,68,97,116,97,83,101,103,109,101,110,116,115,0,70,111,114,109,97,116,0,79,98,106,101,99,116,0,71,101,116,0,83,101,116,0,70,105,110,100,101,114,80,97,116,116,101,114,110,66,111,116,116,111,109,76,101,102,116,0,70,105,110,100,101,114,80,97,116,116,101,114,110,84,111,112,76,101,102,116,0,84,101,115,116,86,101,114,116,105,99,97,108,68,97,114,107,76,105,103,104,116,0,84,101,115,116,72,111,114,105,122,111,110,116,97,108,68,97,114,107,76,105,103,104,116,0,70,105,110,100,101,114,80,97,116,116,101,114,110,84,111,112,82,105,103,104,116,0,83,112,108,105,116,0,69,120,112,84,111,73,110,116,0,83,116,114,105,110,103,68,97,116,97,83,101,103,109,101,110,116,0,70,78,67,49,70,105,114,115,116,0,83,121,115,116,101,109,46,84,101,120,116,0,82,101,97,100,65,108,108,84,101,120,116,0,82,111,119,0,77,97,120,0,103,101,116,95,81,82,67,111,100,101,77,97,116,114,105,120,0,115,101,116,95,81,82,67,111,100,101,77,97,116,114,105,120,0,66,117,105,108,100,66,97,115,101,77,97,116,114,105,120,0,77,97,115,107,77,97,116,114,105,120,0,82,101,115,117,108,116,77,97,116,114,105,120,0,86,101,114,115,105,111,110,67,111,100,101,65,114,114,97,121,0,73,110,105,116,105,97,108,105,122,101,65,114,114,97,121,0,68,97,116,97,83,101,103,65,114,114,97,121,0,71,101,110,65,114,114,97,121,0,65,108,105,103,110,109,101,110,116,80,111,115,105,116,105,111,110,65,114,114,97,121,0,84,111,65,114,114,97,121,0,70,111,114,109,97,116,73,110,102,111,65,114,114,97,121,0,83,97,118,101,66,105,116,115,84,111,67,111,100,101,119,111,114,100,115,65,114,114,97,121,0,77,97,120,67,111,100,101,119,111,114,100,115,65,114,114,97,121,0,67,111,112,121,0,81,82,67,111,100,101,69,110,99,111,100,101,114,76,105,98,114,97,114,121,0,111,112,95,69,113,117,97,108,105,116,121,0,73,115,78,117,108,108,79,114,69,109,112,116,121,0,0,47,85,0,110,0,98,0,97,0,108,0,97,0,110,0,99,0,101,0,100,0,32,0,100,0,111,0,117,0,98,0,108,0,101,0,32,0,113,0,117,0,111,0,116,0,101,0,0,9,104,0,101,0,108,0,112,0,0,57,73,0,110,0,118,0,97,0,108,0,105,0,100,0,32,0,111,0,112,0,116,0,105,0,111,0,110,0,46,0,32,0,65,0,114,0,103,0,117,0,109,0,101,0,110,0,116,0,61,0,123,0,48,0,125,0,0,11,101,0,114,0,114,0,111,0,114,0,0,3,101,0,0,13,109,0,111,0,100,0,117,0,108,0,101,0,0,3,109,0,0,11,113,0,117,0,105,0,101,0,116,0,0,3,113,0,0,9,116,0,101,0,120,0,116,0,0,3,116,0,0,7,108,0,111,0,119,0,0,3,108,0,0,13,109,0,101,0,100,0,105,0,117,0,109,0,0,15,113,0,117,0,97,0,114,0,116,0,101,0,114,0,0,9,104,0,105,0,103,0,104,0,0,3,104,0,0,65,69,0,114,0,114,0,111,0,114,0,32,0,99,0,111,0,114,0,114,0,101,0,99,0,116,0,105,0,111,0,110,0,32,0,111,0,112,0,116,0,105,0,111,0,110,0,32,0,105,0,110,0,32,0,101,0,114,0,114,0,111,0,114,0,0,67,73,0,110,0,118,0,97,0,108,0,105,0,100,0,32,0,97,0,114,0,103,0,117,0,109,0,101,0,110,0,116,0,32,0,110,0,111,0,32,0,123,0,48,0,125,0,44,0,32,0,99,0,111,0,100,0,101,0,32,0,123,0,49,0,125,0,0,132,131,81,0,82,0,67,0,111,0,100,0,101,0,32,0,101,0,110,0,99,0,111,0,100,0,101,0,114,0,32,0,99,0,111,0,110,0,115,0,111,0,108,0,101,0,32,0,97,0,112,0,112,0,108,0,105,0,99,0,97,0,116,0,105,0,111,0,110,0,32,0,115,0,117,0,112,0,112,0,111,0,114,0,116,0,13,0,10,0,65,0,112,0,112,0,78,0,97,0,109,0,101,0,32,0,91,0,111,0,112,0,116,0,105,0,111,0,110,0,97,0,108,0,32,0,97,0,114,0,103,0,117,0,109,0,101,0,110,0,116,0,115,0,93,0,32,0,105,0,110,0,112,0,117,0,116,0,45,0,102,0,105,0,108,0,101,0,32,0,111,0,117,0,116,0,112,0,117,0,116,0,45,0,102,0,105,0,108,0,101,0,13,0,10,0,79,0,117,0,116,0,112,0,117,0,116,0,32,0,102,0,105,0,108,0,101,0,32,0,109,0,117,0,115,0,116,0,32,0,104,0,97,0,118,0,101,0,32,0,46,0,112,0,110,0,103,0,32,0,101,0,120,0,116,0,101,0,110,0,115,0,105,0,111,0,110,0,13,0,10,0,79,0,112,0,116,0,105,0,111,0,110,0,115,0,32,0,102,0,111,0,114,0,109,0,97,0,116,0,32,0,47,0,99,0,111,0,100,0,101,0,58,0,118,0,97,0,108,0,117,0,101,0,32,0,111,0,114,0,32,0,45,0,99,0,111,0,100,0,101,0,58,0,118,0,97,0,108,0,117,0,101,0,32,0,40,0,116,0,104,0,101,0,32,0,58,0,32,0,99,0,97,0,110,0,32,0,98,0,101,0,32,0,61,0,41,0,13,0,10,0,69,0,114,0,114,0,111,0,114,0,32,0,99,0,111,0,114,0,114,0,101,0,99,0,116,0,105,0,111,0,110,0,32,0,108,0,101,0,118,0,101,0,108,0,46,0,32,0,99,0,111,0,100,0,101,0,61,0,91,0,101,0,114,0,114,0,111,0,114,0,124,0,101,0,93,0,44,0,32,0,118,0,97,0,108,0,117,0,101,0,61,0,91,0,108,0,111,0,119,0,124,0,108,0,124,0,109,0,101,0,100,0,105,0,117,0,109,0,124,0,109,0,124,0,113,0,117,0,97,0,114,0,116,0,101,0,114,0,124,0,113,0,124,0,124,0,104,0,105,0,103,0,104,0,124,0,104,0,93,0,44,0,32,0,100,0,101,0,102,0,97,0,117,0,108,0,116,0,61,0,109,0,13,0,10,0,77,0,111,0,100,0,117,0,108,0,101,0,32,0,115,0,105,0,122,0,101,0,46,0,32,0,99,0,111,0,100,0,101,0,61,0,91,0,109,0,111,0,100,0,117,0,108,0,101,0,124,0,109,0,93,0,44,0,32,0,118,0,97,0,108,0,117,0,101,0,61,0,91,0,49,0,45,0,49,0,48,0,48,0,93,0,44,0,32,0,100,0,101,0,102,0,97,0,117,0,108,0,116,0,61,0,50,0,13,0,10,0,81,0,117,0,105,0,101,0,116,0,32,0,122,0,111,0,110,0,101,0,46,0,32,0,99,0,111,0,100,0,101,0,61,0,91,0,113,0,117,0,105,0,101,0,116,0,124,0,113,0,93,0,44,0,32,0,118,0,97,0,108,0,117,0,101,0,61,0,91,0,50,0,45,0,50,0,48,0,48,0,93,0,44,0,32,0,100,0,101,0,102,0,97,0,117,0,108,0,116,0,61,0,52,0,44,0,32,0,109,0,105,0,110,0,61,0,50,0,42,0,119,0,105,0,100,0,116,0,104,0,13,0,10,0,84,0,101,0,120,0,116,0,32,0,102,0,105,0,108,0,101,0,32,0,102,0,111,0,114,0,109,0,97,0,116,0,46,0,32,0,99,0,111,0,100,0,101,0,61,0,91,0,116,0,101,0,120,0,116,0,124,0,116,0,93,0,32,0,115,0,101,0,101,0,32,0,110,0,111,0,116,0,101,0,115,0,32,0,98,0,101,0,108,0,111,0,119,0,13,0,10,0,73,0,110,0,112,0,117,0,116,0,32,0,102,0,105,0,108,0,101,0,32,0,105,0,115,0,32,0,98,0,105,0,110,0,97,0,114,0,121,0,32,0,117,0,110,0,108,0,101,0,115,0,115,0,32,0,116,0,101,0,120,0,116,0,32,0,102,0,105,0,108,0,101,0,32,0,111,0,112,0,116,0,105,0,111,0,110,0,32,0,105,0,115,0,32,0,115,0,112,0,101,0,99,0,105,0,102,0,105,0,101,0,100,0,13,0,10,0,73,0,102,0,32,0,105,0,110,0,112,0,117,0,116,0,32,0,102,0,105,0,108,0,101,0,32,0,102,0,111,0,114,0,109,0,97,0,116,0,32,0,105,0,115,0,32,0,116,0,101,0,120,0,116,0,32,0,99,0,104,0,97,0,114,0,97,0,99,0,116,0,101,0,114,0,32,0,115,0,101,0,116,0,32,0,105,0,115,0,32,0,105,0,115,0,111,0,45,0,56,0,56,0,53,0,57,0,45,0,49,0,13,0,10,0,1,127,69,0,114,0,114,0,111,0,114,0,32,0,99,0,111,0,114,0,114,0,101,0,99,0,116,0,105,0,111,0,110,0,32,0,105,0,115,0,32,0,105,0,110,0,118,0,97,0,108,0,105,0,100,0,46,0,32,0,77,0,117,0,115,0,116,0,32,0,98,0,101,0,32,0,76,0,44,0,32,0,77,0,44,0,32,0,81,0,32,0,111,0,114,0,32,0,72,0,46,0,32,0,68,0,101,0,102,0,97,0,117,0,108,0,116,0,32,0,105,0,115,0,32,0,77,0,0,65,77,0,111,0,100,0,117,0,108,0,101,0,32,0,115,0,105,0,122,0,101,0,32,0,101,0,114,0,114,0,111,0,114,0,46,0,32,0,68,0,101,0,102,0,97,0,117,0,108,0,116,0,32,0,105,0,115,0,32,0,50,0,46,0,0,128,133,81,0,117,0,105,0,101,0,116,0,32,0,122,0,111,0,110,0,101,0,32,0,109,0,117,0,115,0,116,0,32,0,98,0,101,0,32,0,97,0,116,0,32,0,108,0,101,0,97,0,115,0,116,0,32,0,52,0,32,0,116,0,105,0,109,0,101,0,115,0,32,0,116,0,104,0,101,0,32,0,109,0,111,0,100,0,117,0,108,0,101,0,32,0,115,0,105,0,122,0,101,0,46,0,32,0,68,0,101,0,102,0,97,0,117,0,108,0,116,0,32,0,105,0,115,0,32,0,56,0,46,0,0,77,83,0,116,0,114,0,105,0,110,0,103,0,32,0,100,0,97,0,116,0,97,0,32,0,115,0,101,0,103,0,109,0,101,0,110,0,116,0,32,0,105,0,115,0,32,0,110,0,117,0,108,0,108,0,32,0,111,0,114,0,32,0,109,0,105,0,115,0,115,0,105,0,110,0,103,0,0,77,83,0,116,0,114,0,105,0,110,0,103,0,32,0,100,0,97,0,116,0,97,0,32,0,115,0,101,0,103,0,109,0,101,0,110,0,116,0,115,0,32,0,97,0,114,0,101,0,32,0,110,0,117,0,108,0,108,0,32,0,111,0,114,0,32,0,101,0,109,0,112,0,116,0,121,0,0,97,79,0,110,0,101,0,32,0,111,0,102,0,32,0,116,0,104,0,101,0,32,0,115,0,116,0,114,0,105,0,110,0,103,0,32,0,100,0,97,0,116,0,97,0,32,0,115,0,101,0,103,0,109,0,101,0,110,0,116,0,115,0,32,0,105,0,115,0,32,0,110,0,117,0,108,0,108,0,32,0,111,0,114,0,32,0,101,0,109,0,112,0,116,0,121,0,0,91,83,0,105,0,110,0,103,0,108,0,101,0,32,0,100,0,97,0,116,0,97,0,32,0,115,0,101,0,103,0,109,0,101,0,110,0,116,0,32,0,97,0,114,0,103,0,117,0,109,0,101,0,110,0,116,0,32,0,105,0,115,0,32,0,110,0,117,0,108,0,108,0,32,0,111,0,114,0,32,0,101,0,109,0,112,0,116,0,121,0,0,79,68,0,97,0,116,0,97,0,32,0,115,0,101,0,103,0,109,0,101,0,110,0,116,0,115,0,32,0,97,0,114,0,103,0,117,0,109,0,101,0,110,0,116,0,32,0,105,0,115,0,32,0,110,0,117,0,108,0,108,0,32,0,111,0,114,0,32,0,101,0,109,0,112,0,116,0,121,0,0,55,84,0,104,0,101,0,114,0,101,0,32,0,105,0,115,0,32,0,110,0,111,0,32,0,100,0,97,0,116,0,97,0,32,0,116,0,111,0,32,0,101,0,110,0,99,0,111,0,100,0,101,0,46,0,0,75,83,0,97,0,118,0,101,0,81,0,82,0,67,0,111,0,100,0,101,0,84,0,111,0,80,0,110,0,103,0,70,0,105,0,108,0,101,0,58,0,32,0,70,0,105,0,108,0,101,0,78,0,97,0,109,0,101,0,32,0,105,0,115,0,32,0,110,0,117,0,108,0,108,0,0,9,46,0,112,0,110,0,103,0,0,105,83,0,97,0,118,0,101,0,81,0,82,0,67,0,111,0,100,0,101,0,84,0,111,0,80,0,110,0,103,0,70,0,105,0,108,0,101,0,58,0,32,0,70,0,105,0,108,0,101,0,78,0,97,0,109,0,101,0,32,0,101,0,120,0,116,0,101,0,110,0,115,0,105,0,111,0,110,0,32,0,109,0,117,0,115,0,116,0,32,0,98,0,101,0,32,0,46,0,112,0,110,0,103,0,0,57,81,0,82,0,67,0,111,0,100,0,101,0,32,0,109,0,117,0,115,0,116,0,32,0,98,0,101,0,32,0,101,0,110,0,99,0,111,0,100,0,101,0,100,0,32,0,102,0,105,0,114,0,115,0,116,0,0,59,73,0,110,0,112,0,117,0,116,0,32,0,100,0,97,0,116,0,97,0,32,0,115,0,116,0,114,0,105,0,110,0,103,0,32,0,105,0,115,0,32,0,116,0,111,0,111,0,32,0,108,0,111,0,110,0,103,0,0,39,69,0,110,0,99,0,111,0,100,0,105,0,110,0,103,0,32,0,109,0,111,0,100,0,101,0,32,0,101,0,114,0,114,0,111,0,114,0,0,0,0,0,85,117,164,225,196,143,21,66,157,234,91,73,97,222,228,49,0,4,32,1,1,8,3,32,0,1,5,32,1,1,17,17,4,32,1,1,14,5,32,1,1,17,73,8,7,6,9,9,8,2,2,9,5,7,3,9,2,9,7,0,2,1,18,109,17,113,16,7,10,21,18,61,1,14,8,8,8,2,2,2,2,2,2,4,32,1,8,3,6,32,1,29,14,29,3,5,21,18,61,1,14,3,32,0,8,4,32,1,3,8,5,32,2,8,3,8,5,32,2,14,8,8,5,32,1,1,19,0,5,32,0,29,19,0,32,7,27,2,14,14,14,14,18,28,2,8,14,8,2,2,2,2,2,14,9,17,20,8,8,14,2,2,2,2,14,29,5,5,0,2,14,14,28,4,32,1,14,8,2,6,14,3,32,0,14,5,0,2,2,14,14,6,0,2,2,14,16,8,6,0,3,14,14,28,28,4,0,1,14,14,5,0,1,29,5,14,4,7,1,17,20,3,7,1,2,3,7,1,8,4,7,2,2,2,5,7,2,29,5,2,4,0,1,2,14,5,0,0,18,128,145,5,32,1,29,5,14,2,29,5,11,7,7,29,29,5,2,8,2,2,8,2,15,7,12,8,2,8,29,5,2,2,2,8,8,2,2,2,7,20,2,2,0,2,0,0,5,32,2,1,8,8,7,20,5,2,0,2,0,0,5,32,2,5,8,8,6,32,3,1,8,8,2,7,7,4,2,2,2,18,81,7,32,2,2,14,17,128,153,13,32,4,1,14,17,128,161,17,128,165,17,128,169,11,7,5,29,5,29,5,29,5,18,85,2,5,32,1,1,18,81,7,32,3,1,29,5,8,8,29,7,15,8,20,2,2,0,2,0,0,8,8,2,8,8,2,8,8,2,2,2,2,20,2,2,0,2,0,0,5,32,2,2,8,8,27,7,22,8,8,29,5,8,17,24,8,8,8,2,2,2,17,24,2,2,2,2,8,2,2,8,2,2,26,7,22,8,8,29,5,8,17,24,8,8,8,2,2,2,8,2,2,8,2,2,2,2,8,8,2,4,7,2,8,2,15,7,11,29,5,8,29,5,8,8,8,8,8,8,2,2,5,0,2,8,8,8,10,0,5,1,18,109,8,18,109,8,8,7,0,3,1,18,109,8,8,9,7,7,8,8,8,2,8,2,2,21,7,17,29,5,8,29,8,8,8,8,8,2,2,2,2,2,2,8,2,2,2,14,7,12,8,8,8,8,8,2,2,2,2,8,2,2,6,32,3,1,8,8,5,10,7,8,8,8,8,2,2,2,2,2,20,7,18,8,8,8,8,2,2,2,2,2,8,8,8,2,2,2,2,2,8,10,7,8,8,8,8,2,2,2,2,8,24,7,22,8,8,8,8,2,2,2,2,2,2,2,8,8,8,2,2,2,2,2,2,2,8,12,7,10,8,13,8,8,2,2,2,2,8,2,25,7,22,8,8,8,2,8,8,8,8,2,2,8,8,2,2,17,20,8,8,8,8,2,2,2,7,20,8,2,0,2,0,0,5,32,2,8,8,8,5,7,2,17,24,8,42,7,39,8,8,8,2,2,8,8,2,2,8,8,2,2,8,5,2,2,29,5,8,8,8,8,8,2,8,8,2,2,2,2,2,8,8,2,2,8,8,2,2,3,32,0,28,8,7,6,8,8,2,2,2,2,6,32,2,16,5,8,8,7,7,5,8,8,2,2,2,9,7,7,8,8,2,2,2,2,2,18,7,16,8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,16,7,14,8,8,8,2,2,8,2,2,2,2,2,2,2,2,24,7,22,8,8,8,2,2,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,24,7,22,8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,8,7,4,29,5,8,9,29,5,11,7,7,29,5,8,9,8,9,8,29,5,26,7,22,8,8,8,29,5,8,8,2,2,8,8,2,8,8,8,2,2,2,2,2,2,2,29,5,12,7,6,8,18,89,18,93,8,29,5,29,5,9,32,3,1,18,81,17,128,181,2,3,32,0,10,7,32,2,10,10,17,128,185,7,32,3,8,29,5,8,8,4,7,2,9,8,8,204,123,19,255,205,45,221,81,4,0,0,0,0,4,1,0,0,0,4,2,0,0,0,4,3,0,0,0,4,4,0,0,0,4,5,0,0,0,4,6,0,0,0,4,7,0,0,0,4,8,0,0,0,4,9,0,0,0,4,10,0,0,0,4,11,0,0,0,4,12,0,0,0,4,13,0,0,0,4,14,0,0,0,4,15,0,0,0,44,86,0,101,0,114,0,32,0,50,0,46,0,48,0,46,0,48,0,32,0,45,0,32,0,50,0,48,0,49,0,57,0,45,0,48,0,53,0,45,0,49,0,53,0,1,0,1,1,1,2,1,4,1,3,1,6,1,7,3,6,29,9,2,6,8,3,6,17,20,3,6,17,24,8,6,20,2,2,0,2,0,0,4,6,29,29,5,4,6,29,17,24,3,6,29,5,2,6,9,8,6,20,5,2,0,2,0,0,3,6,29,8,8,6,20,8,2,0,2,0,0,2,6,5,3,6,17,44,3,6,17,52,4,6,17,128,132,3,6,17,84,3,6,17,108,3,6,17,48,4,6,17,128,128,3,6,17,56,4,6,17,128,164,4,6,17,128,180,4,6,17,128,156,4,6,17,128,140,4,6,17,128,196,4,6,17,128,168,3,6,17,100,4,6,17,128,224,4,6,17,128,192,3,6,17,76,4,6,17,128,204,4,6,17,128,220,3,6,17,60,4,6,17,128,200,3,6,17,112,4,6,17,128,208,3,6,17,116,2,6,10,3,6,17,104,4,6,17,128,152,3,6,17,92,3,6,17,88,4,6,17,128,188,3,6,17,72,4,6,17,128,148,4,6,17,128,184,4,6,17,128,212,4,6,17,128,176,3,6,17,120,3,6,17,80,4,6,17,128,216,4,6,17,128,172,3,6,17,68,3,6,17,64,3,6,17,124,4,6,17,128,144,4,6,17,128,136,4,6,17,128,160,3,6,17,96,7,0,3,9,29,5,8,8,3,0,0,1,4,0,1,1,14,5,0,1,1,29,14,9,32,0,20,2,2,0,2,0,0,10,32,1,1,20,2,2,0,2,0,0,4,32,0,17,20,5,32,1,1,17,20,5,32,1,1,29,14,5,32,1,1,29,5,6,32,1,1,29,29,5,9,0,4,1,29,5,8,29,5,8,5,32,1,8,17,24,4,32,0,29,5,6,0,1,29,5,29,5,4,0,1,9,14,9,40,0,20,2,2,0,2,0,0,3,40,0,8,4,40,0,17,20,8,1,0,8,0,0,0,0,0,30,1,0,1,0,84,2,22,87,114,97,112,78,111,110,69,120,99,101,112,116,105,111,110,84,104,114,111,119,115,1,8,1,0,7,1,0,0,0,0,54,1,0,25,46,78,69,84,83,116,97,110,100,97,114,100,44,86,101,114,115,105,111,110,61,118,50,46,48,1,0,84,14,20,70,114,97,109,101,119,111,114,107,68,105,115,112,108,97,121,78,97,109,101,0,15,1,0,10,85,122,105,32,71,114,97,110,111,116,0,0,10,1,0,5,68,101,98,117,103,0,0,54,1,0,49,67,111,112,121,114,105,103,104,116,32,40,99,41,32,50,48,49,56,32,85,122,105,32,71,114,97,110,111,116,32,65,108,108,32,114,105,103,104,116,115,32,82,101,115,101,114,118,101,100,0,0,129,69,1,0,129,63,84,104,101,32,81,82,32,67,111,100,101,32,108,105,98,114,97,114,121,32,97,108,108,111,119,115,32,121,111,117,114,32,112,114,111,103,114,97,109,32,116,111,32,99,114,101,97,116,101,32,40,101,110,99,111,100,101,41,32,81,82,32,67,111,100,101,32,105,109,97,103,101,46,32,84,104,101,32,97,116,116,97,99,104,101,100,32,115,111,117,114,99,101,32,99,111,100,101,32,105,115,32,97,32,118,105,115,117,97,108,32,115,116,117,100,105,111,32,115,111,108,117,116,105,111,110,46,32,84,104,101,32,115,111,108,117,116,105,111,110,32,116,97,114,103,101,116,115,32,46,78,69,84,32,102,114,97,109,101,119,111,114,107,32,40,110,101,116,52,54,50,41,32,97,110,100,32,46,78,69,84,32,115,116,97,110,100,97,114,100,32,40,110,101,116,115,116,97,110,100,97,114,100,50,46,48,41,46,32,32,84,104,101,32,115,111,117,114,99,101,32,99,111,100,101,32,105,115,32,119,114,105,116,116,101,110,32,105,110,32,67,35,46,32,73,116,32,105,115,32,97,110,32,111,112,101,110,32,115,111,117,114,99,101,32,99,111,100,101,46,32,70,111,114,32,116,101,115,116,47,100,101,109,111,32,97,112,112,108,105,99,97,116,105,111,110,32,118,105,115,105,116,32,116,104,101,32,112,114,111,106,101,99,116,32,85,82,76,46,0,0,12,1,0,7,50,46,48,46,48,46,48,0,0,10,1,0,5,50,46,48,46,48,0,0,25,1,0,20,81,82,67,111,100,101,69,110,99,111,100,101,114,76,105,98,114,97,114,121,0,0,8,1,0,0,0,0,0,0,0,0,0,0,0,247,10,57,181,0,1,77,80,2,0,0,0,162,0,0,0,220,167,0,0,220,137,0,0,0,0,0,0,0,0,0,0,1,0,0,0,19,0,0,0,39,0,0,0,126,168,0,0,126,138,0,0,0,0,0,0,0,0,0,0,0,0,0,0,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,82,83,68,83,139,101,41,191,68,224,101,71,186,252,145,196,12,234,98,130,1,0,0,0,67,58,92,85,115,101,114,115,92,115,116,97,110,100,97,114,100,117,115,101,114,92,68,111,119,110,108,111,97,100,115,92,81,82,67,111,100,101,69,110,99,111,100,101,114,45,109,97,115,116,101,114,92,81,82,67,111,100,101,69,110,99,111,100,101,114,92,81,82,67,111,100,101,69,110,99,111,100,101,114,76,105,98,114,97,114,121,92,111,98,106,92,68,101,98,117,103,92,110,101,116,115,116,97,110,100,97,114,100,50,46,48,92,81,82,67,111,100,101,69,110,99,111,100,101,114,76,105,98,114,97,114,121,46,112,100,98,0,83,72,65,50,53,54,0,139,101,41,191,68,224,101,167,186,252,145,196,12,234,98,130,247,10,57,53,7,248,82,154,59,7,100,157,10,219,191,2,205,168,0,0,0,0,0,0,0,0,0,0,231,168,0,0,0,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,217,168,0,0,0,0,0,0,0,0,0,0,0,0,95,67,111,114,68,108,108,77,97,105,110,0,109,115,99,111,114,101,101,46,100,108,108,0,0,0,0,0,0,0,0,255,37,0,32,0,16,6,28,50,0,0,0,0,0,6,34,62,90,118,146,0,0,250,103,221,230,25,18,137,231,0,3,58,242,221,191,110,84,230,8,188,106,96,147,15,131,139,34,101,223,39,101,213,199,237,254,201,123,171,162,194,117,50,96,0,0,0,0,0,0,6,34,62,90,0,0,0,0,215,234,158,94,184,97,118,170,79,187,152,148,252,179,5,98,96,153,0,0,0,0,0,0,168,223,200,104,224,234,108,180,110,190,195,147,205,27,232,201,21,43,245,87,42,195,212,119,242,37,9,123,0,0,0,0,6,28,54,80,106,0,0,0,59,116,79,161,252,98,128,205,128,161,247,57,163,56,235,106,53,26,187,174,226,104,170,7,175,35,181,114,88,41,47,163,125,134,72,20,232,53,35,15,6,30,58,86,114,0,0,0,6,30,58,86,114,142,170,0,82,116,26,247,66,27,62,107,252,182,200,185,235,55,251,242,210,144,154,237,176,141,192,248,152,249,206,85,253,142,65,165,125,23,24,30,122,240,214,6,129,218,29,145,127,134,206,245,117,29,41,63,159,142,233,125,148,123,0,0,0,0,0,0,6,30,58,86,0,0,0,0,5,118,222,180,136,136,162,51,46,117,13,215,81,17,139,247,197,171,95,173,65,137,178,68,111,95,101,41,72,214,169,197,95,7,44,154,77,111,236,40,121,143,63,87,80,253,240,126,217,77,34,232,106,50,168,82,76,146,67,106,171,25,132,93,45,105,0,0,0,0,0,0,183,26,201,84,210,221,113,21,46,65,45,50,238,184,249,225,102,58,209,218,109,165,26,95,184,192,52,245,35,254,238,175,172,79,123,25,122,43,120,108,215,80,128,201,235,8,153,59,101,31,198,76,31,156,0,0,112,94,88,112,253,224,202,115,187,99,89,5,54,113,129,44,58,16,135,216,169,211,36,1,4,96,60,241,73,104,234,8,249,245,119,174,52,25,157,224,43,202,223,19,82,15,0,0,0,0,0,0,8,0,0,0,1,0,0,0,8,0,0,0,2,0,0,0,8,0,0,0,3,0,0,0,8,0,0,0,4,0,0,0,8,0,0,0,5,0,0,0,8,0,0,0,7,0,0,0,8,0,0,0,8,0,0,0,8,0,0,0,8,0,0,0,7,0,0,0,8,0,0,0,5,0,0,0,8,0,0,0,4,0,0,0,8,0,0,0,3,0,0,0,8,0,0,0,2,0,0,0,8,0,0,0,1,0,0,0,8,0,0,0,0,0,0,0,6,26,54,82,110,138,166,0,107,140,26,12,9,141,243,197,226,197,219,45,211,101,219,120,28,181,127,6,100,247,2,205,198,57,115,219,101,109,160,82,37,38,238,49,160,209,121,86,11,124,30,181,84,25,194,87,65,102,190,220,70,27,209,16,89,7,33,240,0,0,0,0,6,26,48,70,0,0,0,0,6,30,56,82,108,134,0,0,6,26,46,0,0,0,0,0,7,7,7,7,7,7,6,6,6,7,7,6,7,6,7,7,6,6,6,7,7,7,7,7,7,0,0,0,0,0,0,0,6,32,58,84,110,136,162,0,0,0,0,0,150,48,7,119,44,97,14,238,186,81,9,153,25,196,109,7,143,244,106,112,53,165,99,233,163,149,100,158,50,136,219,14,164,184,220,121,30,233,213,224,136,217,210,151,43,76,182,9,189,124,177,126,7,45,184,231,145,29,191,144,100,16,183,29,242,32,176,106,72,113,185,243,222,65,190,132,125,212,218,26,235,228,221,109,81,181,212,244,199,133,211,131,86,152,108,19,192,168,107,100,122,249,98,253,236,201,101,138,79,92,1,20,217,108,6,99,99,61,15,250,245,13,8,141,200,32,110,59,94,16,105,76,228,65,96,213,114,113,103,162,209,228,3,60,71,212,4,75,253,133,13,210,107,181,10,165,250,168,181,53,108,152,178,66,214,201,187,219,64,249,188,172,227,108,216,50,117,92,223,69,207,13,214,220,89,61,209,171,172,48,217,38,58,0,222,81,128,81,215,200,22,97,208,191,181,244,180,33,35,196,179,86,153,149,186,207,15,165,189,184,158,184,2,40,8,136,5,95,178,217,12,198,36,233,11,177,135,124,111,47,17,76,104,88,171,29,97,193,61,45,102,182,144,65,220,118,6,113,219,1,188,32,210,152,42,16,213,239,137,133,177,113,31,181,182,6,165,228,191,159,51,212,184,232,162,201,7,120,52,249,0,15,142,168,9,150,24,152,14,225,187,13,106,127,45,61,109,8,151,108,100,145,1,92,99,230,244,81,107,107,98,97,108,28,216,48,101,133,78,0,98,242,237,149,6,108,123,165,1,27,193,244,8,130,87,196,15,245,198,217,176,101,80,233,183,18,234,184,190,139,124,136,185,252,223,29,221,98,73,45,218,21,243,124,211,140,101,76,212,251,88,97,178,77,206,81,181,58,116,0,188,163,226,48,187,212,65,165,223,74,215,149,216,61,109,196,209,164,251,244,214,211,106,233,105,67,252,217,110,52,70,136,103,173,208,184,96,218,115,45,4,68,229,29,3,51,95,76,10,170,201,124,13,221,60,113,5,80,170,65,2,39,16,16,11,190,134,32,12,201,37,181,104,87,179,133,111,32,9,212,102,185,159,228,97,206,14,249,222,94,152,201,217,41,34,152,208,176,180,168,215,199,23,61,179,89,129,13,180,46,59,92,189,183,173,108,186,192,32,131,184,237,182,179,191,154,12,226,182,3,154,210,177,116,57,71,213,234,175,119,210,157,21,38,219,4,131,22,220,115,18,11,99,227,132,59,100,148,62,106,109,13,168,90,106,122,11,207,14,228,157,255,9,147,39,174,0,10,177,158,7,125,68,147,15,240,210,163,8,135,104,242,1,30,254,194,6,105,93,87,98,247,203,103,101,128,113,54,108,25,231,6,107,110,118,27,212,254,224,43,211,137,90,122,218,16,204,74,221,103,111,223,185,249,249,239,190,142,67,190,183,23,213,142,176,96,232,163,214,214,126,147,209,161,196,194,216,56,82,242,223,79,241,103,187,209,103,87,188,166,221,6,181,63,75,54,178,72,218,43,13,216,76,27,10,175,246,74,3,54,96,122,4,65,195,239,96,223,85,223,103,168,239,142,110,49,121,190,105,70,140,179,97,203,26,131,102,188,160,210,111,37,54,226,104,82,149,119,12,204,3,71,11,187,185,22,2,34,47,38,5,85,190,59,186,197,40,11,189,178,146,90,180,43,4,106,179,92,167,255,215,194,49,207,208,181,139,158,217,44,29,174,222,91,176,194,100,155,38,242,99,236,156,163,106,117,10,147,109,2,169,6,9,156,63,54,14,235,133,103,7,114,19,87,0,5,130,74,191,149,20,122,184,226,174,43,177,123,56,27,182,12,155,142,210,146,13,190,213,229,183,239,220,124,33,223,219,11,212,210,211,134,66,226,212,241,248,179,221,104,110,131,218,31,205,22,190,129,91,38,185,246,225,119,176,111,119,71,183,24,230,90,8,136,112,106,15,255,202,59,6,102,92,11,1,17,255,158,101,143,105,174,98,248,211,255,107,97,69,207,108,22,120,226,10,160,238,210,13,215,84,131,4,78,194,179,3,57,97,38,103,167,247,22,96,208,77,71,105,73,219,119,110,62,74,106,209,174,220,90,214,217,102,11,223,64,240,59,216,55,83,174,188,169,197,158,187,222,127,207,178,71,233,255,181,48,28,242,189,189,138,194,186,202,48,147,179,83,166,163,180,36,5,54,208,186,147,6,215,205,41,87,222,84,191,103,217,35,46,122,102,179,184,74,97,196,2,27,104,93,148,43,111,42,55,190,11,180,161,142,12,195,27,223,5,90,141,239,2,45,7,7,7,7,7,7,7,6,2,7,6,6,6,6,6,7,6,2,7,6,7,7,7,6,7,6,2,7,6,7,7,7,6,7,6,2,7,6,7,7,7,6,7,6,2,7,6,6,6,6,6,7,6,2,7,7,7,7,7,7,7,6,2,6,6,6,6,6,6,6,6,2,2,2,2,2,2,2,2,2,2,0,0,0,0,0,0,0,6,28,54,80,106,132,158,0,120,104,107,109,102,161,76,3,91,191,147,169,182,194,225,120,8,0,0,0,255,255,255,255,8,0,0,0,254,255,255,255,8,0,0,0,253,255,255,255,8,0,0,0,252,255,255,255,8,0,0,0,251,255,255,255,8,0,0,0,250,255,255,255,8,0,0,0,249,255,255,255,8,0,0,0,248,255,255,255,249,255,255,255,8,0,0,0,250,255,255,255,8,0,0,0,251,255,255,255,8,0,0,0,252,255,255,255,8,0,0,0,253,255,255,255,8,0,0,0,254,255,255,255,8,0,0,0,255,255,255,255,8,0,0,0,148,124,0,0,188,133,0,0,153,154,0,0,211,164,0,0,246,187,0,0,98,199,0,0,71,216,0,0,13,230,0,0,40,249,0,0,120,11,1,0,93,20,1,0,23,42,1,0,50,53,1,0,166,73,1,0,131,86,1,0,201,104,1,0,236,119,1,0,196,142,1,0,225,145,1,0,171,175,1,0,142,176,1,0,26,204,1,0,63,211,1,0,117,237,1,0,80,242,1,0,213,9,2,0,240,22,2,0,186,40,2,0,159,55,2,0,11,75,2,0,46,84,2,0,100,106,2,0,65,117,2,0,105,140,2,0,1,19,0,0,1,16,0,0,1,13,0,0,1,9,0,0,1,34,0,0,1,28,0,0,1,22,0,0,1,16,0,0,1,55,0,0,1,44,0,0,2,17,0,0,2,13,0,0,1,80,0,0,2,32,0,0,2,24,0,0,4,9,0,0,1,108,0,0,2,43,0,0,2,15,2,16,2,11,2,12,2,68,0,0,4,27,0,0,4,19,0,0,4,15,0,0,2,78,0,0,4,31,0,0,2,14,4,15,4,13,1,14,2,97,0,0,2,38,2,39,4,18,2,19,4,14,2,15,2,116,0,0,3,36,2,37,4,16,4,17,4,12,4,13,2,68,2,69,4,43,1,44,6,19,2,20,6,15,2,16,4,81,0,0,1,50,4,51,4,22,4,23,3,12,8,13,2,92,2,93,6,36,2,37,4,20,6,21,7,14,4,15,4,107,0,0,8,37,1,38,8,20,4,21,12,11,4,12,3,115,1,116,4,40,5,41,11,16,5,17,11,12,5,13,5,87,1,88,5,41,5,42,5,24,7,25,11,12,7,13,5,98,1,99,7,45,3,46,15,19,2,20,3,15,13,16,1,107,5,108,10,46,1,47,1,22,15,23,2,14,17,15,5,120,1,121,9,43,4,44,17,22,1,23,2,14,19,15,3,113,4,114,3,44,11,45,17,21,4,22,9,13,16,14,3,107,5,108,3,41,13,42,15,24,5,25,15,15,10,16,4,116,4,117,17,42,0,0,17,22,6,23,19,16,6,17,2,111,7,112,17,46,0,0,7,24,16,25,34,13,0,0,4,121,5,122,4,47,14,48,11,24,14,25,16,15,14,16,6,117,4,118,6,45,14,46,11,24,16,25,30,16,2,17,8,106,4,107,8,47,13,48,7,24,22,25,22,15,13,16,10,114,2,115,19,46,4,47,28,22,6,23,33,16,4,17,8,122,4,123,22,45,3,46,8,23,26,24,12,15,28,16,3,117,10,118,3,45,23,46,4,24,31,25,11,15,31,16,7,116,7,117,21,45,7,46,1,23,37,24,19,15,26,16,5,115,10,116,19,47,10,48,15,24,25,25,23,15,25,16,13,115,3,116,2,46,29,47,42,24,1,25,23,15,28,16,17,115,0,0,10,46,23,47,10,24,35,25,19,15,35,16,17,115,1,116,14,46,21,47,29,24,19,25,11,15,46,16,13,115,6,116,14,46,23,47,44,24,7,25,59,16,1,17,12,121,7,122,12,47,26,48,39,24,14,25,22,15,41,16,6,121,14,122,6,47,34,48,46,24,10,25,2,15,64,16,17,122,4,123,29,46,14,47,49,24,10,25,24,15,46,16,4,122,18,123,13,46,32,47,48,24,14,25,42,15,32,16,20,117,4,118,40,47,7,48,43,24,22,25,10,15,67,16,19,118,6,119,18,47,31,48,34,24,34,25,20,15,61,16,251,67,46,61,118,70,64,94,32,45,0,0,0,0,0,0,18,84,0,0,37,81,0,0,124,94,0,0,75,91,0,0,249,69,0,0,206,64,0,0,151,79,0,0,160,74,0,0,196,119,0,0,243,114,0,0,170,125,0,0,157,120,0,0,47,102,0,0,24,99,0,0,65,108,0,0,118,105,0,0,137,22,0,0,190,19,0,0,231,28,0,0,208,25,0,0,98,7,0,0,85,2,0,0,12,13,0,0,59,8,0,0,95,53,0,0,104,48,0,0,49,63,0,0,6,58,0,0,180,36,0,0,131,33,0,0,218,46,0,0,237,43,0,0,41,173,145,152,216,31,179,182,50,48,110,86,239,96,222,125,42,173,226,193,224,130,156,37,251,216,238,40,192,180,0,0,0,0,0,0,26,0,0,0,44,0,0,0,70,0,0,0,100,0,0,0,134,0,0,0,172,0,0,0,196,0,0,0,242,0,0,0,36,1,0,0,90,1,0,0,148,1,0,0,210,1,0,0,20,2,0,0,69,2,0,0,143,2,0,0,221,2,0,0,47,3,0,0,133,3,0,0,223,3,0,0,61,4,0,0,132,4,0,0,234,4,0,0,84,5,0,0,194,5,0,0,52,6,0,0,170,6,0,0,36,7,0,0,129,7,0,0,3,8,0,0,137,8,0,0,19,9,0,0,161,9,0,0,51,10,0,0,201,10,0,0,60,11,0,0,218,11,0,0,124,12,0,0,34,13,0,0,204,13,0,0,122,14,0,0,0,0,0,0,6,30,54,0,0,0,0,0,10,6,106,190,249,167,4,67,209,138,138,32,242,123,89,27,120,185,80,156,38,60,171,60,28,222,80,52,254,185,220,241,137,80,78,71,13,10,26,10,6,26,50,74,0,0,0,0,173,125,158,2,103,182,118,17,145,201,111,28,165,53,161,21,245,142,13,102,48,227,153,145,218,70,0,0,0,0,0,0,6,28,50,72,94,0,0,0,116,50,86,186,50,220,251,89,192,46,86,127,124,19,184,233,151,215,22,14,59,145,37,242,203,134,254,89,190,94,59,65,124,113,100,233,235,121,22,76,86,97,39,242,200,220,101,33,239,254,116,51,0,0,0,0,210,171,247,242,93,230,14,109,221,53,200,74,8,172,98,80,219,134,160,105,165,231,0,0,6,26,46,66,0,0,0,0,17,60,79,50,61,163,26,187,202,180,221,225,83,239,156,164,212,212,188,190,0,0,0,0,6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,6,2,7,6,6,6,6,6,7,6,2,7,6,7,7,7,6,7,6,2,7,6,7,7,7,6,7,6,2,7,6,7,7,7,6,7,6,2,7,6,6,6,6,6,7,6,2,7,7,7,7,7,7,7,6,2,8,183,61,91,202,37,51,58,58,237,140,124,5,99,105,0,6,7,7,7,7,7,7,7,6,7,6,6,6,6,6,7,6,7,6,7,7,7,6,7,6,7,6,7,7,7,6,7,6,7,6,7,7,7,6,7,6,7,6,6,6,6,6,7,6,7,7,7,7,7,7,7,6,6,6,6,6,6,6,6,2,2,2,2,2,2,2,2,232,125,157,161,164,9,118,46,209,99,203,193,35,3,209,111,195,242,203,225,46,13,32,160,126,209,130,160,242,215,242,75,77,42,189,32,113,65,124,69,228,114,235,175,124,170,215,232,133,205,0,0,0,0,0,0,247,159,223,33,224,93,77,70,90,160,32,254,43,150,84,101,190,205,133,52,60,202,165,220,203,151,93,84,15,84,253,173,160,89,227,52,199,97,95,231,52,177,41,125,137,241,166,225,118,2,54,32,82,215,175,198,43,238,235,27,101,184,127,3,5,8,163,238,0,0,0,0,6,26,50,74,98,122,0,0,6,30,54,78,102,126,150,0,6,34,62,0,0,0,0,0,0,0,1,25,2,50,26,198,3,223,51,238,27,104,199,75,4,100,224,14,52,141,239,129,28,193,105,248,200,8,76,113,5,138,101,47,225,36,15,33,53,147,142,218,240,18,130,69,29,181,194,125,106,39,249,185,201,154,9,120,77,228,114,166,6,191,139,98,102,221,48,253,226,152,37,179,16,145,34,136,54,208,148,206,143,150,219,189,241,210,19,92,131,56,70,64,30,66,182,163,195,72,126,110,107,58,40,84,250,133,186,61,202,94,155,159,10,21,121,43,78,212,229,172,115,243,167,87,7,112,192,247,140,128,99,13,103,74,222,237,49,197,254,24,227,165,153,119,38,184,180,124,17,68,146,217,35,32,137,46,55,63,209,91,149,188,207,205,144,135,151,178,220,252,190,97,242,86,211,171,20,42,93,158,132,60,57,83,71,109,65,162,31,45,67,216,183,123,164,118,196,23,73,236,127,12,111,246,108,161,59,82,41,157,85,170,251,96,134,177,187,204,62,90,203,89,95,176,156,169,160,81,11,245,22,235,122,117,44,215,79,174,213,233,230,231,173,232,116,214,244,234,168,80,88,175,45,51,175,9,7,158,159,49,68,119,92,123,177,204,187,254,200,78,141,149,119,26,127,53,160,93,199,212,29,24,145,156,208,150,218,209,4,216,91,47,184,146,47,140,195,195,125,242,238,63,99,108,140,230,242,31,204,11,178,243,217,156,213,231,6,30,56,82,0,0,0,0,6,34,60,86,112,138,0,0,6,26,52,78,104,130,0,0,111,77,146,94,26,21,108,19,105,94,113,193,86,140,163,125,58,158,229,239,218,103,56,70,114,61,183,129,167,13,98,62,129,51,0,0,0,0,0,0,43,139,206,78,43,239,123,206,214,147,24,99,150,39,243,163,136,0,0,0,0,0,0,0,1,2,4,8,16,32,64,128,29,58,116,232,205,135,19,38,76,152,45,90,180,117,234,201,143,3,6,12,24,48,96,192,157,39,78,156,37,74,148,53,106,212,181,119,238,193,159,35,70,140,5,10,20,40,80,160,93,186,105,210,185,111,222,161,95,190,97,194,153,47,94,188,101,202,137,15,30,60,120,240,253,231,211,187,107,214,177,127,254,225,223,163,91,182,113,226,217,175,67,134,17,34,68,136,13,26,52,104,208,189,103,206,129,31,62,124,248,237,199,147,59,118,236,197,151,51,102,204,133,23,46,92,184,109,218,169,79,158,33,66,132,21,42,84,168,77,154,41,82,164,85,170,73,146,57,114,228,213,183,115,230,209,191,99,198,145,63,126,252,229,215,179,123,246,241,255,227,219,171,75,150,49,98,196,149,55,110,220,165,87,174,65,130,25,50,100,200,141,7,14,28,56,112,224,221,167,83,166,81,162,89,178,121,242,249,239,195,155,43,86,172,69,138,9,18,36,72,144,61,122,244,245,247,243,251,235,203,139,11,22,44,88,176,125,250,233,207,131,27,54,108,216,173,71,142,1,2,4,8,16,32,64,128,29,58,116,232,205,135,19,38,76,152,45,90,180,117,234,201,143,3,6,12,24,48,96,192,157,39,78,156,37,74,148,53,106,212,181,119,238,193,159,35,70,140,5,10,20,40,80,160,93,186,105,210,185,111,222,161,95,190,97,194,153,47,94,188,101,202,137,15,30,60,120,240,253,231,211,187,107,214,177,127,254,225,223,163,91,182,113,226,217,175,67,134,17,34,68,136,13,26,52,104,208,189,103,206,129,31,62,124,248,237,199,147,59,118,236,197,151,51,102,204,133,23,46,92,184,109,218,169,79,158,33,66,132,21,42,84,168,77,154,41,82,164,85,170,73,146,57,114,228,213,183,115,230,209,191,99,198,145,63,126,252,229,215,179,123,246,241,255,227,219,171,75,150,49,98,196,149,55,110,220,165,87,174,65,130,25,50,100,200,141,7,14,28,56,112,224,221,167,83,166,81,162,89,178,121,242,249,239,195,155,43,86,172,69,138,9,18,36,72,144,61,122,244,245,247,243,251,235,203,139,11,22,44,88,176,125,250,233,207,131,27,54,108,216,173,71,142,1,0,65,202,113,98,71,223,248,118,214,94,0,122,37,23,2,228,58,121,7,105,135,78,243,118,70,76,223,89,72,50,70,111,194,17,212,126,181,35,221,117,235,11,229,149,147,123,213,40,115,6,200,100,26,246,182,218,127,215,36,186,110,106,0,0,6,24,50,76,102,128,154,0,87,229,146,149,238,102,21,0,6,22,38,0,0,0,0,0,6,34,62,90,118,0,0,0,6,30,54,78,102,0,0,0,74,152,176,100,86,100,106,104,130,218,206,140,78,0,0,0,0,0,0,0,73,69,78,68,174,66,96,130,0,0,0,0,200,183,98,16,172,31,246,234,60,152,115,0,167,152,113,248,238,107,18,63,218,37,87,210,105,177,120,74,121,196,117,251,113,233,30,120,0,0,0,0,6,26,50,74,98,0,0,0,6,24,42,0,0,0,0,0,228,25,196,130,211,146,60,24,251,90,39,102,240,61,178,63,46,123,115,18,221,111,135,160,182,205,107,206,95,150,120,184,91,21,247,156,140,238,191,11,94,227,84,50,163,39,34,108,6,30,54,78,0,0,0,0,6,32,58,0,0,0,0,0,190,7,61,121,71,246,69,55,168,188,89,243,191,25,72,123,9,145,14,247,1,238,44,78,143,62,224,126,118,114,68,163,52,194,217,147,204,169,37,130,113,102,73,181,0,0,0,0,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,36,45,45,45,37,38,45,45,45,45,39,40,45,41,42,43,0,1,2,3,4,5,6,7,8,9,44,45,45,45,45,45,45,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,45,106,120,107,157,164,216,112,116,2,91,248,163,36,201,202,229,6,144,254,155,135,208,170,209,12,139,127,142,182,249,177,174,190,28,10,85,239,184,101,124,152,206,96,23,163,61,27,196,247,151,154,202,207,20,61,10,229,121,135,48,211,117,251,126,159,180,169,152,192,226,228,218,111,0,117,232,87,96,227,21,6,32,58,84,110,0,0,0,6,30,58,86,114,142,0,0,6,30,54,78,102,126,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,16,0,0,0,24,0,0,128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,48,0,0,128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,72,0,0,0,88,192,0,0,28,6,0,0,0,0,0,0,0,0,0,0,28,6,52,0,0,0,86,0,83,0,95,0,86,0,69,0,82,0,83,0,73,0,79,0,78,0,95,0,73,0,78,0,70,0,79,0,0,0,0,0,189,4,239,254,0,0,1,0,0,0,2,0,0,0,0,0,0,0,2,0,0,0,0,0,63,0,0,0,0,0,0,0,4,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,68,0,0,0,1,0,86,0,97,0,114,0,70,0,105,0,108,0,101,0,73,0,110,0,102,0,111,0,0,0,0,0,36,0,4,0,0,0,84,0,114,0,97,0,110,0,115,0,108,0,97,0,116,0,105,0,111,0,110,0,0,0,0,0,0,0,176,4,124,5,0,0,1,0,83,0,116,0,114,0,105,0,110,0,103,0,70,0,105,0,108,0,101,0,73,0,110,0,102,0,111,0,0,0,88,5,0,0,1,0,48,0,48,0,48,0,48,0,48,0,52,0,98,0,48,0,0,0,152,2,64,1,1,0,67,0,111,0,109,0,109,0,101,0,110,0,116,0,115,0,0,0,84,0,104,0,101,0,32,0,81,0,82,0,32,0,67,0,111,0,100,0,101,0,32,0,108,0,105,0,98,0,114,0,97,0,114,0,121,0,32,0,97,0,108,0,108,0,111,0,119,0,115,0,32,0,121,0,111,0,117,0,114,0,32,0,112,0,114,0,111,0,103,0,114,0,97,0,109,0,32,0,116,0,111,0,32,0,99,0,114,0,101,0,97,0,116,0,101,0,32,0,40,0,101,0,110,0,99,0,111,0,100,0,101,0,41,0,32,0,81,0,82,0,32,0,67,0,111,0,100,0,101,0,32,0,105,0,109,0,97,0,103,0,101,0,46,0,32,0,84,0,104,0,101,0,32,0,97,0,116,0,116,0,97,0,99,0,104,0,101,0,100,0,32,0,115,0,111,0,117,0,114,0,99,0,101,0,32,0,99,0,111,0,100,0,101,0,32,0,105,0,115,0,32,0,97,0,32,0,118,0,105,0,115,0,117,0,97,0,108,0,32,0,115,0,116,0,117,0,100,0,105,0,111,0,32,0,115,0,111,0,108,0,117,0,116,0,105,0,111,0,110,0,46,0,32,0,84,0,104,0,101,0,32,0,115,0,111,0,108,0,117,0,116,0,105,0,111,0,110,0,32,0,116,0,97,0,114,0,103,0,101,0,116,0,115,0,32,0,46,0,78,0,69,0,84,0,32,0,102,0,114,0,97,0,109,0,101,0,119,0,111,0,114,0,107,0,32,0,40,0,110,0,101,0,116,0,52,0,54,0,50,0,41,0,32,0,97,0,110,0,100,0,32,0,46,0,78,0,69,0,84,0,32,0,115,0,116,0,97,0,110,0,100,0,97,0,114,0,100,0,32,0,40,0,110,0,101,0,116,0,115,0,116,0,97,0,110,0,100,0,97,0,114,0,100,0,50,0,46,0,48,0,41,0,46,0,32,0,32,0,84,0,104,0,101,0,32,0,115,0,111,0,117,0,114,0,99,0,101,0,32,0,99,0,111,0,100,0,101,0,32,0,105,0,115,0,32,0,119,0,114,0,105,0,116,0,116,0,101,0,110,0,32,0,105,0,110,0,32,0,67,0,35,0,46,0,32,0,73,0,116,0,32,0,105,0,115,0,32,0,97,0,110,0,32,0,111,0,112,0,101,0,110,0,32,0,115,0,111,0,117,0,114,0,99,0,101,0,32,0,99,0,111,0,100,0,101,0,46,0,32,0,70,0,111,0,114,0,32,0,116,0,101,0,115,0,116,0,47,0,100,0,101,0,109,0,111,0,32,0,97,0,112,0,112,0,108,0,105,0,99,0,97,0,116,0,105,0,111,0,110,0,32,0,118,0,105,0,115,0,105,0,116,0,32,0,116,0,104,0,101,0,32,0,112,0,114,0,111,0,106,0,101,0,99,0,116,0,32,0,85,0,82,0,76,0,46,0,0,0,54,0,11,0,1,0,67,0,111,0,109,0,112,0,97,0,110,0,121,0,78,0,97,0,109,0,101,0,0,0,0,0,85,0,122,0,105,0,32,0,71,0,114,0,97,0,110,0,111,0,116,0,0,0,0,0,82,0,21,0,1,0,70,0,105,0,108,0,101,0,68,0,101,0,115,0,99,0,114,0,105,0,112,0,116,0,105,0,111,0,110,0,0,0,0,0,81,0,82,0,67,0,111,0,100,0,101,0,69,0,110,0,99,0,111,0,100,0,101,0,114,0,76,0,105,0,98,0,114,0,97,0,114,0,121,0,0,0,0,0,48,0,8,0,1,0,70,0,105,0,108,0,101,0,86,0,101,0,114,0,115,0,105,0,111,0,110,0,0,0,0,0,50,0,46,0,48,0,46,0,48,0,46,0,48,0,0,0,82,0,25,0,1,0,73,0,110,0,116,0,101,0,114,0,110,0,97,0,108,0,78,0,97,0,109,0,101,0,0,0,81,0,82,0,67,0,111,0,100,0,101,0,69,0,110,0,99,0,111,0,100,0,101,0,114,0,76,0,105,0,98,0,114,0,97,0,114,0,121,0,46,0,100,0,108,0,108,0,0,0,0,0,136,0,50,0,1,0,76,0,101,0,103,0,97,0,108,0,67,0,111,0,112,0,121,0,114,0,105,0,103,0,104,0,116,0,0,0,67,0,111,0,112,0,121,0,114,0,105,0,103,0,104,0,116,0,32,0,40,0,99,0,41,0,32,0,50,0,48,0,49,0,56,0,32,0,85,0,122,0,105,0,32,0,71,0,114,0,97,0,110,0,111,0,116,0,32,0,65,0,108,0,108,0,32,0,114,0,105,0,103,0,104,0,116,0,115,0,32,0,82,0,101,0,115,0,101,0,114,0,118,0,101,0,100,0,0,0,90,0,25,0,1,0,79,0,114,0,105,0,103,0,105,0,110,0,97,0,108,0,70,0,105,0,108,0,101,0,110,0,97,0,109,0,101,0,0,0,81,0,82,0,67,0,111,0,100,0,101,0,69,0,110,0,99,0,111,0,100,0,101,0,114,0,76,0,105,0,98,0,114,0,97,0,114,0,121,0,46,0,100,0,108,0,108,0,0,0,0,0,74,0,21,0,1,0,80,0,114,0,111,0,100,0,117,0,99,0,116,0,78,0,97,0,109,0,101,0,0,0,0,0,81,0,82,0,67,0,111,0,100,0,101,0,69,0,110,0,99,0,111,0,100,0,101,0,114,0,76,0,105,0,98,0,114,0,97,0,114,0,121,0,0,0,0,0,48,0,6,0,1,0,80,0,114,0,111,0,100,0,117,0,99,0,116,0,86,0,101,0,114,0,115,0,105,0,111,0,110,0,0,0,50,0,46,0,48,0,46,0,48,0,0,0,56,0,8,0,1,0,65,0,115,0,115,0,101,0,109,0,98,0,108,0,121,0,32,0,86,0,101,0,114,0,115,0,105,0,111,0,110,0,0,0,50,0,46,0,48,0,46,0,48,0,46,0,48,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,160,0,0,12,0,0,0,252,56,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,".Split(',') -as [Byte[]]) | Out-Null;
  }
 }

# Main QR code generation part.
Process {
$exportname = $($qrtext -ireplace "\/\/","" -ireplace ":","" -ireplace "\.","");
$exportname = $exportname -ireplace "\/","";

<## using zxing.portable.dll ##>
if ($toSVG) {

$qrtosvg = [ZXing.BarcodeWriterSvg]::new(); 
$qrtosvg.Format = [ZXing.BarcodeFormat]::QR_CODE;
$qrtosvg.Options.Margin = 50;
$qrtosvg.Options.Height = 20; $qrtosvg.Options.Width = 20;
$svgwriter = $qrtosvg.Write("$($qrtext)");
$svgwriter.Content | Set-Content ".\$($exportname)_SVG.html";
return $(Start-Process ".\$($exportname)_SVG.html");
}
if ($toASCII) {

$qrtoascii = [ZXing.BarcodeWriterGeneric]::new(); 
$qrtoascii.Format =[ZXing.BarcodeFormat]::QR_CODE;
$qrasciipx = $qrtoascii.Encode("$($qrtext)"); 
$qrasciipx.ToString() | Set-Content ".\$($exportname)_ASCII.txt";
return $(Start-Process ".\$($exportname)_ASCII.txt");
}

<## using QRCodeEncoderLibrary.QREncoder.dll ##>
$QRimagewriter = New-Object QRCodeEncoderLibrary.QREncoder -ErrorAction Stop;
$QRimagewriter.Encode("$($qrtext)");
$path = Resolve-Path ".\";
$QRimagewriter.SaveQRCodeToPngFile("$($path)\outputtest.png");
 }
}

<# Export module functions.. #>



Export-ModuleMember -Function @('Convert-NameToMD5',
                                'Get-ImageSize',
                                'Get-ImagePxRnd',
                                'Resolve-RndPx',
                                'Get-ImagePxAreaHash',
                                'Get-ImageMetadata',
                                'Set-ImageMetadata',
                                'ConvertFrom-ColorHexARGB',
                                'Get-GreyValue',
                                'Get-GreyScale',
                                'Get-ImageScaledSize',
                                'ConvertTo-Histogram',
                                'Resolve-HistogramData',
                                'Add-ImageWaterMark',
                                'Test-ImageInfo',
                                'Convert-ToImageSource',
                                'ConvertFrom-ToB64Image',
                                'Get-ImageFromUri',
                                'Get-QRFromText');