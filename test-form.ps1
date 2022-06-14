<#using module '.\mainapp.psm1'#>
using module '.\mainappscen2.psm1'

Try {
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[string[]]@(
".\AzFnUtil.psm1",
".\LmbdUtil.psm1",
".\ImagesUtil.psm1"
) | %{ Import-Module $_ -Force }

## -CodeCoverage @{ Path = "DirSize.psm1"}; -CodeCoverage @{ Path = "OtherInfo.psm1"};
#Invoke-Pester -Script "$env:USERPROFILE\Downloads\Tests1\MainPart.Tests.ps1" -OutputFile ".\Test-Log.xml" -OutputFormat NUnitXml;
#Invoke-Pester -Script "$env:USERPROFILE\Downloads\Tests1\Output.Tests.ps1" -OutputFile ".\Test-Log.xml" -OutputFormat NUnitXml;
#Invoke-Pester -Script "$env:USERPROFILE\Downloads\Tests1\XamlLayout.Tests.ps1"
#. ".\gen-doc.ps1"
}
Catch {
Write-Error "Error On Loading types or executing scripts." -ErrorAction Stop;
}

Add-Type -TypeDefinition @"
namespace Browser {
public enum BrowserEmulationVersion
{
    Default = 0,
    Version7 = 7000,
    Version8 = 8000,
    Version8Standards = 8888,
    Version9 = 9000,
    Version9Standards = 9999,
    Version10 = 10000,
    Version10Standards = 10001,
    Version11 = 11000,
    Version11Edge = 11001
}

public class InternetExplorerBrowserEmulation
{

    private const string InternetExplorerRootKey = @"Software\Microsoft\Internet Explorer";
    private const string BrowserEmulationKey = InternetExplorerRootKey + @"\Main\FeatureControl\FEATURE_BROWSER_EMULATION";


    public InternetExplorerBrowserEmulation() {}

    public static int GetInternetExplorerMajorVersion()
    {
        int result;

        result = 0;

        try
        {
            Microsoft.Win32.RegistryKey key;

            key = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(InternetExplorerRootKey);

            if (key != null)
            {
                object value;

                value = key.GetValue("svcVersion", null) ?? key.GetValue("Version", null);

                if (value != null)
                {
                    string version;
                    int separator;

                    version = value.ToString();
                    separator = version.IndexOf('.');
                    if (separator != -1)
                    {
                        int.TryParse(version.Substring(0, separator), out result);
                    }
                }
            }
        }
        catch (System.Security.SecurityException)
        {
            // The user does not have the permissions required to read from the registry key.
        }
        catch (System.UnauthorizedAccessException)
        {
            // The user does not have the necessary registry rights.
        }

        return result;
    }

    public static bool SetBrowserEmulationVersion(BrowserEmulationVersion browserEmulationVersion)
    {
        bool result;

        result = false;

        try
        {
            Microsoft.Win32.RegistryKey key;

            key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(BrowserEmulationKey, true);

            if (key != null)
            {
                string programName;

                programName = System.IO.Path.GetFileName(System.Environment.GetCommandLineArgs()[0]);

                if (browserEmulationVersion != BrowserEmulationVersion.Default)
                {
                    // if it's a valid value, update or create the value
                    key.SetValue(programName, (int)browserEmulationVersion, Microsoft.Win32.RegistryValueKind.DWord);
                }
                else
                {
                    // otherwise, remove the existing value
                    key.DeleteValue(programName, false);
                }

                result = true;
            }
        }
        catch (System.Security.SecurityException)
        {
            // The user does not have the permissions required to read from the registry key.
        }
        catch (System.UnauthorizedAccessException)
        {
            // The user does not have the necessary registry rights.
        }

        return result;
    }

    public static bool SetBrowserEmulationVersion()
    {
        int ieVersion;
        BrowserEmulationVersion emulationCode;

        ieVersion = GetInternetExplorerMajorVersion();

        if (ieVersion >= 11)
        {
            emulationCode = BrowserEmulationVersion.Version11;
        }
        else
        {
            switch (ieVersion)
            {
                case 10:
                    emulationCode = BrowserEmulationVersion.Version10;
                    break;
                case 9:
                    emulationCode = BrowserEmulationVersion.Version9;
                    break;
                case 8:
                    emulationCode = BrowserEmulationVersion.Version8;
                    break;
                default:
                    emulationCode = BrowserEmulationVersion.Version11;
                    break;
            }
        }

        return SetBrowserEmulationVersion(emulationCode);
    }

    public static BrowserEmulationVersion GetBrowserEmulationVersion()
    {
        BrowserEmulationVersion result;

        result = BrowserEmulationVersion.Default;

        try
        {
            Microsoft.Win32.RegistryKey key;

            key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(BrowserEmulationKey, true);
            if (key != null)
            {
                string programName;
                object value;

                programName = System.IO.Path.GetFileName(System.Environment.GetCommandLineArgs()[0]);
                value = key.GetValue(programName, null);

                if (value != null)
                {
                    result = (BrowserEmulationVersion)System.Convert.ToInt32(value);
                }
            }
        }
        catch (System.Security.SecurityException)
        {
            // The user does not have the permissions required to read from the registry key.
        }
        catch (System.UnauthorizedAccessException)
        {
            // The user does not have the necessary registry rights.
        }

        return result;
    }


    public static bool IsBrowserEmulationSet()
    {
        return GetBrowserEmulationVersion() != BrowserEmulationVersion.Default;
    }
 }
}
"@ -ReferencedAssemblies @("System","PresentationFramework","Microsoft.CSharp")

[xml]$xaml = (Get-Content ".\wpflayout\mainlayout.xaml");

if (-not [Browser.InternetExplorerBrowserEmulation]::IsBrowserEmulationSet()) {
    [Browser.InternetExplorerBrowserEmulation]::SetBrowserEmulationVersion();
}

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

#Data retrieval/file generation ops.. getDirectorySizes - 0 getOtherSizes - 1 getPartitionSizes - 2 getProcessSizes - 3
$i=0;
$eventsArray = @([Windows.RoutedEventHandler]{infoRetrieval 0; $browserWindow.NavigateToString((Get-Content ".\tmpl.html"))},
                 [Windows.RoutedEventHandler]{infoRetrieval 1; $browserWindow.NavigateToString((Get-Content ".\tmpl.html"))},
                 [Windows.RoutedEventHandler]{infoRetrieval 2; $browserWindow.NavigateToString((Get-Content ".\tmpl.html"))},
                 [Windows.RoutedEventHandler]{infoRetrieval 3; $browserWindow.NavigateToString((Get-Content ".\tmpl.html"))},
                 [Windows.RoutedEventHandler]{$contentlist.ItemsSource = $(Invoke-AzureFunctionEndPoint -InvokeUrlPath "https://functionsampl235.azurewebsites.net/functions/Testapp1/?api-version=2016-08-02");},
                 [Windows.RoutedEventHandler]{$contentlist.ItemsSource = $(Invoke-AWSLambdaEndPoint -RestEndPointName "endpoint9" -AGstageName "stage9" -AGWResourceName "resource9" -LmbdName "lambda23:function4:sample09340-sdjsk3290");});

infoRetrieval;
$contentlist = $window.FindName("ContentBox");
$browserWindow = $window.FindName("WebBrowser");

#Base64 Encoded Image Loading Ops.
$imgs = (@'
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
'@ -split "`r`n");

if (-not (Test-Path ".\tmpl.html")) {
 $browserWindow.NavigateToString("<html><head><h1 style='color:#f2f2f2;font-size:45px;font-family:arial,sans-serif;padding-left:25%;padding-top:10%'> Stats Window </h1></head></html>")
 } else {$browserwindow.NavigateToString($(Get-Content ".\tmpl.html"))}

$xaml.SelectNodes("//*[@Name]") | ?{$_.Name -ilike "*btn*" } | %{
 $window.FindName($_.Name).add_click($eventsArray[$i]);
 $i++;
 }

$xaml.SelectNodes("//*[@Name]") | ?{$_.Name -ilike "_Img*"} | %{
Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name);

}

$_ImgLambda.Source = ConvertFrom-ToB64Image -imgforenc $($imgs[0]);
$_ImgAzureFn.Source = ConvertFrom-ToB64Image -imgforenc $($imgs[1]);

$window.ShowDialog() | Out-Null