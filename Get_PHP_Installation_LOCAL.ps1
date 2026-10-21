<#
.SYNOPSIS
    Detects PHP installations and related web servers on Windows Server.
.DESCRIPTION
    Scans for active processes, services, PATH variables, and common directories
    to help identify PHP installations vulnerable to CVE-2026-109618 & CVE-2026-109619 (PHP2Shell).
#>

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " PHP Usage and Web Server Detection Tool (PHP2Shell Mitigation) " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Checking for active PHP processes, services, and common paths...`n"

# 1. Check Running Processes
Write-Host "[*] Checking Running Processes..." -ForegroundColor Cyan
$processNames = @("php", "php-cgi", "php-fpm", "httpd", "nginx", "w3wp")
$activeProcesses = Get-Process -Name $processNames -ErrorAction SilentlyContinue | Select-Object Name, Id, Path

if ($activeProcesses) {
    Write-Host "Found potentially relevant processes (Check if these are serving PHP):" -ForegroundColor Yellow
    $activeProcesses | Format-Table -AutoSize
} else {
    Write-Host "No active PHP or common web server processes found running.`n" -ForegroundColor Green
}

# 2. Check Windows Services
Write-Host "[*] Checking Web Server Services (IIS, Apache, Nginx)..." -ForegroundColor Cyan
$services = Get-Service -Name "W3SVC", "Apache*", "Nginx*" -ErrorAction SilentlyContinue

if ($services) {
    Write-Host "Found installed web server services:" -ForegroundColor Yellow
    $services | Select-Object Name, DisplayName, Status | Format-Table -AutoSize
} else {
    Write-Host "No common web server services found.`n" -ForegroundColor Green
}

# 3. Check Environment Variables (PATH)
Write-Host "[*] Checking System PATH for PHP..." -ForegroundColor Cyan
$pathVar = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$phpInPath = $pathVar -split ';' | Where-Object { $_ -match "php" }

if ($phpInPath) {
    Write-Host "PHP directories found in System PATH:" -ForegroundColor Yellow
    $phpInPath | ForEach-Object { Write-Host " - $_" }
    Write-Host ""
} else {
    Write-Host "PHP not found in System PATH.`n" -ForegroundColor Green
}

# 4. Check Common Default Installation Paths
Write-Host "[*] Checking Common Installation Paths..." -ForegroundColor Cyan
$commonPaths = @(
    "C:\php\php.exe",
    "C:\xampp\php\php.exe",
    "C:\tools\php\php.exe",
    "C:\Program Files\PHP\*\php.exe",
    "C:\Program Files (x86)\PHP\*\php.exe"
)

$foundExecutables = @()
foreach ($path in$commonPaths) {
    # Resolve wildcards
    $resolvedPaths = Resolve-Path -Path$path -ErrorAction SilentlyContinue
    if ($resolvedPaths) {
        $foundExecutables +=$resolvedPaths.Path
    }
}

if ($foundExecutables) {
    Write-Host "Found PHP executables in common locations:" -ForegroundColor Yellow
    foreach ($exe in$foundExecutables) {
        Write-Host " - $exe"
        # Attempt to extract the PHP version
        try {
            $versionOutput = &$exe -v 2>&1
            $versionLine = ($versionOutput -split "`n")[0]
            Write-Host "   Version Info: $versionLine" -ForegroundColor Gray
        } catch {
            Write-Host "   [Could not execute to determine version]" -ForegroundColor Red
        }
    }
} else {
    Write-Host "No PHP executables found in standard default locations." -ForegroundColor Green
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "Scan Complete."
Write-Host "If PHP is found, verify if it serves web requests. To mitigate"
Write-Host "CVE-2026-109618 and CVE-2026-109619, update immediately to:"
Write-Host "PHP 8.5.12, 8.4.27, 8.3.36, or 8.2.35."
Write-Host "================================================================" -ForegroundColor Cyan
