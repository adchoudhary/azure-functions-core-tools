$buildFolderPath = Join-Path $PSScriptRoot "build"
if (-not (Test-Path $buildFolderPath))
{
    throw "Build folder '$buildFolderPath' does not exist."
}

Set-Location $buildFolderPath

$command = $null
if ($env:INTEGRATIONBUILDNUMBER)
{
    $command = "dotnet run --integrationTests"
}
else
{
    $command = "dotnet run --ci"
}

Invoke-Expression -Command $command
if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }