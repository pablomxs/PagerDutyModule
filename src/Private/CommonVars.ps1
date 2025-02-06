$myTeamId = "PS7S040"

$secretName = "PagerDutyApiKey"

$headers = @{
    "Authorization" = "Token token=$global:apiToken"
    "Accept" = "application/vnd.pagerduty+json;version=2"
}
