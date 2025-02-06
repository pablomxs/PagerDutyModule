# Retrieve the API key and set it as a global variable
$global:apiToken = Get-ApiKey
if (-not $global:apiToken) {
    Write-Host "API key not found. Please enter the API key."
    Set-ApiKey
    $global:apiToken = Get-ApiKey
    if (-not $global:apiToken) {
        Write-Error "API key not found. Please set the API key using Set-ApiKey function."
        return
    }
}