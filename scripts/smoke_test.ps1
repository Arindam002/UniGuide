[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$Origin,

    [string]$DemoEmail,

    [string]$DemoPassword,

    [switch]$TestRateLimit
)

$ErrorActionPreference = "Stop"

if (($DemoEmail -and -not $DemoPassword) -or (-not $DemoEmail -and $DemoPassword)) {
    throw "Provide both -DemoEmail and -DemoPassword, or neither."
}

$base = $BaseUrl.TrimEnd("/")
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-BackendRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [hashtable]$Headers = @{},

        [string]$Body,

        [switch]$CaptureBody
    )

    $requestParameters = @{
        Uri             = "$base$Path"
        Method          = $Method
        Headers         = $Headers
        UseBasicParsing = $true
        TimeoutSec      = 180
        ErrorAction     = "Stop"
    }

    if ($PSBoundParameters.ContainsKey("Body")) {
        $requestParameters.Body = $Body
        $requestParameters.ContentType = "application/json"
    }

    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest @requestParameters
        $statusCode = [int]$response.StatusCode
        $responseHeaders = $response.Headers
        $responseBody = ""
        if ($CaptureBody) {
            $responseBody = [string]$response.Content
        }
        $errorMessage = ""
    }
    catch {
        $response = $_.Exception.Response
        if ($null -ne $response) {
            $statusCode = [int]$response.StatusCode
            $responseHeaders = $response.Headers
            $responseBody = ""
            $errorMessage = ""
        }
        else {
            $statusCode = 0
            $responseHeaders = @{}
            $responseBody = ""
            $errorMessage = "No HTTP response"
        }
    }
    finally {
        $timer.Stop()
    }

    [pscustomobject]@{
        StatusCode = $statusCode
        Headers    = $responseHeaders
        Body       = $responseBody
        ElapsedMs  = [Math]::Round($timer.Elapsed.TotalMilliseconds)
        Error      = $errorMessage
    }
}

function Add-Result {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details,
        [switch]$Skipped
    )

    [void]$results.Add([pscustomobject]@{
        Check   = $Name
        Result  = if ($Skipped) { "SKIP" } elseif ($Passed) { "PASS" } else { "FAIL" }
        Details = $Details
    })
}

$health = Invoke-BackendRequest -Method "GET" -Path "/health"
Add-Result -Name "GET /health" -Passed ($health.StatusCode -eq 200) -Details "HTTP $($health.StatusCode)"

$chatBody = @{
    question = "Explain binary search"
    guest_id = "smoke-test"
} | ConvertTo-Json -Compress
$chat = Invoke-BackendRequest -Method "POST" -Path "/chat/" -Body $chatBody -CaptureBody
$answer = ""
$answerIssue = ""
if ($chat.StatusCode -eq 200 -and $chat.Body) {
    try {
        $chatResponse = $chat.Body | ConvertFrom-Json
        if ($chatResponse.answer -is [string]) {
            $answer = $chatResponse.answer.Trim()
        }
        else {
            $answerIssue = "answer field missing or invalid"
        }
    }
    catch {
        $answerIssue = "response JSON invalid"
    }
}
elseif ($chat.StatusCode -eq 200) {
    $answerIssue = "response body empty"
}
$answerPreview = ($answer -replace '\s+', ' ').Trim()
if ($answerPreview.Length -gt 150) {
    $answerPreview = $answerPreview.Substring(0, 150)
}
Write-Output ("CHAT status={0} time_ms={1} answer={2}" -f $chat.StatusCode, $chat.ElapsedMs, $answerPreview)
$chatDetails = "HTTP $($chat.StatusCode)"
if ($answerIssue) {
    $chatDetails = "$chatDetails; $answerIssue"
}
Add-Result -Name "POST /chat/ returns an answer" -Passed ($chat.StatusCode -eq 200 -and -not [string]::IsNullOrWhiteSpace($answer)) -Details $chatDetails

$preflightHeaders = @{
    Origin                         = $Origin
    "Access-Control-Request-Method" = "POST"
    "Access-Control-Request-Headers" = "content-type"
}
$preflight = Invoke-BackendRequest -Method "OPTIONS" -Path "/chat/" -Headers $preflightHeaders
$allowedOrigin = [string]$preflight.Headers["Access-Control-Allow-Origin"]
Add-Result -Name "CORS allows configured origin" -Passed ($preflight.StatusCode -eq 200 -and $allowedOrigin -ceq $Origin) -Details "HTTP $($preflight.StatusCode); exact origin match: $($allowedOrigin -ceq $Origin)"

$authPreflightHeaders = @{
    Origin                          = $Origin
    "Access-Control-Request-Method" = "POST"
    "Access-Control-Request-Headers" = "content-type,authorization"
}
$authPreflight = Invoke-BackendRequest -Method "OPTIONS" -Path "/chat/" -Headers $authPreflightHeaders
$authAllowedOrigin = [string]$authPreflight.Headers["Access-Control-Allow-Origin"]
$allowedHeaders = ([string]$authPreflight.Headers["Access-Control-Allow-Headers"]).ToLowerInvariant()
$headersAllowed = $allowedHeaders.Contains("content-type") -and $allowedHeaders.Contains("authorization")
Add-Result -Name "CORS allows Flutter headers" -Passed ($authPreflight.StatusCode -eq 200 -and $authAllowedOrigin -ceq $Origin -and $headersAllowed) -Details "HTTP $($authPreflight.StatusCode); Content-Type and Authorization allowed: $headersAllowed"

$evilOrigin = "https://evil.example"
$evilHeaders = @{
    Origin                          = $evilOrigin
    "Access-Control-Request-Method" = "POST"
    "Access-Control-Request-Headers" = "content-type"
}
$evilPreflight = Invoke-BackendRequest -Method "OPTIONS" -Path "/chat/" -Headers $evilHeaders
$evilAllowedOrigin = [string]$evilPreflight.Headers["Access-Control-Allow-Origin"]
Add-Result -Name "CORS rejects unconfigured origin" -Passed ($evilPreflight.StatusCode -eq 200 -and $evilAllowedOrigin -ne $evilOrigin) -Details "HTTP $($evilPreflight.StatusCode); evil origin allowed: $($evilAllowedOrigin -eq $evilOrigin)"

if ($DemoEmail -and $DemoPassword) {
    $loginBody = @{
        email    = $DemoEmail
        password = $DemoPassword
    } | ConvertTo-Json -Compress
    $login = Invoke-BackendRequest -Method "POST" -Path "/students/login" -Body $loginBody
    Write-Output ("DEMO_LOGIN status={0}" -f $login.StatusCode)
    Add-Result -Name "POST /students/login" -Passed ($login.StatusCode -eq 200) -Details "HTTP $($login.StatusCode)"
}
else {
    Add-Result -Name "POST /students/login" -Passed $false -Skipped -Details "Credentials not supplied"
}

if ($TestRateLimit) {
    $rateLimitHit = $false
    for ($i = 0; $i -lt 12; $i++) {
        $rateResponse = Invoke-BackendRequest -Method "POST" -Path "/chat/" -Body $chatBody
        if ($rateResponse.StatusCode -eq 429) {
            $rateLimitHit = $true
        }
    }
    Write-Output ("RATE_LIMIT 429_seen={0}" -f $rateLimitHit)
    Add-Result -Name "Chat rate limit returns 429" -Passed $rateLimitHit -Details "429 seen: $rateLimitHit"
}
else {
    Add-Result -Name "Chat rate limit returns 429" -Passed $false -Skipped -Details "Use -TestRateLimit; sends 12 chat requests"
}

Write-Output ""
Write-Output "Smoke test summary:"
$results | Format-Table -AutoSize
