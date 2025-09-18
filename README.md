# Power Platfrom Prerequisites

## Retrieving Environment URLs

The environment URL uniquely identifies your Power Platform environment (Dev, Stage, Prod). It is required to authenticate and interact with the environment using the Power Platform tools and GitHub Actions. Each GitHub Action workflow uses this URL to connect to the correct environment during export/import steps. It helps target deployments accurately and securely.

To obtain environment URL, follow below steps:

1. Sign in to the [Power Platform Admin Center](https://admin.powerplatform.microsoft.com/)
2. In the left navigation pane, select **Environments**.
3. Choose your environment.
4. Copy the URL listed in the **Details** section (e.g., `https://orga7e80c8e.crm.dynamics.com`).  
Use this value in GitHub secrets as `https://<Environment_URL>`.
---

## Creating Connections in Higher Environments

Connections created in Dev don't carry over automatically to Stage/Prod. You must manually recreate them using proper service accounts. Connection IDs are added to the deployment settings file. This allows GitHub Actions to map the connection references during deployment using `import-solution`.

1. Identify connection references in the `AI - IT Self Service - Dev` solution.
2. Use Stage and Production service accounts to recreate these connections.
3. Record the connection IDs to reference them in respective deployment settings files.
---

## Updating Cloud Flow `Run only user`

The "Run only users" setting defines who can trigger the flow. This will update the Run only user to service account when deploying the solution to Stage or Prod.

> This action must be performed for **each cloud flow** within your solution.

1. Navigate to the `AI - IT Self Service - Dev` environment.
2. Navigate to the solution containing the cloud flows.
3. Open the specific cloud flow, without editing.
4. Update the **Run only user** setting to reflect the flow owner's name.
---

## Updating Environment Variables

Environment variables are placeholders used to store values like API keys, connection strings, or URLs. They are included in the solution by default during export. To avoid exporting hardcoded values from Dev that could overwrite settings in Stage/Prod. 

To ensure environment-specific values are updated:

1. In the `AI - IT Self Service - Dev` environment, open the target solution.
2. Navigate to **Environment Variables**.
3. For each environment variable:
   - Open the **Advanced** section.
   - Set **Export value** to `false`.
---

# Github Prerequisites

### Configuring Secrets in GitHub

GitHub Secrets are secure storage for sensitive configuration values used in your workflows, such as service account credentials, environment URLs, and app registration details.
These secrets prevent exposing confidential information directly in the codebase or workflow files. They enable GitHub Actions to authenticate and interact with Power Platform environments.Centralizing secrets ensures easier management and updates without modifying workflows.

To configure secrets:

1. Navigate to your repository **Settings**.
2. Go to **Secrets and variables** → **Actions**.
3. Click **New repository secret**.
4. Add the secret name, value and then save.
---

## Required GitHub Secrets

Ensure the following repository secrets are configured:

- `POWERPLATFORM_ENVIRONMENT_URL`
- `SERVICE_ACCOUNT_USERNAME`
- `SERVICE_ACCOUNT_PASSWORD`
- `APPREGISTRATION_CLIENT_ID`
- `APPREGISTRATION_SECRET`
- `TENANT_ID`
- `GITHUB_TOKEN` (used for GitHub repository access)


## Generating Deployment Settings Files

> ⚠️ **Note:** These actions should only be executed **once**, and **only** if the corresponding settings files are **not already present** in the repository. You should update the settings files **only when new connection references are added** to the solution in the Dev environment.

Deployment settings files are JSON configurations that include metadata and references needed to import a solution into a target environment, such as Stage or Production.

Each environment may have different connection references, environment variables, and solution-specific configurations. The deployment settings file ensures that all connection references are correctly mapped during deployment. 

These files are generated from the managed solution `.zip` file exported from Dev. Once generated, they are passed as input during the `import-solution` step in the workflow. Workflow uses `DeploymentSettings-UAT.json` for Stage deployments and `DeploymentSettings-PROD.json` for Production deployments.

**Commands to generate settings:**
Use the following Power Platform CLI commands to create settings files for each target environment:

```bash
pac solution create-settings --solution-zip <SolutionName>_managed.zip --settings-file settings/<UAT_Settings_File>.json
pac solution create-settings --solution-zip <SolutionName>_managed.zip --settings-file settings/<Prod_Settings_File>.json
```
---

# Power Platform Deployment Workflows
This repository provides GitHub Actions workflows to automate the export, and deployment of Power Platform solutions across Staging, and Production environments.

## Workflows Overview

### 1. `build-branch-for-PR.yml`

This workflow should be triggered first upon any changes in the `AI - IT Self Service - Dev` environment and is designed to:

- Export a managed solution from the development environment.
- Unpack the solution using Power Platform CLI.
- Prepare the solution for submission via pull request by branching and committing changes to the repository.

#### Inputs

```bash
on:
  workflow_dispatch:
    inputs:
      solution_name:
        description: 'name of the solution to worked on from Power Platform'
        required: true
        default: HelpDeskChatbot
```
Enables manual triggering of the workflow via GitHub. Accepts an input parameter solution_name which specifies the Power Platform solution to process.

#### Environment Variables

- `solution_exported_folder`
- `solution_folder`
- `solution_target_folder`
- `solution_settings_folder`

Defines environment-wide folder paths used to export, unpack, and stage the solution. Used to centralizes file locations, making it easier to manage solution artifacts across steps.

### Permissions Setup

```bash
permissions:
  contents: write
```
Grants write access to the repository’s contents to push changes, create branches. Needed for steps like branching and committing unpacked solution code to the repo.

### Job Definition

```bash
jobs:
  checkin-to-repo-from-dev:
    runs-on: windows-latest
    env:
      RUNNER_DEBUG: 1
    environment:
      name: dev
```
Defines a job that runs on a Windows-based GitHub runner.Enables verbose debugging with RUNNER_DEBUG: 1, which Helps trace issues during workflow execution.

Each step in a GitHub Actions workflow typically follows a structured pattern using these key fields:
- `name` : Defines the human-readable label in the workflow logs and helps identify what the step is doing.
- `uses` : Specifies GitHub Action being executed. Refers to an existing action hosted on GitHub (e.g., Power Platform CLI tasks).
- `with` : Passes input parameters or configuration values to the action defined in uses. These are action-specific options like solution name, credentials, or flags.

#### Key Steps

```bash
- name: Install Power Platform Tools
  uses: microsoft/powerplatform-actions/actions-install@v1
```
Installs all necessary Power Platform tools required to interact with environments and solutions.

```bash
- uses: actions/checkout@v3
  with:
    lfs: true
```
Retrieves the repository code into the runner’s workspace.
lfs: true ensures that large files (tracked by Git LFS) are downloaded correctly.

```bash
- name: who-am-i action
  uses: microsoft/powerplatform-actions/who-am-i@v1
  with:
    environment-url: ${{vars.POWERPLATFORM_ENVIRONMENT_URL}}
    app-id: ${{vars.APPREGISTRATION_CLIENT_ID}}
    client-secret: ${{secrets.APPREGISTRATION_SECRET}}
    tenant-id: ${{vars.TENANT_ID}}
```
Authenticate using configured secrets.
Verifies connection credentials to the Power Platform environment.
Confirms access and setup before moving on to solution export.

```bash
- name: export-solution action for managed solution
  uses: microsoft/powerplatform-actions/export-solution@v1
  with:
    environment-url: ${{vars.POWERPLATFORM_ENVIRONMENT_URL}}
    app-id: ${{vars.APPREGISTRATION_CLIENT_ID}}
    client-secret: ${{secrets.APPREGISTRATION_SECRET}}
    tenant-id: ${{vars.TENANT_ID}}
    managed: true
    solution-name: ${{github.event.inputs.solution_name}}
    solution-output-file: ${{env.solution_exported_folder}}${{github.event.inputs.solution_name}}_managed.zip
```
Exports the specified solution from the Dev environment as a managed .zip file. Managed solutions are suitable for staging and production deployments.
Output is saved for unpacking in the next step.

```bash
- name: unpack-solution action for unmanaged solution
  uses: microsoft/powerplatform-actions/unpack-solution@v1
  with:
    solution-file: ${{env.solution_exported_folder}}/${{github.event.inputs.solution_name}}_managed.zip
    solution-folder: ${{env.solution_folder}}/${{github.event.inputs.solution_name}}
    solution-type: 'Managed'
    overwrite-files: true
```
Unpacks the exported managed solution into source folders. Converts .zip contents to raw components.

```bash
- name: branch-solution for managed, prepare it for a PullRequest
  uses: microsoft/powerplatform-actions/branch-solution@v1
  with:
    solution-folder: ${{env.solution_folder}}
    solution-target-folder: ${{env.solution_target_folder}}
    repo-token: ${{ secrets.GITHUB_TOKEN }}
    allow-empty-commit: true
```
Creates or updates branches with the unpacked solution files.
Prepares content for pull request submission. Automates source control of Power Platform solutions. Enables code reviews and CI/CD integration via PRs.

---

### 2. `release-solution-to-uat-prod.yml`

This workflow is triggered upon closure of a pull request to the `master` branch and facilitates deployment to Stage and Production environments.

> **Note:** This workflow should only be triggered **after** `build-branch-for-PR.yml` has been successfully completed to ensure the solution is properly checked-in to the repository.

```bash
on:
  pull_request:
    types:
      - closed
    branches:
      - master
```
This enables workflow to be triggered automatically when a pull request to the master branch is closed.

```bash
env:
  solution_name: HelpDeskChatbot
  solution_shipping_folder: out/ship
  solution_outbound_folder: out/solutions
  solution_source_folder: solutions
  solution_release_folder: out/release
```
Definitions environment-wide folder path to be used for solution checkout, packing and import.

## Stage Deployment

```bash
jobs:
  deploy-to-uat:
    runs-on: windows-latest
    env:
      RUNNER_DEBUG: 1
    environment:
      name: stage
```
Executes the job on a Windows runner (compatible with Power Platform CLI).
Enables detailed logging with RUNNER_DEBUG.

```bash
- name: Install Power Platform Tools
  uses: microsoft/powerplatform-actions/actions-install@v1
```
- name: Indicates this step installs required Power Platform CLI tools.
- uses: Calls a prebuilt GitHub Action that sets up Power Platform tooling.
Installs the Power Platform CLI and all required dependencies.
This action sets up the core tooling used to interact with Power Platform environments, such as packing/unpacking solutions, exporting/importing.

```bash
- uses: actions/checkout@v3
  with:
    lfs: true
```
Retrieves the repository code into the workspace.
lfs: true ensures that large files (tracked by Git LFS) are downloaded correctly.

```bash
- name: who-am-i action
  uses: microsoft/powerplatform-actions/who-am-i@v1
  with:
    environment-url: ${{vars.POWERPLATFORM_ENVIRONMENT_URL}}
    user-name: ${{ secrets.SERVICE_ACCOUNT_USERNAME }}
    password-secret: ${{ secrets.SERVICE_ACCOUNT_PASSWORD }}
```
Authenticates and verifies the identity of the executing user in the Power Platform environment and confirms your workflow has access to the target environment.

```bash
- name: Pack solution from source control into a solution.zip
  uses: microsoft/powerplatform-actions/pack-solution@v1
  with:
    solution-folder: ${{env.solution_source_folder}}/${{env.solution_name}}
    solution-file: ${{env.solution_outbound_folder}}/${{env.solution_name}}_managed.zip
    solution-type: Managed
```
Packs the individual solution components (flows, tables, agents, etc.) from source folders into a deployable .zip file. Creates the managed version of the solution used for deployment.

```bash
- name: Import solution as managed to uat env
  uses: microsoft/powerplatform-actions/import-solution@v1
  with:
    environment-url: ${{vars.POWERPLATFORM_ENVIRONMENT_URL}}
    user-name: ${{ secrets.SERVICE_ACCOUNT_USERNAME }}
    password-secret: ${{ secrets.SERVICE_ACCOUNT_PASSWORD }} 
    solution-file: ${{env.solution_outbound_folder}}/${{env.solution_name}}_managed.zip
    use-deployment-settings-file: true
    deployment-settings-file: settings/DeploymentSettings-UAT.json
    publish-changes: true
    stage-and-upgrade: true
    run-asynchronously: true
    max-async-wait-time: 60
```
Deploys the packed managed solution into the Staging environment. This uses a deployment settings file to map connection references and variables and publishes changes automatically.

```bash
- name: Upload the ready to ship solution to GH artifact store
  uses: actions/upload-artifact@v4
  with:
    name: ${{env.solution_name}}_managed
    path: ${{env.solution_outbound_folder}}/
```
Uploads the packaged managed solution .zip as an artifact in build machine and lets you reuse the artifcats in later stages.

```bash
- name: Upload the settings folder to GH artifact store
  uses: actions/upload-artifact@v4
  with:
    name: ${{env.solution_name}}_managed_settings
    path: settings/DeploymentSettings-PROD.json
```
Uploads the Production deployment settings file used later for environment-specific configuration mapping.

## Production Deployment

```bash
needs: [ deploy-to-uat ]
runs-on: windows-latest
env:
  RUNNER_DEBUG: 1
environment:
  name: prod
```
This ensures that the production deployment job runs only after the Stage deployment completes, using a Windows runner with enhanced logging.

- needs: Specifies a job dependency. This job will only run after deploy-to-uat completes successfully.
- runs-on: Defines the operating system for the runner. windows-latest ensures compatibility with Power Platform tools.
- env: Sets runtime environment variables. RUNNER_DEBUG: 1 enables verbose logging to aid in troubleshooting.
- environment: Tags the deployment to the prod environment, enabling environment-specific controls and approvals.
- Before deploying to the Production environment, the workflow includes a manual approval step using GitHub Environments. This ensures controlled and verified releases.
   - The prod environment must be configured in the repository settings with required reviewers.
   - Deployment to Production will pause until approval is granted by one of the designated reviewers.

## Configuring Manual Approval for Production Deployment
To ensure controlled and verified deployments to the Production environment, this workflow uses **GitHub Environments** with a manual approval step.
### Setup Instructions
1. **Navigate to Repository Settings**
   - Go to your repository on GitHub.
   - Click on **Settings**.
2. **Access Environments**
   - In the left sidebar, scroll down to click on **Environments**.
3. **Create a New Environment**
   - Click **New environment**.
   - Name it `prod`.
   - Click **Configure environment**.
4. **Add Required Reviewers**
   - Under **Deployment protection rules**.
   - Select **Required reviewers**.
   - Choose one or more users or teams who must approve the deployment.
   - Click **Save protection rule**.
5. **Save the Environment Configuration**
   - Click **Save** to finalize the environment setup.

### How It Works
When the workflow reaches the `deploy-to-prod` job, GitHub will:
- Pause the workflow.
- Notify the designated reviewers.
- Resume deployment only after approval is granted.

This ensures that production deployments are **intentional, secure, and reviewed**.

```bash
- name: Install Power Platform Tools
  uses: microsoft/powerplatform-actions/actions-install@v1
```
- name: Identifies the step as installing CLI tools required for Power Platform tasks.
- uses: Invokes the official Microsoft action to install Power Platform CLI components.

```bash
- name: Fetch the ready to ship solution from GH artifact store
  uses: actions/download-artifact@v4
  with:
    name: ${{env.solution_name}}_managed
    path: ${{env.solution_shipping_folder}}/
```
- name: Describes retrieval of the previously uploaded solution file.
- uses: GitHub’s standard action to download artifacts generated in previous jobs.
- with: name: The artifact identifier (HelpDeskChatbot_managed). 
path: Target folder to place the downloaded solution.

```bash
- name: Fetch the settings folder from GH artifact store
  uses: actions/download-artifact@v4
  with:
    name: ${{env.solution_name}}_managed_settings
```
- name: Labels the download step for deployment settings.
- uses: Uses artifact downloader command.
- with:name: Identifier for the PROD deployment settings JSON.

```bash
- name: Import solution as managed to PROD env
  uses: microsoft/powerplatform-actions/import-solution@v1
  with:
    environment-url: ${{vars.POWERPLATFORM_ENVIRONMENT_URL}}
    user-name: ${{ secrets.SERVICE_ACCOUNT_USERNAME }}
    password-secret: ${{ secrets.SERVICE_ACCOUNT_PASSWORD }} 
    solution-file: ${{env.solution_shipping_folder}}/${{env.solution_name}}_managed.zip
    use-deployment-settings-file: true
    deployment-settings-file: DeploymentSettings-PROD.json
    publish-changes: true
    stage-and-upgrade: true
    run-asynchronously: true
    max-async-wait-time: 60
```
- name: Executes deployment of the managed solution to the production environment.
- uses: Calls the Power Platform import CLI action.
- with:
    - environment-url: Target PROD environment URL.
    - user-name & password-secret: Credentials from GitHub secrets.
    - solution-file: Path to the .zip file downloaded earlier.
    - use-deployment-settings-file: Enables use of environment-specific configuration.
    - deployment-settings-file: Path to the PROD settings JSON.
    - publish-changes: Publishes the solution automatically.
    - stage-and-upgrade: Set to false for first-time deployments; use true only when upgrading.
    - run-asynchronously: Executes in background mode to prevent timeouts.
    - max-async-wait-time: Waits up to 60 minutes for async tasks to complete.
---
## References

- [Microsoft Power Platform GitHub Actions](https://github.com/microsoft/powerplatform-actions)
- [ALM with GitHub Actions - Power Platform Documentation](https://learn.microsoft.com/en-us/power-platform/alm/tutorials/github-actions-start)
- [Azure AD App Registration for Power Platform](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/walkthrough-register-app-azure-active-directory)

---
