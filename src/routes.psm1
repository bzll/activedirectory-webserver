using module ".\controllers\UserController.psm1"
using module ".\controllers\GroupController.psm1"

function Set-RouteDefinition($request) {

    $endpoint = $request.Url.AbsolutePath
    $method = $request.HttpMethod
    $body = Get-Body($request)
    
    switch ($endpoint) {
        "/groups" {  
            $DistributionList = [GroupController]::new($request, $method, $body, $request.QueryString)
            $DistributionList.Start()
            $result = $DistributionList.result
            $statusCode = $DistributionList.statusCode
        } "/user" { 
            $User = [UserController]::new($request, $method, $body)
            $User.Start()
            $result = $User.result
            $statusCode = $User.statusCode
         } "/health" {  
            $result = @{message = "Health Checked" }
            $statusCode = 200
        } "/health/ad/connectivity" {
            try {
                $details = Get-ADDomain -Identity domain | select DNSRoot, InfrastructureMaster
                $result = @{
                            message     = "Successfully Connected to ActiveDirectory Server" ;
                            details     = $details}
                $statusCode = 200                
            } catch {
                $error_message = $_.Exception.Message
                $error_details = $_.Exception.InnerException.Message
                $result = @{ error_message = $error_message;
                             error_details = $error_details;
                            }
                $statusCode = 400  
            }
        } default {
            $result = @{ message = 'Invalid route'; endpoint = $endpoint }
            $statusCode = 405
        }
    }
    
    return @{
        result     = $result;
        statusCode = $statusCode
    }
}

function Get-Body($request) {
    
    if ($request.HasEntityBody) {
        $body = [System.IO.StreamReader]::new($request.InputStream).ReadToEnd()
        Write-Host ("Body:`n" + $body) -ForegroundColor Blue
        try { if (Test-Json -Json $body) { $body = $body | ConvertFrom-Json } else { $body = $null } }
        catch { $body = "" }
    }
    return $body
}

Export-ModuleMember -Function "Set-RouteDefinition"