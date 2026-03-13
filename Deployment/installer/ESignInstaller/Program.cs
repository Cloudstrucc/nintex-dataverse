using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http.Headers;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

const string REPO_BASE = "https://github.com/Cloudstrucc/nintex-dataverse/raw/main/Deployment";
const string SCHEMA_SOLUTION = "nintex";
const string CONFIG_SOLUTION = "ESignatureConfig";
const string BROKER_SOLUTION = "ESignatureBroker";

var isWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
int stepNum = 0;

// Load .env file if present (check current dir, parent, grandparent, and app base dir)
var envVars = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
foreach (var dir in new[] { Directory.GetCurrentDirectory(),
    Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..")),
    Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "../..")),
    AppContext.BaseDirectory })
{
    var envFile = Path.Combine(dir, ".env");
    if (File.Exists(envFile))
    {
        foreach (var line in File.ReadAllLines(envFile))
        {
            var trimmed = line.Trim();
            if (string.IsNullOrEmpty(trimmed) || trimmed.StartsWith('#')) continue;
            var eqIdx = trimmed.IndexOf('=');
            if (eqIdx <= 0) continue;
            var key = trimmed[..eqIdx].Trim();
            var val = trimmed[(eqIdx + 1)..].Trim();
            if (!string.IsNullOrEmpty(val))
                envVars.TryAdd(key, val);
        }
        break; // Use first .env found
    }
}

PrintBanner();
Console.WriteLine();

// Step 1: Check .NET
PrintStep(++stepNum, "Checking prerequisites");
var dotnetVersion = RunCommand("dotnet", "--version");
if (dotnetVersion == null)
{
    PrintError(".NET SDK is not installed. Install from https://dot.net/download");
    Exit(1);
}
PrintSuccess($".NET SDK {dotnetVersion!.Trim()} found");

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
PrintStep(++stepNum, "Solution type");
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

var SCHEMA_ZIP = $"nintex_1_0_0_2_{suffix}.zip";
var CONFIG_ZIP = $"ESignatureConfig_1_0_0_0_{suffix}.zip";
var BROKER_ZIP = $"ESignatureBroker_1_0_0_42_{suffix}.zip";

PrintSuccess($"{typeLabel} solutions selected");
if (!isManaged)
{
    PrintWarning("Unmanaged solutions can be modified after import. Use managed for production.");
}

// Step 4: Solution selection
PrintStep(++stepNum, "Select solutions to install");
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.Cyan;
Console.WriteLine("  Which solutions would you like to install?");
Console.ResetColor();
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.White;
Console.Write("    [1] ");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("All solutions (recommended for fresh install)");
Console.ForegroundColor = ConsoleColor.White;
Console.Write("    [2] ");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("Schema only     — 16 tables, columns, relationships");
Console.ForegroundColor = ConsoleColor.White;
Console.Write("    [3] ");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("Config only     — 5 environment variables");
Console.ForegroundColor = ConsoleColor.White;
Console.Write("    [4] ");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("Broker only     — 10 Power Automate cloud flows");
Console.ForegroundColor = ConsoleColor.White;
Console.Write("    [5] ");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("Custom selection");
Console.ResetColor();
Console.WriteLine();
Console.Write("  Enter choice (1-5): ");
var selChoice = Console.ReadLine()?.Trim() ?? "1";

bool installSchema = true, installConfig = true, installBroker = true;

switch (selChoice)
{
    case "2":
        installConfig = false;
        installBroker = false;
        break;
    case "3":
        installSchema = false;
        installBroker = false;
        break;
    case "4":
        installSchema = false;
        installConfig = false;
        break;
    case "5":
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine("  For each solution, enter Y to install or N to skip:");
        Console.ResetColor();
        Console.WriteLine();

        Console.ForegroundColor = ConsoleColor.White;
        Console.Write($"    Nintex Schema (v1.0.0.2) [Y/n]: ");
        Console.ResetColor();
        var schIn = Console.ReadLine()?.Trim().ToLower();
        installSchema = schIn != "n" && schIn != "no";

        Console.ForegroundColor = ConsoleColor.White;
        Console.Write($"    E-Signature Config (v1.0.0.0) [Y/n]: ");
        Console.ResetColor();
        var cfgIn = Console.ReadLine()?.Trim().ToLower();
        installConfig = cfgIn != "n" && cfgIn != "no";

        Console.ForegroundColor = ConsoleColor.White;
        Console.Write($"    E-Signature Broker (v1.0.0.42) [Y/n]: ");
        Console.ResetColor();
        var brkIn = Console.ReadLine()?.Trim().ToLower();
        installBroker = brkIn != "n" && brkIn != "no";
        break;
    default: // "1" or anything else = all
        break;
}

if (!installSchema && !installConfig && !installBroker)
{
    PrintError("No solutions selected. Nothing to install.");
    Exit(1);
}

// Count selected solutions for overall progress
int totalSolutions = (installSchema ? 1 : 0) + (installConfig ? 1 : 0) + (installBroker ? 1 : 0);
int completedSolutions = 0;

var selectedNames = new List<string>();
if (installSchema) selectedNames.Add("Schema");
if (installConfig) selectedNames.Add("Config");
if (installBroker) selectedNames.Add("Broker");
PrintSuccess($"Selected: {string.Join(", ", selectedNames)} ({totalSolutions} solution{(totalSolutions > 1 ? "s" : "")})");

// Dependency warnings
if (installBroker && (!installSchema || !installConfig))
{
    Console.WriteLine();
    PrintWarning("The Broker solution depends on Schema and Config.");
    PrintWarning("Ensure they are already installed in the target environment.");
}
if (installConfig && !installSchema)
{
    Console.WriteLine();
    PrintWarning("The Config solution depends on Schema.");
    PrintWarning("Ensure Schema is already installed in the target environment.");
}

// Step 5: Nintex API credentials (only if Config is selected)
// Pre-populate from .env if available
envVars.TryGetValue("NINTEX_API_USERNAME", out var envApiUsername);
envVars.TryGetValue("NINTEX_API_KEY", out var envApiKey);
envVars.TryGetValue("NINTEX_CONTEXT_USERNAME", out var envContextUsername);
envVars.TryGetValue("NINTEX_AUTH_URL", out var envAuthUrl);
envVars.TryGetValue("NINTEX_API_BASE_URL", out var envApiBaseUrl);

string apiUsername = "", apiKey = "", contextUsername = "";
string authUrl = envAuthUrl ?? "https://account.assuresign.net/api/v3.7";
string apiBaseUrl = envApiBaseUrl ?? "https://ca1.assuresign.net/api/documentnow/v3.7";

if (installConfig)
{
    PrintStep(++stepNum, "Nintex eSign API credentials");
    Console.WriteLine();
    Console.ForegroundColor = ConsoleColor.Cyan;
    Console.WriteLine("  These values configure the environment variables used by the");
    Console.WriteLine("  cloud flows to authenticate with the Nintex eSign API.");
    if (envVars.Count > 0)
    {
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("  Values loaded from .env file — press Enter to keep them.");
    }
    Console.ResetColor();
    Console.WriteLine();

    Console.ForegroundColor = ConsoleColor.White;
    if (!string.IsNullOrEmpty(envApiUsername))
        Console.Write($"  Nintex API Username [{envApiUsername}]: ");
    else
        Console.Write("  Nintex API Username: ");
    Console.ResetColor();
    var usernameInput = Console.ReadLine()?.Trim() ?? "";
    apiUsername = string.IsNullOrEmpty(usernameInput) ? (envApiUsername ?? "") : usernameInput;
    if (string.IsNullOrEmpty(apiUsername))
    {
        PrintError("API Username is required.");
        Exit(1);
    }

    Console.ForegroundColor = ConsoleColor.White;
    if (!string.IsNullOrEmpty(envApiKey))
        Console.Write($"  Nintex API Key      [{new string('*', Math.Min(envApiKey.Length, 8))}...]: ");
    else
        Console.Write("  Nintex API Key:      ");
    Console.ResetColor();
    var keyInput = Console.ReadLine()?.Trim() ?? "";
    apiKey = string.IsNullOrEmpty(keyInput) ? (envApiKey ?? "") : keyInput;
    if (string.IsNullOrEmpty(apiKey))
    {
        PrintError("API Key is required.");
        Exit(1);
    }

    Console.ForegroundColor = ConsoleColor.White;
    if (!string.IsNullOrEmpty(envContextUsername))
        Console.Write($"  Context Username    [{envContextUsername}]: ");
    else
        Console.Write("  Context Username:    ");
    Console.ResetColor();
    var ctxInput = Console.ReadLine()?.Trim() ?? "";
    contextUsername = string.IsNullOrEmpty(ctxInput) ? (envContextUsername ?? "") : ctxInput;
    if (string.IsNullOrEmpty(contextUsername))
    {
        PrintError("Context Username is required.");
        Exit(1);
    }

    Console.WriteLine();
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  The following have defaults — press Enter to keep them.");
    Console.ResetColor();
    Console.WriteLine();

    Console.ForegroundColor = ConsoleColor.White;
    Console.Write($"  Auth URL [{authUrl}]: ");
    Console.ResetColor();
    var authUrlInput = Console.ReadLine()?.Trim();
    if (!string.IsNullOrEmpty(authUrlInput)) authUrl = authUrlInput;

    Console.ForegroundColor = ConsoleColor.White;
    Console.Write($"  API Base URL [{apiBaseUrl}]: ");
    Console.ResetColor();
    var apiBaseUrlInput = Console.ReadLine()?.Trim();
    if (!string.IsNullOrEmpty(apiBaseUrlInput)) apiBaseUrl = apiBaseUrlInput;

    Console.WriteLine();
    PrintSuccess("Credentials captured");
    PrintSuccess($"API Username:    {apiUsername}");
    PrintSuccess($"API Key:         {new string('*', Math.Min(apiKey.Length, 8))}...");
    PrintSuccess($"Context User:    {contextUsername}");
    PrintSuccess($"Auth URL:        {authUrl}");
    PrintSuccess($"API Base URL:    {apiBaseUrl}");
}

// Step 6: Environment URL
envVars.TryGetValue("DATAVERSE_ENVIRONMENT_URL", out var envDataverseUrl);

PrintStep(++stepNum, "Target environment");
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.Cyan;
Console.Write("  Enter your Dataverse environment URL");
Console.ResetColor();
Console.WriteLine();
Console.ForegroundColor = ConsoleColor.DarkGray;
if (!string.IsNullOrEmpty(envDataverseUrl))
    Console.Write($"  [{envDataverseUrl}]: ");
else
    Console.Write("  (e.g. https://your-org.crm3.dynamics.com): ");
Console.ResetColor();
var envUrlInput = Console.ReadLine()?.Trim();
var envUrl = string.IsNullOrEmpty(envUrlInput) ? (envDataverseUrl ?? "") : envUrlInput;
if (string.IsNullOrEmpty(envUrl))
{
    PrintError("Environment URL is required.");
    Exit(1);
}
if (!envUrl!.StartsWith("https://"))
{
    envUrl = "https://" + envUrl;
}

// Step 7: Auth
PrintStep(++stepNum, "Authenticating to Dataverse");
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

// Step 8: Download solutions
PrintStep(++stepNum, $"Downloading {typeLabel.ToLower()} solution packages");
var tempDir = Path.Combine(Path.GetTempPath(), "esign-installer-" + Guid.NewGuid().ToString("N")[..8]);
Directory.CreateDirectory(tempDir);

var schemaPath = Path.Combine(tempDir, SCHEMA_ZIP);
var configPath = Path.Combine(tempDir, CONFIG_ZIP);
var brokerPath = Path.Combine(tempDir, BROKER_ZIP);

// Build lists of only selected solutions
var selectedZips = new List<string>();
var selectedPaths = new List<string>();
var selectedLabels = new List<string>();

if (installSchema) { selectedZips.Add(SCHEMA_ZIP); selectedPaths.Add(schemaPath); selectedLabels.Add("Schema"); }
if (installConfig) { selectedZips.Add(CONFIG_ZIP); selectedPaths.Add(configPath); selectedLabels.Add("Config"); }
if (installBroker) { selectedZips.Add(BROKER_ZIP); selectedPaths.Add(brokerPath); selectedLabels.Add("Broker"); }

// Try local directories first
string? sourceDir = null;
foreach (var dir in new[] { AppContext.BaseDirectory, Directory.GetCurrentDirectory(),
    Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..")) })
{
    if (selectedZips.All(z => File.Exists(Path.Combine(dir, z))))
    {
        sourceDir = dir;
        break;
    }
}

if (sourceDir != null)
{
    for (int i = 0; i < selectedZips.Count; i++)
    {
        File.Copy(Path.Combine(sourceDir, selectedZips[i]), selectedPaths[i], true);
        PrintProgressBar($"  Copying {selectedZips[i]}", 1.0);
        Console.WriteLine();
    }
    PrintSuccess($"Using local solution files (from {sourceDir})");
}
else
{
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  Downloading from GitHub...");
    Console.ResetColor();
    using var http = new HttpClient();
    http.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("ESignInstaller", "2.1"));

    try
    {
        for (int i = 0; i < selectedZips.Count; i++)
        {
            await DownloadFileWithProgress(http, $"{REPO_BASE}/{selectedZips[i]}", selectedPaths[i], selectedZips[i]);
            PrintSuccess($"Downloaded {selectedZips[i]}");
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

// Step 9: Inject environment variable values into config solution
if (installConfig)
{
    PrintStep(++stepNum, "Configuring environment variables");
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  Injecting Nintex API credentials into config solution...");
    Console.ResetColor();

    var envVarValues = new Dictionary<string, string>
    {
        ["cs_NintexApiUsername"] = apiUsername,
        ["cs_NintexApiKey"] = apiKey,
        ["cs_NintexContextUsername"] = contextUsername,
        ["cs_NintexAuthUrl"] = authUrl,
        ["cs_NintexApiBaseUrl"] = apiBaseUrl,
    };

    try
    {
        InjectEnvVarDefaults(configPath, envVarValues);
        PrintSuccess("Environment variable values configured in solution package");
    }
    catch (Exception ex)
    {
        PrintError($"Failed to configure environment variables: {ex.Message}");
        PrintWarning("Values can be set manually after import via Solutions > E-Signature Configuration");
    }
}

// Import solutions with overall progress
PrintOverallProgress(completedSolutions, totalSolutions);

if (installSchema)
{
    PrintStep(++stepNum, $"Importing Nintex Schema — {typeLabel} ({completedSolutions + 1} of {totalSolutions})");
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  This creates 16 tables, columns, and relationships...");
    Console.ResetColor();
    Console.WriteLine();

    var schemaImport = await RunCommandWithSpinner(pacPath!, $"solution import --path \"{schemaPath}\" --publish-changes --activate-plugins", "Importing Schema");
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
        PrintSuccess($"Schema solution ({SCHEMA_SOLUTION} v1.0.0.2) imported successfully");
    }
    completedSolutions++;
    PrintOverallProgress(completedSolutions, totalSolutions);
}

if (installConfig)
{
    PrintStep(++stepNum, $"Importing E-Signature Config — {typeLabel} ({completedSolutions + 1} of {totalSolutions})");
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  This creates 5 environment variables with your Nintex API credentials...");
    Console.ResetColor();
    Console.WriteLine();

    var configImport = await RunCommandWithSpinner(pacPath!, $"solution import --path \"{configPath}\" --publish-changes --activate-plugins", "Importing Config");
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
        PrintSuccess("Environment variables set with your Nintex API credentials");
    }
    completedSolutions++;
    PrintOverallProgress(completedSolutions, totalSolutions);
}

if (installBroker)
{
    PrintStep(++stepNum, $"Importing E-Signature Broker — {typeLabel} ({completedSolutions + 1} of {totalSolutions})");
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  This deploys 10 Power Automate cloud flows...");
    Console.ResetColor();
    Console.WriteLine();

    var brokerImport = await RunCommandWithSpinner(pacPath!, $"solution import --path \"{brokerPath}\" --publish-changes --activate-plugins", "Importing Broker");
    if (brokerImport != 0)
    {
        PrintError("Workflow solution import failed.");
        Console.ForegroundColor = ConsoleColor.DarkGray;
        Console.WriteLine("  Ensure schema and config solutions imported successfully first.");
        Console.ResetColor();
        Cleanup(tempDir);
        Exit(1);
    }
    PrintSuccess($"Workflow solution ({BROKER_SOLUTION} v1.0.0.42) imported successfully");
    completedSolutions++;
    PrintOverallProgress(completedSolutions, totalSolutions);
}

// Verify
PrintStep(++stepNum, "Verifying installation");
var listResult = RunCommand(pacPath!, "solution list");
if (listResult != null)
{
    Console.ForegroundColor = ConsoleColor.DarkGray;
    foreach (var line in listResult.Split('\n'))
    {
        bool highlight = (installSchema && line.Contains(SCHEMA_SOLUTION, StringComparison.OrdinalIgnoreCase)) ||
                         (installConfig && line.Contains(CONFIG_SOLUTION, StringComparison.OrdinalIgnoreCase)) ||
                         (installBroker && line.Contains(BROKER_SOLUTION, StringComparison.OrdinalIgnoreCase));
        if (highlight)
            Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("  " + line);
        Console.ForegroundColor = ConsoleColor.DarkGray;
    }
    Console.ResetColor();
}

// Post-install summary
Console.WriteLine();
PrintDivider();
Console.ForegroundColor = ConsoleColor.Green;
Console.WriteLine($"  INSTALLATION COMPLETE ({typeLabel.ToUpper()}) — {totalSolutions} solution{(totalSolutions > 1 ? "s" : "")} installed");
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
Console.WriteLine("  3. Test the integration:");
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine("     Create a cs_envelope record and verify the Prepare Envelope flow triggers");
Console.ResetColor();
Console.WriteLine();
if (installConfig)
{
    Console.ForegroundColor = ConsoleColor.DarkGray;
    Console.WriteLine("  Environment variables were set during installation.");
    Console.WriteLine("  To change them later: Solutions > E-Signature Configuration > Environment Variables");
}
Console.ForegroundColor = ConsoleColor.DarkGray;
Console.WriteLine();
Console.WriteLine("  Full documentation: https://github.com/Cloudstrucc/nintex-dataverse/blob/main/Deployment/README.md");
Console.ResetColor();
Console.WriteLine();

Cleanup(tempDir);
Console.Write("  Press Enter to exit...");
Console.ReadLine();

// ─── Helper Methods ───

static void InjectEnvVarDefaults(string zipPath, Dictionary<string, string> values)
{
    using var archive = ZipFile.Open(zipPath, ZipArchiveMode.Update);
    foreach (var entry in archive.Entries.ToList())
    {
        if (!entry.FullName.StartsWith("environmentvariabledefinitions/") ||
            !entry.FullName.EndsWith("/environmentvariabledefinition.xml"))
            continue;

        var parts = entry.FullName.Split('/');
        if (parts.Length < 3) continue;
        var schemaName = parts[1];

        if (!values.TryGetValue(schemaName, out var newValue) || string.IsNullOrEmpty(newValue))
            continue;

        string xml;
        using (var reader = new StreamReader(entry.Open()))
        {
            xml = reader.ReadToEnd();
        }

        xml = Regex.Replace(xml,
            @"<defaultvalue>[^<]*</defaultvalue>",
            $"<defaultvalue>{EscapeXml(newValue)}</defaultvalue>");

        entry.Delete();
        var newEntry = archive.CreateEntry(entry.FullName);
        using var writer = new StreamWriter(newEntry.Open());
        writer.Write(xml);
    }
}

static string EscapeXml(string value)
{
    return value
        .Replace("&", "&amp;")
        .Replace("<", "&lt;")
        .Replace(">", "&gt;")
        .Replace("\"", "&quot;")
        .Replace("'", "&apos;");
}

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
    ║          v2.1.0  |  Nintex eSign Integration                 ║
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

static void PrintProgressBar(string label, double fraction)
{
    const int barWidth = 30;
    fraction = Math.Clamp(fraction, 0.0, 1.0);
    int filled = (int)(fraction * barWidth);
    int empty = barWidth - filled;
    var bar = new string('\u2588', filled) + new string('\u2591', empty);
    int percent = (int)(fraction * 100);

    Console.Write($"\r{label}  [{bar}] {percent,3}%");
}

static void PrintSpinner(string label, int tick, TimeSpan elapsed)
{
    const int barWidth = 30;
    char[] spinChars = ['|', '/', '-', '\\'];
    char spin = spinChars[tick % spinChars.Length];

    // Bouncing bar effect
    int pos = tick % (barWidth * 2);
    if (pos >= barWidth) pos = barWidth * 2 - pos - 1;

    var bar = new char[barWidth];
    Array.Fill(bar, '\u2591');
    // Draw a 3-wide highlight that bounces
    for (int i = Math.Max(0, pos - 1); i <= Math.Min(barWidth - 1, pos + 1); i++)
        bar[i] = '\u2588';

    int secs = (int)elapsed.TotalSeconds;
    Console.Write($"\r  {label}  [{new string(bar)}] {spin} {secs}s");
}

static void PrintOverallProgress(int completed, int total)
{
    if (total <= 1) return;
    double fraction = (double)completed / total;
    const int barWidth = 30;
    int filled = (int)(fraction * barWidth);
    int empty = barWidth - filled;
    var bar = new string('\u2588', filled) + new string('\u2591', empty);

    Console.WriteLine();
    Console.ForegroundColor = ConsoleColor.Cyan;
    Console.Write($"  Overall Progress  [{bar}]  {completed} of {total} solution{(total > 1 ? "s" : "")}");
    Console.ResetColor();
    Console.WriteLine();
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

static async Task<int> RunCommandWithSpinner(string cmd, string args, string label)
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

    try
    {
        using var proc = Process.Start(psi);
        if (proc == null) return 1;

        var sw = Stopwatch.StartNew();
        int tick = 0;

        // Read output asynchronously to prevent deadlock
        var outputTask = proc.StandardOutput.ReadToEndAsync();
        var errorTask = proc.StandardError.ReadToEndAsync();

        while (!proc.HasExited)
        {
            PrintSpinner(label, tick++, sw.Elapsed);
            await Task.Delay(150);
        }

        await outputTask;
        await errorTask;
        sw.Stop();

        // Clear spinner line and print final status
        Console.Write("\r" + new string(' ', Console.BufferWidth > 0 ? Math.Min(Console.BufferWidth, 120) : 80));
        Console.Write("\r");

        int secs = (int)sw.Elapsed.TotalSeconds;
        if (proc.ExitCode == 0)
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine($"  ✓ {label} completed in {secs}s");
            Console.ResetColor();
        }
        else
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"  ✗ {label} failed after {secs}s");
            Console.ResetColor();
            var err = await errorTask;
            if (!string.IsNullOrWhiteSpace(err))
            {
                Console.ForegroundColor = ConsoleColor.DarkGray;
                foreach (var line in err.Split('\n').Take(5))
                    Console.WriteLine($"    {line}");
                Console.ResetColor();
            }
        }

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

static async Task DownloadFileWithProgress(HttpClient http, string url, string destPath, string fileName)
{
    using var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
    response.EnsureSuccessStatusCode();

    var totalBytes = response.Content.Headers.ContentLength;
    await using var contentStream = await response.Content.ReadAsStreamAsync();
    await using var fs = File.Create(destPath);

    var buffer = new byte[8192];
    long downloaded = 0;
    int bytesRead;

    while ((bytesRead = await contentStream.ReadAsync(buffer)) > 0)
    {
        await fs.WriteAsync(buffer.AsMemory(0, bytesRead));
        downloaded += bytesRead;

        if (totalBytes.HasValue && totalBytes.Value > 0)
        {
            double fraction = (double)downloaded / totalBytes.Value;
            PrintProgressBar($"  {fileName}", fraction);
        }
        else
        {
            // Indeterminate: show downloaded size
            Console.Write($"\r  {fileName}  {downloaded / 1024}KB downloaded...");
        }
    }

    // Clear progress line
    Console.Write("\r" + new string(' ', Console.BufferWidth > 0 ? Math.Min(Console.BufferWidth, 120) : 80));
    Console.Write("\r");
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
