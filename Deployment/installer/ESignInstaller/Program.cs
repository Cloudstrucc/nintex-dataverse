using System.Diagnostics;
using System.Net.Http.Headers;
using System.Runtime.InteropServices;

const string REPO_BASE = "https://github.com/Cloudstrucc/nintex-dataverse/raw/main/Deployment";
const string SCHEMA_ZIP = "nintex_1_0_0_1_managed.zip";
const string BROKER_ZIP = "ESignatureBroker_1_0_0_33_managed.zip";
const string SCHEMA_SOLUTION = "nintex";
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

// Step 3: Environment URL
PrintStep(2, "Target environment");
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

// Step 4: Auth
PrintStep(3, "Authenticating to Dataverse");
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

// Step 5: Download solutions
PrintStep(4, "Downloading solution packages");
var tempDir = Path.Combine(Path.GetTempPath(), "esign-installer-" + Guid.NewGuid().ToString("N")[..8]);
Directory.CreateDirectory(tempDir);

var schemaPath = Path.Combine(tempDir, SCHEMA_ZIP);
var brokerPath = Path.Combine(tempDir, BROKER_ZIP);

var localDir = AppContext.BaseDirectory;
var localSchema = Path.Combine(localDir, SCHEMA_ZIP);
var localBroker = Path.Combine(localDir, BROKER_ZIP);

var cwdSchema = Path.Combine(Directory.GetCurrentDirectory(), SCHEMA_ZIP);
var cwdBroker = Path.Combine(Directory.GetCurrentDirectory(), BROKER_ZIP);

var parentDir = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), ".."));
var parentSchema = Path.Combine(parentDir, SCHEMA_ZIP);
var parentBroker = Path.Combine(parentDir, BROKER_ZIP);

if (File.Exists(localSchema) && File.Exists(localBroker))
{
    File.Copy(localSchema, schemaPath, true);
    File.Copy(localBroker, brokerPath, true);
    PrintSuccess("Using local solution files (from installer directory)");
}
else if (File.Exists(cwdSchema) && File.Exists(cwdBroker))
{
    File.Copy(cwdSchema, schemaPath, true);
    File.Copy(cwdBroker, brokerPath, true);
    PrintSuccess("Using local solution files (from current directory)");
}
else if (File.Exists(parentSchema) && File.Exists(parentBroker))
{
    File.Copy(parentSchema, schemaPath, true);
    File.Copy(parentBroker, brokerPath, true);
    PrintSuccess("Using local solution files (from Deployment folder)");
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
        await DownloadFile(http, $"{REPO_BASE}/{SCHEMA_ZIP}", schemaPath);
        PrintSuccess($"Downloaded {SCHEMA_ZIP}");
        await DownloadFile(http, $"{REPO_BASE}/{BROKER_ZIP}", brokerPath);
        PrintSuccess($"Downloaded {BROKER_ZIP}");
    }
    catch (Exception ex)
    {
        PrintError($"Download failed: {ex.Message}");
        PrintWarning("Place the solution zips in the same directory as this installer and try again.");
        Cleanup(tempDir);
        Exit(1);
    }
}

// Step 6: Import schema
PrintStep(5, "Importing Nintex Schema solution (1 of 2)");
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
    Console.Write("  Continue with workflow import anyway? (y/N): ");
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

// Step 7: Import workflows
PrintStep(6, "Importing E-Signature Broker flows (2 of 2)");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("  This deploys 10 Power Automate cloud flows...");
Console.ResetColor();
Console.WriteLine();

var brokerImport = RunCommandLive(pacPath!, $"solution import --path \"{brokerPath}\" --publish-changes --activate-plugins");
if (brokerImport != 0)
{
    PrintError("Workflow solution import failed.");
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  Ensure the schema solution imported successfully first.");
    Console.ResetColor();
    Cleanup(tempDir);
    Exit(1);
}
PrintSuccess($"Workflow solution ({BROKER_SOLUTION} v1.0.0.33) imported successfully");

// Step 8: Verify
PrintStep(7, "Verifying installation");
var listResult = RunCommand(pacPath!, "solution list");
if (listResult != null)
{
    Console.ForegroundColor = ConsoleColor.DarkGray;
    foreach (var line in listResult.Split('\n'))
    {
        if (line.Contains(SCHEMA_SOLUTION, StringComparison.OrdinalIgnoreCase) ||
            line.Contains(BROKER_SOLUTION, StringComparison.OrdinalIgnoreCase))
        {
            Console.ForegroundColor = ConsoleColor.Green;
        }
        Console.WriteLine("  " + line);
        Console.ForegroundColor = ConsoleColor.DarkGray;
    }
    Console.ResetColor();
}

// Step 9: Post-install summary
Console.WriteLine();
PrintDivider();
Console.ForegroundColor = ConsoleColor.Green;
Console.WriteLine("  INSTALLATION COMPLETE");
Console.ResetColor();
PrintDivider();
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.White;
Console.WriteLine("  Next steps:");
Console.ResetColor();
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  1. Configure the connection reference:");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("     Solutions > E-Signature Broker > Connection References");
Console.WriteLine("     Select 'Dataverse (Current Environment)' > Edit > Choose connection");
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  2. Activate all 10 cloud flows:");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("     Solutions > E-Signature Broker > Cloud flows > Turn on each flow");
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  3. Configure Nintex credentials:");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("     Create a record in the cs_assuresign table with your API URL, key, and account ID");
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
    ║          v1.0.0  |  Nintex eSign Integration                 ║
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
