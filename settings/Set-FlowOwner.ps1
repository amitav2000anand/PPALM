name: release-solution-to-uat-prod

env:
  DEV_ENVIRONMENT_URL: ${{ secrets.ENVIRONMENT_URL }}
  BUILD_ENVIRONMENT_URL: ${{ secrets.BUILD_ENVIRONMENT_URL }}
  PROD_ENVIRONMENT_URL: ${{ secrets.PRODUCTION_ENVIRONMENT_URL }}
  CLIENT_ID: ${{ secrets.POWERPLATFORM_CLIENT_ID }}
  TENANT_ID: ${{ secrets.POWERPLATFORM_TENANT_ID }}
  SECRET: ${{ secrets.POWERPLATFORMSPN }}
  
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
Write-Host "Fetching flows from environment: $EnvironmentId"
$flows = Get-AdminFlow -EnvironmentName $EnvironmentId
Write-Host "Found $($flows.Count) flows. Starting reassignment..."
foreach ($flow in $flows) {
    Write-Host "Assigning owner for flow: $($flow.DisplayName)"
    Set-AdminFlowOwnerRole -EnvironmentName $EnvironmentId `
                           -FlowName $flow.FlowName `
                           -PrincipalObjectId $ServiceAccountObjectId `
                           -RoleName "Owner"
}
