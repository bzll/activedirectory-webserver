param($hostname="+",$port=8080)

Import-Module "$(Split-Path -parent $MyInvocation.MyCommand.Path)\routes.psm1" -Force

Write-Host "Web Listener: Starting..." -ForegroundColor Green

function New-ScriptBlockCallback {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Callback
    )

    # Is this type already defined?
    if (-not ( 'CallbackEventBridge' -as [type])) {
        Add-Type @' 
                using System; 
 
                public sealed class CallbackEventBridge { 
                    public event AsyncCallback CallbackComplete = delegate { }; 
 
                    private CallbackEventBridge() {} 
 
                    private void CallbackInternal(IAsyncResult result) { 
                        CallbackComplete(result); 
                    } 
 
                    public AsyncCallback Callback { 
                        get { return new AsyncCallback(CallbackInternal); } 
                    } 
 
                    public static CallbackEventBridge Create() { 
                        return new CallbackEventBridge(); 
                    } 
                } 
'@
    }
    $bridge = [callbackeventbridge]::create()
    Register-ObjectEvent -InputObject $bridge -EventName callbackcomplete -Action $Callback -MessageData $args > $null
    $bridge.Callback
}

try {
    if ($listener) { $listener.Stop(); $listener.Close() }
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://$hostname`:$port/")
    $listener.Start()
    Write-Host "Web Listener: Started on http://$hostname`:$port/" -ForegroundColor Green
}
catch {
    Write-Host "Unable to open listener. Check Admin permission or NETSH Binding" -ForegroundColor Red
    exit 1
}

$count = 0
$requestListener = {
    [cmdletbinding()]
    param($result)
    [System.Net.HttpListener]$listener = $result.AsyncState;
    $count++

    $context = $listener.EndGetContext($result);
    $request = $context.Request
    $response = $context.Response
    $response.ContentType = "application/json"

    Write-Host "------- New Request ($count) arrived ------------" -ForegroundColor Blue
    Write-Host ("Endpoint: [" + $request.HttpMethod  + "] " + $request.URL.AbsoluteUri)  -ForegroundColor Blue
    
    $message = Set-RouteDefinition -request $request
    $message_json = $message.result | ConvertTo-Json
    $response.StatusCode = $message.statusCode

    [byte[]]$buffer = [System.Text.Encoding]::UTF8.GetBytes($message_json)
    $response.ContentLength64 = $buffer.length

    $output = $response.OutputStream
    
    Write-Host "------- Sending Response ------------" -ForegroundColor Yellow
    Write-Host "Status Code: $($message.statusCode)"  -ForegroundColor Yellow
    Write-Host "Result:`n$($message_json)"  -ForegroundColor Yellow

    $output.Write($buffer, 0, $buffer.length)
    $output.Close()
}  

$context = $listener.BeginGetContext((New-ScriptBlockCallback -Callback $requestListener), $listener)
 
$StartServiceTime = Get-Date
while ($listener.IsListening) {
    If ($context.IsCompleted -eq $true) { $context = $listener.BeginGetContext(
        (New-ScriptBlockCallback -Callback $requestListener), $listener) }
         
    $oTimeLapse = New-TimeSpan -Start $StartServiceTime -End $(Get-date)
    If ($PreviousTime.Minutes -ne $oTimeLapse.Minutes) {
        $PreviousTime = $oTimeLapse
        If ($oTimeLapse.Minutes % 2 -eq 0) { 
            $FormatedDate = "$((Get-Date).ToShortDateString()) $((Get-Date).ToShortTimeString())"
            $FormatedLapse = "$($oTimeLapse.days)d $($oTimeLapse.Hours)h $($oTimeLapse.Minutes)m $($oTimeLapse.Seconds)s"
            Write-Host "$FormatedDate - running since $FormatedLapse" -ForegroundColor Green
        }
    } 
}
 
$listener.Close()
Write-Host "Web Listener: Stopped" -ForegroundColor Green