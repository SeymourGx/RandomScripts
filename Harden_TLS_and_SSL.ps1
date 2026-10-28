#Requires -RunAsAdministrator

$schannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

# Define protocols to disable
$disableProtocols = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1")

# Define protocols to enable
$enableProtocols = @("TLS 1.2")

# Check OS version for TLS 1.3 support (Requires Windows Server 2022+ / Build 20348+)
$osInfo = Get-CimInstance Win32_OperatingSystem
$buildNumber = [int]$osInfo.BuildNumber

if ($buildNumber -ge 20348) {
    $enableProtocols += "TLS 1.3"
    Write-Host "Windows Server 2022+ detected. Adding TLS 1.3 to enabled protocols." -ForegroundColor Green
} else {
    Write-Host "OS does not natively support TLS 1.3 via Schannel. Skipping TLS 1.3." -ForegroundColor Yellow
}

# Function to configure the Client and Server subkeys for a protocol
function Set-ProtocolState {
    param (
        [string]$Protocol,
        [bool]$Enable
    )

    $targetPath = "$schannelPath\$Protocol"
    $clientPath = "$targetPath\Client"
    $serverPath = "$targetPath\Server"

    # Create keys if they do not exist
    if (-not (Test-Path $targetPath)) { New-Item -Path $targetPath -Force | Out-Null }
    if (-not (Test-Path $clientPath)) { New-Item -Path $clientPath -Force | Out-Null }
    if (-not (Test-Path $serverPath)) { New-Item -Path $serverPath -Force | Out-Null }

    if ($Enable) {
        $enabledValue = 1
        $disabledByDefaultValue = 0
        Write-Host "Enabling $Protocol..."
    } else {
        $enabledValue = 0
        $disabledByDefaultValue = 1
        Write-Host "Disabling $Protocol..."
    }

    # Apply settings to the Server subkey
    Set-ItemProperty -Path $serverPath -Name "Enabled" -Value $enabledValue -Type DWord -Force
    Set-ItemProperty -Path $serverPath -Name "DisabledByDefault" -Value $disabledByDefaultValue -Type DWord -Force

    # Apply settings to the Client subkey
    Set-ItemProperty -Path $clientPath -Name "Enabled" -Value $enabledValue -Type DWord -Force
    Set-ItemProperty -Path $clientPath -Name "DisabledByDefault" -Value $disabledByDefaultValue -Type DWord -Force
}

# Process the disabled protocols
foreach ($proto in $disableProtocols) {
    Set-ProtocolState -Protocol $proto -Enable $false
}

# Process the enabled protocols
foreach ($proto in $enableProtocols) {
    Set-ProtocolState -Protocol $proto -Enable $true
}

Write-Host "Schannel registry updates complete. You must restart the server for these changes to take effect." -ForegroundColor Cyan