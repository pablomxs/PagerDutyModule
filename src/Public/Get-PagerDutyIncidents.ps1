function Get-PagerDutyIncidents {
    [CmdletBinding(DefaultParameterSetName = 'BySearch')]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = 'ByIncidentId')]
        [Parameter(Mandatory = $false, ParameterSetName = 'ByIncidentIdWithCustomFields')]
        [string]$IncidentId, 
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearch')]
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearchCustomFields')]
        [int]$SinceDaysAgo,
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearch')]
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearchCustomFields')]
        [int]$UntilDaysAgo,
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearch')]
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearchCustomFields')]
        [ValidateSet("triggered", "acknowledged", "resolved")]
        [string[]]$Status,
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearch')]
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearchCustomFields')]
        [string[]]$TeamIds,
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearchCustomFields')]
        [ValidateSet("True", "False")]
        [string]$Categorized,
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearchCustomFields')]
        [ValidateSet("True", "False")]
        [string]$FalsePositive,
        [Parameter(Mandatory = $false, ParameterSetName = 'BySearch')]
        [Parameter(Mandatory = $false,  ParameterSetName = 'ByIncidentIdWithCustomFields')]
        [switch]$IncludeCustomFields
    )

    dynamicparam {
        # Retrieving team members for input parameter dynamically
        $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $attributes = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        $attribute1 = New-Object System.Management.Automation.ParameterAttribute
        $attribute1.Mandatory = $false
        $attribute1.ParameterSetName = 'BySearch'
        $attributes.Add($attribute1)

        $attribute2 = New-Object System.Management.Automation.ParameterAttribute
        $attribute2.Mandatory = $false
        $attribute2.ParameterSetName = 'BySearchCustomFields'
        $attributes.Add($attribute2)

        try {
            $validateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute((Get-PagerDutyTeamMembers -TeamId $myTeamId | Select-Object -ExpandProperty Summary))
            $attributes.Add($validateSetAttribute)
        }
        catch {
            Write-Error "Failed to retrieve team members: $_"
            return
        }

        $runtimeParam = New-Object System.Management.Automation.RuntimeDefinedParameter('AssignedUsers', [string[]], $attributes)
        $paramDictionary.Add('AssignedUsers', $runtimeParam)
        return $paramDictionary
    }

    begin {
        # Verify if the API key is set
        if (-not $global:apiToken) {
            Write-Error "API key not found. Please set the API key using Set-ApiKey function."
            return
        }

        # Initializing variables
        $body = @{
            limit = 1000
            starting_after = $null
            filters = @{
                # Filters to be added at runtime
            }
        }
        $headers["Content-Type"] = "application/json"

        $allIncidents = @()
    }

    process {
        # If IncidentId is provided, retrieve only the specified incident
        if ($IncidentId) {
            $uri = "https://api.pagerduty.com/analytics/raw/incidents/$IncidentId"
            try {
                $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
                $allIncidents += $response.data
            } catch {
                Write-Error "Failed to retrieve incident $($IncidentId): $_"
            }
        } else { # If IncidentId is not provided, retrieve incidents based on the other parameters
            # Gathering details from provided parameters
            if ($SinceDaysAgo) { $body.filters["created_at_start"] = (Get-Date).AddDays(-$SinceDaysAgo).ToString("yyyy-MM-ddTHH:mm:ssZ") }
            if ($UntilDaysAgo) { 
                $body.filters["created_at_end"] = (Get-Date).AddDays(-$UntilDaysAgo).ToString("yyyy-MM-ddTHH:mm:ssZ")
            } else {
                $body.filters["created_at_end"] = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
            
            do {
                # Adding team filter to the API call if TeamIds are provided
                if ($TeamIds) {
                    $body.filters["team_ids"] = $TeamIds
                }

                # Formatting the body as JSON
                $bodyJson = $body | ConvertTo-Json
        
                try {
                    # Making the API call to retrieve incidents from inicdent analytics endpoint
                    $response = Invoke-RestMethod -Uri "https://api.pagerduty.com/analytics/raw/incidents" -Headers $headers -Method Post -Body $bodyJson
                    $allIncidents += $response.data
                    # Setting the cursor to fetch the next set of incidents
                    $body["starting_after"] = $response.last
                } catch {
                    Write-Error "Failed to retrieve incidents: $_"
                    break
                }
            } while ($response.more) # Continue fetching incidents until there are no more to fetch

            ### Filtering output if status or assigned users parameters are provided

            # If both Status and AssignedUsers parameters are provided, filter incidents based on both
            if ($PSBoundParameters.ContainsKey("Status") -and $PSBoundParameters.ContainsKey("AssignedUsers")) {
                $allIncidents = $allIncidents | Where-Object {
                    $PSBoundParameters["Status"] -contains $_.status -and
                    ($_.assigned_user_names | ForEach-Object { $PSBoundParameters["AssignedUsers"] -contains $_ }) -contains $true
                }
            # If only Status or AssignedUsers parameter is provided, filter incidents based on it
            } elseif ($PSBoundParameters.ContainsKey("Status")) {
                $allIncidents = $allIncidents | Where-Object { $PSBoundParameters["Status"] -contains $_.status }
            } elseif ($PSBoundParameters.ContainsKey("AssignedUsers")) {
                $allIncidents = $allIncidents | Where-Object {
                    ($_.assigned_user_names | ForEach-Object { $PSBoundParameters["AssignedUsers"] -contains $_ }) -contains $true
                }
            }
        }
    }
    end {
        # If custom attributes filters or flag are provided, custom fields for each incident must be retrieved
        if ($IncludeCustomFields -or $PSBoundParameters.ContainsKey("Categorized") -or $PSBoundParameters.ContainsKey("FalsePositive")) {
            $filteredIncidents = @()
            $incCount = 0
            $incTotal = $allIncidents.Count
            foreach ($incident in $allIncidents) {
                $customFieldsUri = "https://api.pagerduty.com/incidents/$($incident.id)/custom_fields/values"
                try {
                    # Making the API call to retrieve custom fields for the incident
                    $customFieldsResponse = Invoke-RestMethod -Uri $customFieldsUri -Headers $headers -Method Get
                    
                    # Displaying and updating progress bar on each iteration
                    $incCount ++
                    $percentComplete = ($incCount / $incTotal) * 100
                    Write-Progress -Activity "Retrieving custom fields from PagerDuty incidents..." -Status "$incCount of $incTotal incidents processed" -PercentComplete $percentComplete

                    # Adding custom fields properties to incident object
                    $customFields = $customFieldsResponse.custom_fields
                    foreach ($customField in $customFields) {
                        $incident | Add-Member -MemberType NoteProperty -Name "custom_field_$($customField.name)" -Value $customField.value -Force
                    }

                    ### Filtering incidents based on provided custom attributes

                    $addIncident = $true
                    # If Categorized field does not equal the provided value, exclude the incident
                    if ($PSBoundParameters.ContainsKey("Categorized")) {
                        $categorizedField = $customFields | Where-Object { $_.name -eq "categorized" }
                        if ($categorizedField -and $categorizedField.value -ne [bool]::Parse($Categorized)) {
                            $addIncident = $false
                        }
                    }
                    #If FalsePositive field does not equal the provided value, exclude the incident
                    if ($PSBoundParameters.ContainsKey("FalsePositive")) {
                        $falsePositiveField = $customFields | Where-Object { $_.name -eq "false_positive" }
                        if ($falsePositiveField -and $falsePositiveField.value -ne [bool]::Parse($FalsePositive)) {
                            $addIncident = $false
                        }
                    }
                    # Adding incident to output if it meets the criteria
                    if ($addIncident) {
                        $filteredIncidents += $incident
                    }

                } catch {
                    Write-Error "Failed to retrieve custom fields for incident $($incident.id): $_"
                }
            }
            # Outputting filtered incidents if custom attributes are provided
            $filteredIncidents | ForEach-Object { Write-Output $_ }
        } else {
            # Outputting all incidents if no custom attributes are provided
            $allIncidents | ForEach-Object { Write-Output $_ }
        }
    }
}
