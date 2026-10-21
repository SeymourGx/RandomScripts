# Local-Only PHP Audit Script for DMZ / Workgroup Servers
[CmdletBinding()]
param(
    [string]$ExportPath = "C:\Temp\PHP_Audit_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
)

$HostName =$env:COMPUTERNAME
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Starting PHP Audit on Local Host: $HostName" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$Results = [System.Collections.Generic.List[PSObject]]::new()

# 1. Check Running Processes
Write-Host "[*] Checking running processes..." -ForegroundColor Gray
$runningProc = Get-Process -Name "php*", "php-cgi*", "php-fpm*" -ErrorAction SilentlyContinue
if ($runningProc) {
    foreach ($proc in $runningProc) {$Results.Add([PSCustomObject]@{
            Category    = "Running Process"
            Path        = $proc.Path
            Details     = "PID: $($proc.Id) | Process: $($proc.Name)"
        })
    }
}

# 2. Check System/Machine PATH Environment Variables
Write-Host "[*] Checking System PATH environment variables..." -ForegroundColor Gray
$envPath = [Environment]::GetEnvironmentVariable("PATH", "Machine") -split ";"
foreach ($path in$envPath) {
    if ($path -and (Test-Path$path)) {
        $phpInPath = Get-ChildItem -Path$path -Filter "php*.exe" -ErrorAction SilentlyContinue
        foreach ($bin in $phpInPath) {$Results.Add([PSCustomObject]@{
                Category    = "System PATH"
                Path        = $bin.FullName
                Details     = "Version: $(($bin.VersionInfo).FileVersion)"
            })
        }
    }
}

# 3. Search Common Directory Targets
Write-Host "[*] Scanning standard PHP directory paths..." -ForegroundColor Gray
$targetDirectories = @(
    "C:\php",
    "C:\Program Files\PHP",
    "C:\Program Files (x86)\PHP",
    "C:\inetpub",
    "C:\xampp\php",
    "C:\wamp64\bin\php",
    "C:\wamp\bin\php",
    "C:\Apache24"
)

foreach ($dir in$targetDirectories) {
    if (Test-Path $dir) {
        $foundBins = Get-ChildItem -Path$dir -Filter "php*.exe" -Recurse -ErrorAction SilentlyContinue
        foreach ($bin in $foundBins) {$Results.Add([PSCustomObject]@{
                Category    = "Directory Search"
                Path        = $bin.FullName
                Details     = "Version: $(($bin.VersionInfo).FileVersion)"
            })
        }
    }
}

# 4. Check IIS Handler Mappings
Write-Host "[*] Checking IIS Handler Mappings..." -ForegroundColor Gray
if (Get-Module -ListAvailable -Name WebAdministration) {
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    $phpHandlers = Get-WebConfigurationProperty -Filter 'system.webServer/handlers' -Name 'collection' -ErrorAction SilentlyContinue |
                   Where-Object { $_.path -like '*.php*' -or$_.scriptProcessor -like '*php*' }
    
    foreach ($handler in $phpHandlers) {$Results.Add([PSCustomObject]@{
            Category    = "IIS Handler"
            Path        = $handler.scriptProcessor
            Details     = "Handler Name: $($handler.name) | Route: $($handler.path)"
        })
    }
}

# Display & Export Output
if ($Results.Count -gt 0) {
    Write-Host "`n[!] DETECTED: PHP components found on $HostName:`n" -ForegroundColor Yellow
    $Results | Format-Table -AutoSize
    
    # Save output log locally
    $logDir = Split-Path $ExportPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $Results | Out-File -FilePath $ExportPath
    Write-Host "[+] Results exported to: $ExportPath" -ForegroundColor Green
} else {
    Write-Host "`n[+] CLEAN: No active PHP processes, binaries, or IIS handlers detected on $HostName." -ForegroundColor Green
}