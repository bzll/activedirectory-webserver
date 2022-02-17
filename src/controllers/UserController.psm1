class UserController {
    [System.Net.HttpListenerRequest]$request
    [string]$method
    [PSCustomObject]$body
    [hashtable]$result
    [int]$statusCode
    hidden $userSchema = $(Get-Content ".\src\schemas\UserSchema.json") -join ""
    
    UserController(
        [System.Net.HttpListenerRequest]$r, 
        [string]$m, 
        [PSCustomObject]$b
    ){
        $this.request = $r
        $this.method = $m
        $this.body = $b
    }

    [void]Start() {
        switch ($this.method) {
            "POST" { 
                if ($this.body.Length -gt 0) {
                    $this.CreateUser()
                } else {
                    $this.result = @{ message = 'Empty or invalid body JSON' }
                    $this.statusCode = 400
                } 
            }
            default {
                $this.result = @{ message = 'Invalid method' }
                $this.statusCode = 400
            }
        }
    }

    [void]CreateUser() {
        try {
            if (Test-Json -Json $(ConvertTo-Json $this.body) -Schema $this.userSchema -ErrorVariable result_schema -ErrorAction SilentlyContinue) {  
                $user_name = $this.body.user_name ? $this.body.user_name : $this.GetAvailableUser($this.body.name);
                $password = $this.GenerateRandomPassword(8)
                $given_name = $this.body.name.Split(" ")[0]
                $sur_name = $this.body.name.Split(" ")[-1]
                $mail = $this.body.email ? $this.body.email : $user_name + "@mail.com"
                if($user_name.Length -gt 0) {
                    New-ADUser `
                        -Name $($this.body.name) `
                        -AccountPassword $(ConvertTo-SecureString $password -AsPlainText -Force) `
                        -GivenName $given_name `
                        -Surname $sur_name `
                        -SamAccountName $user_name `
                        -ChangePasswordAtLogon $True `
                        -Company $($this.body.company) `
                        -Title $($this.body.title) `
                        -State $($this.body.state) `
                        -City $($this.body.city) `
                        -Description $($this.body.description) `
                        -EmployeeNumber $($this.body.employee_number) `
                        -EmployeeID $($this.body.employee_id) `
                        -Department $($this.body.department) `
                        -DisplayName $($this.body.name) `
                        -Country $($this.body.country) `
                        -PostalCode $($this.body.zip) `
                        -Enabled $true `
                        -Manager $($this.body.manager) `
                        -Office $($this.body.office) `
                        -OfficePhone $($this.body.phone) `
                        -StreetAddress $($this.body.street_address) `
                        -UserPrincipalName $mail `
                        -EmailAddress $mail `
                        -Path $($this.body.path) `
                        -MobilePhone $($this.body.mobile ? $this.body.mobile : "" )
    
                    $new_user = Get-AdUser -Identity $user_name
    
                    $this.statusCode = 200
                    $this.result = @{
                        message = "OK";
                        details = @{
                            user      = $new_user;
                            password  = $password;
                        }
                    }
                } else {
                    $this.statusCode = 400
                    $this.result = @{
                        error_message = "Invalid or empty user";
                        error_details = "If you have not specified the 'user_name' attribute," +
                                " when trying to assemble a valid combination of user" +
                                " (taking the first and last name), probably the result" +
                                " of this combination already has in an existing user," +
                                " therefore, it is recommended that you inform a content" + 
                                "valid in the 'user_name' attribute inside the body"
                    }
                }
            } else {
                $this.statusCode = 400
                $private:result_schema =  $private:result_schema ? ($private:result_schema | % ErrorDetails | % Message) : ""
                $this.result = @{
                    error_message = "Not passed on json schema";
                    error_details = $private:result_schema
                }
            }
        } catch {
            $error_message = $_.Exception.Message
            $error_details = $_.Exception.InnerException.Message
            $this.result = @{ error_message = $error_message;
                              error_details = $error_details;
                            }
            $this.statusCode = 400
        }
    }

    [string]GetAvailableUser($name) {

        $user_name = ""
        $name = $name.toLower().Split(" ")
        $last = $name.Length
        $first = 1
        $available = $false
        if ($name.Length -gt 1) {
            while ($last -gt $($first) -and (!$available)) {
                $user_name = $name[$first - 1] + "." + $name[$last - 1]
                if ($(try { Get-ADUser -Identity $user_name } catch { $null }) -eq $null) {
                    $available = $true
                    break
                }
                $last -= 1
            }
            $first = 2
            $last = $name.Length
            while ($first -lt $($last) -and (!$available)) {
                $user_name = $name[$first - 1] + "." + $name[$last - 1]
                if ($(try { Get-ADUser -Identity $user_name } catch { $null }) -eq $null) {
                    $available = $true
                    break
                }
                $first += 1
            }
        }
    
        if ($available) { return $user_name } else { return $null }
    }

    [string]GenerateRandomPassword([int]$length = 8) {
        
        $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{]+-[*=@:)}$^%;(_!&amp;#?>/|.'.ToCharArray()
        $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $bytes = New-Object byte[]($length)
        $rng.GetBytes($bytes)
        $return = New-Object char[]($length)
     
        for ($i = 0 ; $i -lt $length ; $i++) { $return[$i] = $charSet[$bytes[$i] % $charSet.Length] }
        return (-join $return)
    }
}