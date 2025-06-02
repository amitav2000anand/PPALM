param (
    [string]$EnvironmentId,
    [string]$ServiceAccountObjectId
)

# Install required modules if not already present
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force -AllowClobber -Scope CurrentUser
Install-Module -Name Microsoft.PowerApps.PowerShell -Force -AllowClobber -Scope CurrentUser

# Authenticate using service principal credentials from environment variables
$clientId = $env:CLIENT_ID
$clientSecret = $env:CLIENT_SECRET
$tenantId = $env:TENANT_ID

$secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($clientId, $secureSecret)

Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId

# Get all flows in the environment
$flows = Get-AdminFlow -EnvironmentName $EnvironmentId

foreach ($flow in $flows) {
    Write-Host "Assigning owner for flow: $($flow.DisplayName)"
    Set-AdminFlowOwnerRole -EnvironmentName $EnvironmentId `
                           -FlowName $flow.FlowName `
                           -PrincipalObjectId $ServiceAccountObjectId `
                           -RoleName "Owner"
}
