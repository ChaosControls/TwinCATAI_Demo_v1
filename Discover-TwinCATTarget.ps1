#Requires -Modules TcXaeMgmt

<#
.SYNOPSIS
    Discovers a TwinCAT 3 target (broadcast or manual IP), establishes an ADS
    route to it, and deploys the TwinCAT project via the Automation Interface.

.DESCRIPTION
    0. Prompts the user to choose broadcast search or manual IP entry.
    1. Discovers / validates the target.
    2. Adds a permanent ADS route via Add-AdsRoute.
    3. Reads the target AMS Net ID.
    4. Launches TCAI, which opens the TwinCAT project in TcXaeShell,
       assigns the AMS Net ID, activates the configuration, and restarts
       TwinCAT on the target.

.NOTES
    Requires the TcXaeMgmt module:
        Install-Module -Name TcXaeMgmt

    The target system must have TwinCAT 3 running and be reachable on the
    network before running this script.
#>

Import-Module TcXaeMgmt

# Suppress progress stream output globally so TcXaeMgmt progress messages
# do not bleed into credential or input prompts in the terminal.
$ProgressPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Discovery method selection
# ---------------------------------------------------------------------------
Write-Host "How would you like to discover the TwinCAT target?"
Write-Host "  [1] Broadcast search  — automatically scan the network"
Write-Host "  [2] Manual IP entry   — connect directly to a known IP address"
Write-Host ""

do {
    $choice = Read-Host "Enter choice (1 or 2)"
} while ($choice -ne '1' -and $choice -ne '2')

# These are populated by whichever discovery path runs and used in Steps 2-4.
$targetName = $null
$targetNetId = $null
$targetIp   = $null

# ---------------------------------------------------------------------------
# Step 1A – Broadcast search
# ---------------------------------------------------------------------------
if ($choice -eq '1') {
    Write-Host "`nStep 1: Scanning network for TwinCAT 3 targets..."

    $allRoutes = @(Get-AdsRoute -All)

    if ($allRoutes.Count -eq 0) {
        Write-Error "No TwinCAT 3 targets found. Verify the target is powered on and reachable."
        exit 1
    }

    # Filter out the local machine — you cannot add an ADS route to yourself.
    $remoteRoutes = @($allRoutes | Where-Object { $_.Name -ne $env:COMPUTERNAME })

    if ($remoteRoutes.Count -eq 0) {
        Write-Error "No remote TwinCAT targets found (only the local machine was discovered)."
        exit 1
    }

    Write-Host "Found $($remoteRoutes.Count) remote target(s):"
    $remoteRoutes | Format-Table -AutoSize

    if ($remoteRoutes.Count -gt 1) {
        Write-Warning "More than one remote target found. Using first: '$($remoteRoutes[0].Name)'"
    }

    $targetName  = $remoteRoutes[0].Name
    $targetNetId = $remoteRoutes[0].NetId
    $targetIp    = $remoteRoutes[0].Address

    Write-Host "Selected target: '$targetName'"

# ---------------------------------------------------------------------------
# Step 1B – Manual IP entry
# ---------------------------------------------------------------------------
} else {
    Write-Host ""
    $targetIp = Read-Host "Enter the target IP address  (e.g. 192.168.1.100)"

    if ([string]::IsNullOrWhiteSpace($targetIp)) {
        Write-Error "No IP address entered."
        exit 1
    }

    Write-Host "`nStep 1: Using manually entered IP: $targetIp"
}

# ---------------------------------------------------------------------------
# Step 2 – Add ADS route to the target
#
# Broadcast path : NetId + IP are already known, pass both to skip any
#                  additional broadcast search inside Add-AdsRoute.
# Manual IP path : only IP is known; Add-AdsRoute contacts that address
#                  directly to retrieve the NetId and establish the route.
# ---------------------------------------------------------------------------
$displayName = if ($targetName) { $targetName } else { $targetIp }
Write-Host "`nStep 2: Adding ADS route to '$displayName'..."

$credential = Get-Credential -Message "Enter credentials for TwinCAT target '$displayName'"

if ($choice -eq '1') {
    $route = Add-AdsRoute `
        -NetId $targetNetId `
        -IPOrHostName $targetIp `
        -Credential $credential `
        -PassThru
} else {
    $route = Add-AdsRoute `
        -IPOrHostName $targetIp `
        -Credential $credential `
        -PassThru
}

if (-not $route) {
    Write-Error "Failed to add ADS route to '$displayName'."
    exit 1
}

Write-Host "ADS route established successfully:"
$route | Format-List

# ---------------------------------------------------------------------------
# Step 3 – Determine the AMS Net ID
#
# Broadcast path : NetId was already resolved by Get-AdsRoute -All.
# Manual IP path : NetId is taken from the route object returned by
#                  Add-AdsRoute, which retrieved it from the target.
# ---------------------------------------------------------------------------
$amsNetId   = if ($choice -eq '1') { $targetNetId } else { $route.NetId }
$targetName = if ($choice -eq '1') { $targetName  } else { $route.Name  }

if (-not $amsNetId) {
    Write-Error "Could not determine AMS Net ID for '$displayName'."
    exit 1
}

Write-Host ""
Write-Host "=== Discovery Complete ==="
Write-Host "  Target Name : $targetName"
Write-Host "  AMS Net ID  : $amsNetId"

# ---------------------------------------------------------------------------
# Step 4 – Launch the TCAI project
#
# Passes the AMS Net ID to TcAI_Project, which:
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
