#Requires -Modules TcXaeMgmt

<#
.SYNOPSIS
    Discovers the single TwinCAT 3 target on the network, establishes an ADS
    route to it, and deploys the TwinCAT project via the Automation Interface.

.DESCRIPTION
    1. Uses Get-AdsRoute -All to broadcast-search the network for TwinCAT targets.
    2. Validates exactly one remote target is reachable.
    3. Adds a permanent ADS route to that target via Add-AdsRoute.
    4. Retrieves the target's AMS Net ID via Get-AmsNetId.
    5. Launches TcAI_Project, which opens the TwinCAT project in TcXaeShell,
       assigns the discovered AMS Net ID as the target, activates the
       configuration, and restarts TwinCAT on the target.

.NOTES
    Requires the TcXaeMgmt module:
        Install-Module -Name TcXaeMgmt

    The target system must have TwinCAT 3 running and be reachable on the
    local network subnet before running this script.
#>

Import-Module TcXaeMgmt

# ---------------------------------------------------------------------------
# Step 1 – Broadcast search: discover all TwinCAT 3 targets on the network
#
# Get-AdsRoute -All queries the local ADS router for all discovered targets,
# performing a broadcast search across the subnet to find available devices.
# ---------------------------------------------------------------------------
Write-Host "Step 1: Scanning network for TwinCAT 3 targets..."

$allRoutes = Get-AdsRoute -All

if (-not $allRoutes) {
    Write-Error "No TwinCAT 3 targets found. Verify the target is powered on and reachable."
    exit 1
}

# Wrap in array to ensure Count works correctly for a single result
$allRoutes = @($allRoutes)

Write-Host "Found $($allRoutes.Count) target(s):"
$allRoutes | Format-Table -AutoSize

if ($allRoutes.Count -gt 1) {
    Write-Warning "More than one target found. Expected exactly one. Using first: '$($allRoutes[0].Name)'"
}

$target = $allRoutes[0]

Write-Host "Selected target: '$($target.Name)'"

# ---------------------------------------------------------------------------
# Step 2 – Add ADS route to the discovered target
#
# Add-AdsRoute establishes a bidirectional route. When the target's address
# is supplied by name, it performs a broadcast search to resolve IP/NetId.
# -PassThru returns the created route object so we can inspect it.
# Credentials are required for the target Windows/TwinCAT user account.
# ---------------------------------------------------------------------------
Write-Host "`nStep 2: Adding ADS route to '$($target.Name)'..."

$credential = Get-Credential -Message "Enter credentials for TwinCAT target '$($target.Name)'"

$route = Add-AdsRoute `
    -Address $target.Name `
    -Credential $credential `
    -PassThru

if (-not $route) {
    Write-Error "Failed to add ADS route to '$($target.Name)'."
    exit 1
}

Write-Host "ADS route established successfully:"
$route | Format-List

# ---------------------------------------------------------------------------
# Step 3 – Retrieve the AMS Net ID of the target
#
# Get-AmsNetId returns the AMS Network Identifier of the specified target,
# which is required for all subsequent ADS communication with that device.
# ---------------------------------------------------------------------------
Write-Host "Step 3: Retrieving AMS Net ID for '$($target.Name)'..."

$amsNetId = Get-AmsNetId -Target $target.Name

if (-not $amsNetId) {
    Write-Error "Could not retrieve AMS Net ID for '$($target.Name)'."
    exit 1
}

Write-Host ""
Write-Host "=== Discovery Complete ==="
Write-Host "  Target Name : $($target.Name)"
Write-Host "  AMS Net ID  : $amsNetId"

# ---------------------------------------------------------------------------
# Step 4 – Launch the TwinCAT Automation Interface project
#
# Passes the discovered AMS Net ID to TcAI_Project, which:
#   - Opens the TwinCAT project from TwinCAT_ProjectTemp in TcXaeShell
#   - Assigns the AMS Net ID as the target system
#   - Activates the configuration
#   - Restarts TwinCAT on the target
# ---------------------------------------------------------------------------
Write-Host "`nStep 4: Launching TwinCAT Automation Interface..."

$tcaiProjectPath = Join-Path $PSScriptRoot "TcAI_Demo\TcAI_Project\TcAI_Project"

dotnet run --project $tcaiProjectPath -- $amsNetId.ToString()

if ($LASTEXITCODE -ne 0) {
    Write-Error "TcAI_Project exited with code $LASTEXITCODE. Deployment may be incomplete."
    exit $LASTEXITCODE
}

Write-Host "`n=== Deployment Pipeline Complete ==="
