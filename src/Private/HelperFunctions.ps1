### Auxiliary functions that can be used by other functions across the module.

# Set-ApiKey and Get-ApiKey functions are used to store and retrieve the API key securely.
function Set-ApiKey {
    $apiKey = Read-Host -AsSecureString "Enter the API key"

    try {
        # Check if the PowerShell SecretManagement module is available
        if (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement) {
            # Store the API key in the SecretManagement vault
            Set-Secret -Name $secretName -Secret $apiKey
        } else {
            # Convert the secure string to plain text
            $plainTextApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey))
            # Store the API key as an environment variable
            [System.Environment]::SetEnvironmentVariable($secretName, $plainTextApiKey, [System.EnvironmentVariableTarget]::User)
        }
    }
    catch {
        Write-Error "Failed to store API key: $_"
    }
}

function Get-ApiKey {

    try {
        # Check if the PowerShell SecretManagement module is available
        if (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement) {
            # Check if the API key is stored in the PowerShell SecretManagement vault
            $secureApiKey = Get-Secret -Name $secretName -ErrorAction SilentlyContinue
            
            if ($secureApiKey) {
                # Convert the secure string to plain text
                $plainTextApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureApiKey))
            } else {
                # If not found in the vault, check the environment variable
                $plainTextApiKey = [System.Environment]::GetEnvironmentVariable($secretName, [System.EnvironmentVariableTarget]::User)
            }
        } else {
            # If SecretManagement module is not available, check the environment variable
            $plainTextApiKey = [System.Environment]::GetEnvironmentVariable($secretName, [System.EnvironmentVariableTarget]::User)
        }

        if (-not $plainTextApiKey) {
            return $null
        }

        return $plainTextApiKey
    }
    catch {
        Write-Error "Failed to retrieve API key: $_"
        return $null
    }
}
