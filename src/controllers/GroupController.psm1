class GroupController {
    [System.Net.HttpListenerRequest]$request
    [string]$method
    [PSCustomObject]$body
    [hashtable]$result
    [int]$statusCode
    $query

    GroupController(
        [System.Net.HttpListenerRequest]$r, 
        [string]$m, 
        [PSCustomObject]$b,
        $q
    ){
        $this.request = $r
        $this.method = $m
        $this.body = $b
        $this.query = $q
    }

    [void]Start() {
        switch ($this.method) {
            "PUT" { 
                if ($this.body.Length -gt 0) {
                    $this.SyncAdGroupMembers()
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

    [void]SyncAdGroupMembers() {
        try {
            $actual_members = (Get-ADGroupMember -Identity $($this.body.source)).distinguishedName
            $sync_members = $this.body.members.source
            $private:members_to_remove = $actual_members | Where-Object { -not ($sync_members -contains $_) }
            $private:members_to_insert = $sync_members | Where-Object { -not ($actual_members -contains $_) }
            if ($private:members_to_insert.Length -gt 0) {
                Add-ADGroupMember -Identity $($this.body.source) -Members $private:members_to_insert -ErrorAction SilentlyContinue -Confirm:$false
            } else { $private:members_to_insert = $null }
            if ($private:members_to_remove.Length -gt 0 -and $this.query.getValues('delete') -eq "true") {
                Remove-ADGroupMember -Identity $($this.body.source) -Members $private:members_to_remove -Confirm:$false -ErrorAction SilentlyContinue
            } else { $private:members_to_remove = $null }
            $this.statusCode = 200
        }
        catch {
            $private:error_message = $_.Exception.Message
            $this.statusCode = 400
        }
        $this.result = @{
            remove_members = $private:members_to_remove;
            insert_members = $private:members_to_insert;
            group          = $($this.body.source);
            message        = 
            if ($private:members_to_remove.Length -gt 0 -or $private:members_to_insert.Length -gt 0) { 
                "done" 
            } else { "nothing to do here" }
            error_message  = $private:error_message
        }
    }
}