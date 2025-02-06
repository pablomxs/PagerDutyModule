function Get-PagerDutyTeamMembers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TeamId
    )

    # Verify if the API key is set
    if (-not $global:apiToken) {
        Write-Error "API key not found. Please set the API key using Set-ApiKey function."
        return
    }

    # Making the API call to retrieve team members
    $urlTeamMembers = "https://api.pagerduty.com/teams/$TeamId/members"
    $responseMembers = Invoke-RestMethod -Uri $urlTeamMembers -Headers $headers -Method Get

    # Constructing the response object
    $returnObjects = foreach ($item in $responseMembers.members){
        [PSCustomObject]@{
            ID = $item.user.id
            Summary = $item.user.summary
            Type = $item.user.type
            Self = $item.user.self
            HTMLUrl = $item.user.html_url
            Role = $item.role
        }
    }

    # Returning the response object
    $returnObjects | ForEach-Object { Write-Output $_ }
}