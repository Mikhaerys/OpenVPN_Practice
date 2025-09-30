# OpenVPN Access Server Docker Setup Script for Windows PowerShell
# This script initializes and starts the OpenVPN Access Server

param(
    [switch]$Force,
    [switch]$SkipValidation
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script and project directories
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

# Function to write colored output
function Write-ColorMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Red", "Green", "Yellow", "Blue", "White")]
        [string]$Color = "White"
    )
    
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if Docker is running
function Test-Docker {
    Write-ColorMessage "Checking Docker installation..." -Color Blue
    
    try {
        $null = Get-Command docker -ErrorAction Stop
        $null = docker info 2>$null
        Write-ColorMessage "Docker is installed and running." -Color Green
        return $true
    }
    catch {
        Write-ColorMessage "Docker is not installed or not running. Please install and start Docker first." -Color Red
        return $false
    }
}

# Function to check if Docker Compose is available
function Test-DockerCompose {
    Write-ColorMessage "Checking Docker Compose installation..." -Color Blue
    
    try {
        # Try docker-compose first
        $null = Get-Command docker-compose -ErrorAction SilentlyContinue
        if ($?) {
            Write-ColorMessage "Docker Compose is available." -Color Green
            return "docker-compose"
        }
        
        # Try docker compose
        $null = docker compose version 2>$null
        if ($?) {
            Write-ColorMessage "Docker Compose (plugin) is available." -Color Green
            return "docker compose"
        }
        
        throw "Docker Compose not found"
    }
    catch {
        Write-ColorMessage "Docker Compose is not installed. Please install Docker Compose first." -Color Red
        return $null
    }
}

# Function to create necessary directories
function New-ProjectDirectories {
    Write-ColorMessage "Creating necessary directories..." -Color Blue
    
    $directories = @(
        "$ProjectDir\config",
        "$ProjectDir\data",
        "$ProjectDir\data\openvpn-as",
        "$ProjectDir\logs"
    )
    
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-ColorMessage "Directories created successfully." -Color Green
}

# Function to setup environment file
function Set-EnvironmentFile {
    Write-ColorMessage "Setting up environment file..." -Color Blue
    
    $envFile = "$ProjectDir\.env"
    $envExampleFile = "$ProjectDir\.env.example"
    
    if (!(Test-Path $envFile)) {
        if (Test-Path $envExampleFile) {
            Copy-Item $envExampleFile $envFile
            Write-ColorMessage "Created .env file from .env.example" -Color Yellow
            Write-ColorMessage "Please edit .env file to customize your settings!" -Color Yellow
        }
        else {
            Write-ColorMessage ".env.example file not found!" -Color Red
            exit 1
        }
    }
    else {
        Write-ColorMessage ".env file already exists." -Color Green
    }
}

# Function to load environment variables
function Get-EnvironmentVariables {
    $envFile = "$ProjectDir\.env"
    $envVars = @{}
    
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^([^#=]+)=(.*)$') {
                $envVars[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }
    
    return $envVars
}

# Function to validate environment
function Test-Environment {
    if ($SkipValidation) {
        Write-ColorMessage "Skipping environment validation..." -Color Yellow
        return
    }
    
    Write-ColorMessage "Validating environment configuration..." -Color Blue
    
    $envVars = Get-EnvironmentVariables
    
    # Check admin password
    if ($envVars["ADMIN_PASSWORD"] -eq "changeme" -or $envVars["ADMIN_PASSWORD"] -eq "changeme123!") {
        Write-ColorMessage "WARNING: You are using the default admin password!" -Color Red
        Write-ColorMessage "Please change ADMIN_PASSWORD in the .env file for security." -Color Yellow
        
        if (!$Force) {
            $response = Read-Host "Do you want to continue anyway? (y/N)"
            if ($response -notmatch '^[Yy]$') {
                exit 1
            }
        }
    }
    
    # Check hostname
    if ($envVars["SERVER_HOSTNAME"] -eq "localhost") {
        Write-ColorMessage "WARNING: SERVER_HOSTNAME is set to localhost." -Color Yellow
        Write-ColorMessage "This will only work for local testing. Set your public IP/domain for remote access." -Color Yellow
    }
    
    Write-ColorMessage "Environment validation completed." -Color Green
}

# Function to pull Docker image
function Get-DockerImage {
    Write-ColorMessage "Pulling OpenVPN Access Server Docker image..." -Color Blue
    
    $envVars = Get-EnvironmentVariables
    $version = if ($envVars["OPENVPN_VERSION"]) { $envVars["OPENVPN_VERSION"] } else { "latest" }
    
    docker pull "openvpn/openvpn-as:$version"
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorMessage "Image pulled successfully." -Color Green
    }
    else {
        Write-ColorMessage "Failed to pull Docker image." -Color Red
        exit 1
    }
}

# Function to start container
function Start-Container {
    param([string]$ComposeCommand)
    
    Write-ColorMessage "Starting OpenVPN Access Server container..." -Color Blue
    
    Push-Location $ProjectDir
    
    try {
        if ($ComposeCommand -eq "docker-compose") {
            docker-compose up -d
        }
        else {
            docker compose up -d
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorMessage "Container started successfully." -Color Green
        }
        else {
            Write-ColorMessage "Failed to start container." -Color Red
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

# Function to wait for container readiness
function Wait-Container {
    Write-ColorMessage "Waiting for OpenVPN Access Server to be ready..." -Color Blue
    
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $result = docker exec openvpn-access-server test -f /opt/openvpn-as/init/as-init 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorMessage "OpenVPN Access Server is ready!" -Color Green
                return
            }
        }
        catch {
            # Continue waiting
        }
        
        $attempt++
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 5
    }
    
    Write-ColorMessage ""
    Write-ColorMessage "Timeout waiting for OpenVPN Access Server to be ready." -Color Red
    Write-ColorMessage "Check container logs: docker logs openvpn-access-server" -Color Yellow
    exit 1
}

# Function to show connection information
function Show-ConnectionInfo {
    Write-ColorMessage "=== OpenVPN Access Server Setup Complete ===" -Color Green
    
    $envVars = Get-EnvironmentVariables
    
    Write-Host ""
    Write-ColorMessage "Connection Information:" -Color Blue
    Write-ColorMessage "Admin Web UI: https://$($envVars["SERVER_HOSTNAME"]):$($envVars["ADMIN_UI_PORT"])/admin" -Color Yellow
    Write-ColorMessage "Client Web UI: https://$($envVars["SERVER_HOSTNAME"]):$($envVars["CLIENT_UI_PORT"])/" -Color Yellow
    Write-ColorMessage "Username: $($envVars["ADMIN_USERNAME"])" -Color Yellow
    Write-ColorMessage "Password: $($envVars["ADMIN_PASSWORD"])" -Color Yellow
    
    Write-Host ""
    Write-ColorMessage "OpenVPN Connection:" -Color Blue
    Write-ColorMessage "Server: $($envVars["SERVER_HOSTNAME"])" -Color Yellow
    Write-ColorMessage "Port: $($envVars["OPENVPN_PORT"])" -Color Yellow
    Write-ColorMessage "Protocol: $($envVars["VPN_PROTOCOL"])" -Color Yellow
    
    Write-Host ""
    Write-ColorMessage "Next Steps:" -Color Green
    Write-ColorMessage "1. Access the Admin Web UI to configure your VPN server" -Color Yellow
    Write-ColorMessage "2. Create user accounts in the Admin interface" -Color Yellow
    Write-ColorMessage "3. Download client configuration files" -Color Yellow
    Write-ColorMessage "4. Import configuration into OpenVPN clients" -Color Yellow
    
    Write-Host ""
    Write-ColorMessage "Useful Commands:" -Color Blue
    Write-ColorMessage "View logs: docker logs openvpn-access-server" -Color Yellow
    Write-ColorMessage "Stop server: docker-compose down" -Color Yellow
    Write-ColorMessage "Restart server: docker-compose restart" -Color Yellow
    Write-ColorMessage "Update server: docker-compose pull && docker-compose up -d" -Color Yellow
}

# Main function
function Main {
    Write-ColorMessage "=== OpenVPN Access Server Docker Setup ===" -Color Green
    
    # Check prerequisites
    if (!(Test-Docker)) { exit 1 }
    
    $composeCommand = Test-DockerCompose
    if (!$composeCommand) { exit 1 }
    
    # Setup
    New-ProjectDirectories
    Set-EnvironmentFile
    Test-Environment
    Get-DockerImage
    Start-Container -ComposeCommand $composeCommand
    Wait-Container
    Show-ConnectionInfo
    
    Write-ColorMessage "Setup completed successfully!" -Color Green
}

# Run main function
try {
    Main
}
catch {
    Write-ColorMessage "Error: $($_.Exception.Message)" -Color Red
    exit 1
}