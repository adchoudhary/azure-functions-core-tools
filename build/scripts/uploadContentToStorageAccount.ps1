param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $StorageAccountName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $StorageAccountKey,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $SourcePath
)

$CONTAINER_NAME = "builds"
$FUNC_RUNTIME_VERSION = '3'

if (-not (Test-Path $SourcePath))
{
    throw "SourcePath '$SourcePath' does not exist."
}

$filesToUploaded = @(Get-ChildItem -Path "$SourcePath/*.zip" | ForEach-Object {$_.FullName} )
if ($filesToUploaded.Count -eq 0)
{
    throw "'$SourcePath' does not contain any zip files to upload."
}

if (-not (Get-command New-AzStorageContext -ea SilentlyContinue))
{
    # Install Az.Storage if needed.
    Install-Module Az.Storage -Force -Verbose -Scope CurrentUser
}

$context = $null
try
{
    $context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -ErrorAction Stop
}
catch
{
    "Failed to authenticate with Azure. Please verify the StorageAccountName and StorageAccountKey. Exception information: $_"
}

# Validate and read manifest file
$manifestFilePath = Join-Path $SourcePath "integrationTestBuildManifest.json"

if(-not (Test-Path $manifestFilePath))
{
    throw "File '$manifestFilePath' does not exist."
}

$manifest = $null
try
{
    $manifest = Get-Content $manifestFilePath -Raw | ConvertFrom-Json -ErrorAction Stop
    $filesToUploaded += $manifestFilePath
}
catch
{
    throw "Failed to parse '$manifestFilePath'. Please make sure the file content is a valid JSON."
}

# Create a version.txt file from the integrationTestBuildManifest.json and add it to the list of files to upload
$versionFilePath = Join-Path $SourcePath "version.txt"
$manifest.CoreToolsVersion | Set-Content -Path $versionFilePath
$filesToUploaded += $versionFilePath

# These are the destination paths in the storage account
# "https://<storageAccountName>.blob.core.windows.net/builds/$FUNC_RUNTIME_VERSION/latest/Azure.Functions.Cli.$os-$arch.zi"
# "https://<storageAccountName>.blob.core.windows.net/builds/$FUNC_RUNTIME_VERSION/$version/Azure.Functions.Cli.$os-$arch.zip"
$latestDestinationPath = Join-Path $FUNC_RUNTIME_VERSION "latest"
$versionDestinationPath = Join-Path $FUNC_RUNTIME_VERSION $manifest.CoreToolsVersion

foreach ($path in @($latestDestinationPath, $versionDestinationPath))
{
    foreach ($file in $filesToUploaded)
    {
        $fileName = Split-Path $file -Leaf
        $destinationPath = Join-Path $path $fileName

        try
        {
            Set-AzStorageBlobContent -File $file `
                                     -Container $CONTAINER_NAME `
                                     -Blob $destinationPath `
                                     -Context $context `
                                     -StandardBlobTier Hot `
                                     -ErrorAction Stop `
                                     -Force
        }
        catch
        {
            throw "Failed to upload file '$file' to storage account. Exception information: $_"
        }
    }
}