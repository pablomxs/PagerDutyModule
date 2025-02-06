# PagerDutyModule

## Overview
This PowerShell module provides a set of functions to interact with the PagerDuty API.
## Installation
To install the module, create a folder named PagerDutyModule and clone the repository in there or download the files directly. Place the module folder in one of the following locations:

### For Current User (Non-Admin, Recommended)
Place the module folder in the following folder or check the correct path in `$env:PSModulePath`:
- `$HOME\Documents\WindowsPowerShell\Modules`

### For All Users (Requires Admin)
Place the module folder in:
- `$env:ProgramFiles\PowerShell\Modules`

## Usage
### Importing the Module
To use the module, first import it into your PowerShell session:

```powershell
Import-Module PagerDutyModule
```

### Public Functions
- **Get-PagerDutyIncidents**: This function retrieves incidents from the PagerDuty API. You can filter incidents based on different properties.
- **Get-PagerDutyTeammembers**: This function retrieves members for a specific team from the PagerDuty API.

### Examples
#### Example 1: Retrieve all incidents from the last week including their custom fields
```powershell
Get-PagerDutyIncidents -SinceDaysAgo 7 -IncludeCustomFields
```

#### Example 2: Retrieve uncategorized resolved incidents from the last 3 days assigned to UserA and UserB
```powershell
Get-PagerDutyIncidents -SinceDaysAgo 3 -AssignedUsers "UserA","UserB" -Categorized False -Status resolved
```

#### Example 3: Retrieve all triggered and acknowledged incidents from the previous month that are tagged as False Positive
```powershell
Get-PagerDutyIncidents -SinceDaysAgo 60 -UntilDaysAgo 30 -Status triggered,acknowledged -FalsePositive True
```