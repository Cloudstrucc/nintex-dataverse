# Build Script for Nintex Dataverse Proxy Plugin
# Run this in Visual Studio Developer PowerShell

param(
    [string]$Configuration = "Release"
)

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Nintex Dataverse Proxy Builder" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check for strong name key
if (-not (Test-Path "NintexDataverseProxy.snk")) {
    Write-Host "Creating strong name key..." -ForegroundColor Yellow
    sn -k NintexDataverseProxy.snk
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Strong name key created" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create strong name key" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ Strong name key exists" -ForegroundColor Green
}

Write-Host ""

# Step 2: Restore NuGet packages
Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
dotnet restore
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Packages restored" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to restore packages" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Build the project
Write-Host "Building project ($Configuration)..." -ForegroundColor Yellow
dotnet build --configuration $Configuration --no-restore
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Build successful" -ForegroundColor Green
} else {
    Write-Host "✗ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Show output location
$outputPath = "bin\$Configuration\net462\NintexDataverseProxy.dll"
if (Test-Path $outputPath) {
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Build Complete!" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Assembly Location:" -ForegroundColor Yellow
    Write-Host "  $outputPath" -ForegroundColor White
    Write-Host ""
    Write-Host "File Size:" -ForegroundColor Yellow
    $fileInfo = Get-Item $outputPath
    Write-Host "  $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Open Plugin Registration Tool" -ForegroundColor White
    Write-Host "  2. Register this assembly" -ForegroundColor White
    Write-Host "  3. Configure secure configuration with Nintex credentials" -ForegroundColor White
    Write-Host "  4. Register plugin steps (see DEPLOYMENT-GUIDE.md)" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "✗ Assembly not found at expected location" -ForegroundColor Red
    exit 1
}
