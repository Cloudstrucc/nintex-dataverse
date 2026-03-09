using System.Diagnostics;
using System.Net.Http.Headers;
using System.Runtime.InteropServices;

const string REPO_BASE = "https://github.com/Cloudstrucc/nintex-dataverse/raw/main/Deployment";
const string SCHEMA_SOLUTION = "nintex";
const string CONFIG_SOLUTION = "ESignatureConfig";
const string BROKER_SOLUTION = "ESignatureBroker";

var isWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);

PrintBanner();
Console.WriteLine();

// Step 1: Check .NET
PrintStep(1, "Checking prerequisites");
var dotnetVersion = RunCommand("dotnet", "--version");
if (dotnetVersion == null)
{
    PrintError(".NET SDK is not installed. Install from https://dot.net/download");
    Exit(1);
}
PrintSuccess($".NET SDK {dotnetVersion.Trim()} found");

// Step 2: Check PAC CLI
var pacPath = FindPac();
if (pacPath == null)
{
    PrintWarning("PAC CLI not found. Installing...");
    var installResult = RunCommand("dotnet", "tool install --global Microsoft.PowerApps.CLI.Tool");
    if (installResult == null)
    {
        PrintError("Failed to install PAC CLI. Run manually: dotnet tool install --global Microsoft.PowerApps.CLI.Tool");
        Exit(1);
    }
    pacPath = FindPac();
    if (pacPath == null)
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var toolsPath = Path.Combine(home, ".dotnet", "tools", isWindows ? "pac.exe" : "pac");
        if (File.Exists(toolsPath))
            pacPath = toolsPath;
        else
        {
            PrintError("PAC CLI installed but not found in PATH. Restart your terminal and run this installer again.");
            Exit(1);
        }
    }
    PrintSuccess("PAC CLI installed");
}
else
{
    PrintSuccess($"PAC CLI found at {pacPath}");
}

// Step 3: Solution type
PrintStep(2, "Solution type");
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  Select solution type to install:");
Console.ResetColor();
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.White;
Console.Write("    [1] ");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("Managed   — Locked, for production / client environments");
Console.ForegroundColor = ConsoleColor.White;
Console.Write("    [2] ");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("Unmanaged — Editable, for development / sandbox environments");
Console.ResetColor();
Console.WriteLine();
Console.Write("  Enter choice (1 or 2): ");
var typeChoice = Console.ReadLine()?.Trim();
var isManaged = typeChoice != "2";
var suffix = isManaged ? "managed" : "unmanaged";
var typeLabel = isManaged ? "Managed" : "Unmanaged";

var SCHEMA_ZIP = $"nintex_1_0_0_1_{suffix}.zip";
var CONFIG_ZIP = $"ESignatureConfig_1_0_0_0_{suffix}.zip";
var BROKER_ZIP = $"ESignatureBroker_1_0_0_34_{suffix}.zip";

PrintSuccess($"{typeLabel} solutions selected");
if (!isManaged)
{
    PrintWarning("Unmanaged solutions can be modified after import. Use managed for production.");
}

// Step 4: Environment URL
PrintStep(3, "Target environment");
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.Cyan;
Console.Write("  Enter your Dataverse environment URL");
Console.ResetColor();
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.Write("  (e.g. https://your-org.crm3.dynamics.com): ");
Console.ResetColor();
var envUrl = Console.ReadLine()?.Trim();
if (string.IsNullOrEmpty(envUrl))
{
    PrintError("Environment URL is required.");
    Exit(1);
}
if (!envUrl!.StartsWith("https://"))
{
    envUrl = "https://" + envUrl;
}

// Step 5: Auth
PrintStep(4, "Authenticating to Dataverse");
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.Yellow;
Console.WriteLine("  A browser window will open for authentication.");
Console.WriteLine("  Sign in with an account that has System Administrator or");
Console.WriteLine("  System Customizer role on the target environment.");
Console.ResetColor();
Console.WriteLine();
Console.Write("  Press Enter to continue...");
Console.ReadLine();

var authResult = RunCommandLive(pacPath!, $"auth create --environment \"{envUrl}\"");
if (authResult != 0)
{
    PrintError("Authentication failed. Check your credentials and environment URL.");
    Console.WriteLine();
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  Tip: If you already have an auth profile, try:");
    Console.WriteLine($"    pac auth select --environment \"{envUrl}\"");
    Console.ResetColor();
    Console.WriteLine();
    Console.Write("  Continue anyway? (y/N): ");
    var cont = Console.ReadLine()?.Trim().ToLower();
    if (cont != "y" && cont != "yes")
        Exit(1);
}
else
{
    PrintSuccess("Authenticated successfully");
}

// Step 6: Download solutions
PrintStep(5, $"Downloading {typeLabel.ToLower()} solution packages");
var tempDir = Path.Combine(Path.GetTempPath(), "esign-installer-" + Guid.NewGuid().ToString("N")[..8]);
Directory.CreateDirectory(tempDir);

var schemaPath = Path.Combine(tempDir, SCHEMA_ZIP);
var configPath = Path.Combine(tempDir, CONFIG_ZIP);
var brokerPath = Path.Combine(tempDir, BROKER_ZIP);

string[] allZips = [SCHEMA_ZIP, CONFIG_ZIP, BROKER_ZIP];
string[] allPaths = [schemaPath, configPath, brokerPath];

// Try local directories first
string? sourceDir = null;
foreach (var dir in new[] { AppContext.BaseDirectory, Directory.GetCurrentDirectory(),
    Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..")) })
{
    if (allZips.All(z => File.Exists(Path.Combine(dir, z))))
    {
        sourceDir = dir;
        break;
    }
}

if (sourceDir != null)
{
    for (int i = 0; i < allZips.Length; i++)
        File.Copy(Path.Combine(sourceDir, allZips[i]), allPaths[i], true);
    PrintSuccess($"Using local solution files (from {sourceDir})");
}
else
{
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  Downloading from GitHub...");
    Console.ResetColor();
    using var http = new HttpClient();
    http.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("ESignInstaller", "1.0"));

    try
    {
        for (int i = 0; i < allZips.Length; i++)
        {
            await DownloadFile(http, $"{REPO_BASE}/{allZips[i]}", allPaths[i]);
            PrintSuccess($"Downloaded {allZips[i]}");
        }
    }
    catch (Exception ex)
    {
        PrintError($"Download failed: {ex.Message}");
        PrintWarning("Place the solution zips in the same directory as this installer and try again.");
        Cleanup(tempDir);
        Exit(1);
    }
}

// Step 7: Import schema
PrintStep(6, $"Importing Nintex Schema — {typeLabel} (1 of 3)");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("  This creates 16 tables, columns, and relationships...");
Console.ResetColor();
Console.WriteLine();

var schemaImport = RunCommandLive(pacPath!, $"solution import --path \"{schemaPath}\" --publish-changes --activate-plugins");
if (schemaImport != 0)
{
    PrintError("Schema solution import failed.");
    Console.WriteLine();
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  Common causes:");
    Console.WriteLine("  - Solution already imported at same or higher version");
    Console.WriteLine("  - Missing permissions (need System Administrator role)");
    Console.WriteLine("  - Environment not provisioned with Dataverse");
    Console.ResetColor();
    Console.WriteLine();
    Console.Write("  Continue anyway? (y/N): ");
    var cont = Console.ReadLine()?.Trim().ToLower();
    if (cont != "y" && cont != "yes")
    {
        Cleanup(tempDir);
        Exit(1);
    }
}
else
{
    PrintSuccess($"Schema solution ({SCHEMA_SOLUTION} v1.0.0.1) imported successfully");
}

// Step 8: Import config (environment variables)
PrintStep(7, $"Importing E-Signature Config — {typeLabel} (2 of 3)");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("  This creates 5 environment variables for Nintex API credentials...");
Console.ResetColor();
Console.WriteLine();

var configImport = RunCommandLive(pacPath!, $"solution import --path \"{configPath}\" --publish-changes --activate-plugins");
if (configImport != 0)
{
    PrintError("Config solution import failed.");
    Console.Write("  Continue anyway? (y/N): ");
    var cont2 = Console.ReadLine()?.Trim().ToLower();
    if (cont2 != "y" && cont2 != "yes")
    {
        Cleanup(tempDir);
        Exit(1);
    }
}
else
{
    PrintSuccess($"Config solution ({CONFIG_SOLUTION} v1.0.0.0) imported successfully");
}

// Step 9: Import workflows
PrintStep(8, $"Importing E-Signature Broker — {typeLabel} (3 of 3)");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("  This deploys 10 Power Automate cloud flows...");
Console.ResetColor();
Console.WriteLine();

var brokerImport = RunCommandLive(pacPath!, $"solution import --path \"{brokerPath}\" --publish-changes --activate-plugins");
if (brokerImport != 0)
{
    PrintError("Workflow solution import failed.");
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  Ensure schema and config solutions imported successfully first.");
    Console.ResetColor();
    Cleanup(tempDir);
    Exit(1);
}
PrintSuccess($"Workflow solution ({BROKER_SOLUTION} v1.0.0.34) imported successfully");

// Step 10: Verify
PrintStep(9, "Verifying installation");
var listResult = RunCommand(pacPath!, "solution list");
if (listResult != null)
{
    Console.ForegroundColor = ConsoleColor.DarkGray;
    foreach (var line in listResult.Split('\n'))
    {
        if (line.Contains(SCHEMA_SOLUTION, StringComparison.OrdinalIgnoreCase) ||
            line.Contains(CONFIG_SOLUTION, StringComparison.OrdinalIgnoreCase) ||
            line.Contains(BROKER_SOLUTION, StringComparison.OrdinalIgnoreCase))
        {
            Console.ForegroundColor = ConsoleColor.Green;
        }
        Console.WriteLine("  " + line);
        Console.ForegroundColor = ConsoleColor.DarkGray;
    }
    Console.ResetColor();
}

// Post-install summary
Console.WriteLine();
PrintDivider();
Console.ForegroundColor = ConsoleColor.Green;
Console.WriteLine($"  INSTALLATION COMPLETE ({typeLabel.ToUpper()})");
Console.ResetColor();
PrintDivider();
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.White;
Console.WriteLine("  Next steps:");
Console.ResetColor();
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  1. Set environment variable values:");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("     Solutions > E-Signature Configuration > Environment Variables");
Console.WriteLine("     Set values for: Nintex API Username, API Key, Context Username");
Console.WriteLine("     (Auth URL and API Base URL have defaults — only change if needed)");
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  2. Configure the connection reference:");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("     Solutions > E-Signature Broker > Connection References");
Console.WriteLine("     Select 'Dataverse (Current Environment)' > Edit > Choose connection");
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  3. Activate all 10 cloud flows:");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("     Solutions > E-Signature Broker > Cloud flows > Turn on each flow");
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  4. Test the integration:");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("     Create a cs_envelope record and verify the Prepare Envelope flow triggers");
Console.ResetColor();
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("  Full documentation: https://github.com/Cloudstrucc/nintex-dataverse/blob/main/Deployment/README.md");
Console.ResetColor();
Console.WriteLine();

Cleanup(tempDir);
Console.Write("  Press Enter to exit...");
Console.ReadLine();

// ─── Helper Methods ───

static void PrintBanner()
{
    Console.Clear();
    Console.ForegroundColor = ConsoleColor.DarkRed;
    Console.WriteLine(@"
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║");
    Console.ForegroundColor = ConsoleColor.White;
    Console.WriteLine(@"    ║        ██████╗ ██╗      ██████╗ ██╗   ██╗ ██████╗           ║
    ║       ██╔════╝ ██║     ██╔═══██╗██║   ██║ ██╔══██╗          ║
    ║       ██║      ██║     ██║   ██║██║   ██║ ██║  ██║          ║
    ║       ██║      ██║     ██║   ██║██║   ██║ ██║  ██║          ║
    ║       ╚██████╗ ███████╗╚██████╔╝╚██████╔╝ ██████╔╝          ║
    ║        ╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝  ╚═════╝           ║");
    Console.ForegroundColor = ConsoleColor.DarkRed;
    Console.WriteLine(@"    ║                  S T R U C C                                 ║");
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine(@"    ║                                                              ║
    ║          E-Signature Broker — Dataverse Installer            ║
    ║          v1.1.0  |  Nintex eSign Integration                 ║
    ║                                                              ║");
    Console.ForegroundColor = ConsoleColor.DarkRed;
    Console.WriteLine(@"    ╚══════════════════════════════════════════════════════════════╝");
    Console.ResetColor();
}

static void PrintStep(int n, string title)
{
    Console.WriteLine();
    Console.ForegroundColor = ConsoleColor.DarkRed;
    Console.Write($"  [{n}] ");
    Console.ForegroundColor = ConsoleColor.White;
    Console.WriteLine(title.ToUpper());
    Console.ResetColor();
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  " + new string('─', 56));
    Console.ResetColor();
}

static void PrintSuccess(string msg)
{
    Console.ForegroundColor = ConsoleColor.Green;
    Console.Write("  ✓ ");
    Console.ResetColor();
    Console.WriteLine(msg);
}

static void PrintWarning(string msg)
{
    Console.ForegroundColor = ConsoleColor.Yellow;
    Console.Write("  ⚠ ");
    Console.ResetColor();
    Console.WriteLine(msg);
}

static void PrintError(string msg)
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.Write("  ✗ ");
    Console.ResetColor();
    Console.WriteLine(msg);
}

static void PrintDivider()
{
    Console.ForegroundColor = ConsoleColor.DarkRed;
    Console.WriteLine("  " + new string('═', 56));
    Console.ResetColor();
}

static string? FindPac()
{
    try
    {
        var result = RunCommand("which", "pac");
        if (result != null) return result.Trim();
    }
    catch { }

    try
    {
        var result = RunCommand("where", "pac");
        if (result != null) return result.Trim().Split('\n')[0].Trim();
    }
    catch { }

    var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    var paths = new[]
    {
        Path.Combine(home, ".dotnet", "tools", "pac"),
        Path.Combine(home, ".dotnet", "tools", "pac.exe"),
        "/usr/local/bin/pac",
    };

    foreach (var p in paths)
        if (File.Exists(p))
            return p;

    return null;
}

static string? RunCommand(string cmd, string args)
{
    try
    {
        var psi = new ProcessStartInfo
        {
            FileName = cmd,
            Arguments = args,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        using var proc = Process.Start(psi);
        if (proc == null) return null;
        var output = proc.StandardOutput.ReadToEnd();
        proc.WaitForExit(30000);
        return proc.ExitCode == 0 ? output : null;
    }
    catch
    {
        return null;
    }
}

static int RunCommandLive(string cmd, string args)
{
    try
    {
        var psi = new ProcessStartInfo
        {
            FileName = cmd,
            Arguments = args,
            UseShellExecute = false,
            CreateNoWindow = false,
        };
        using var proc = Process.Start(psi);
        if (proc == null) return 1;
        proc.WaitForExit();
        return proc.ExitCode;
    }
    catch (Exception ex)
    {
        Console.ForegroundColor = ConsoleColor.Red;
        Console.WriteLine($"  Error: {ex.Message}");
        Console.ResetColor();
        return 1;
    }
}

static async Task DownloadFile(HttpClient http, string url, string destPath)
{
    using var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
    response.EnsureSuccessStatusCode();
    await using var fs = File.Create(destPath);
    await response.Content.CopyToAsync(fs);
}

static void Cleanup(string tempDir)
{
    try { Directory.Delete(tempDir, true); } catch { }
}

static void Exit(int code)
{
    Console.WriteLine();
    Console.Write("  Press Enter to exit...");
    Console.ReadLine();
    Environment.Exit(code);
}
