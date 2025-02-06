# FILE: /PagerDutyModule/PagerDutyModule/PagerDutyModule.psm1

# This file is the main module file for the PagerDutyModule.
# It imports the public and private functions and defines the module's functionality.

# Import public functions
Get-ChildItem -Path "$PSScriptRoot\src\Public" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Import all private functions
Get-ChildItem -Path "$PSScriptRoot\src\Private" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Exported functions
Export-ModuleMember -Function Get-PagerDutyIncidents
Export-ModuleMember -Function Get-PagerDutyTeamMembers

# Additional module functionality can be defined here.