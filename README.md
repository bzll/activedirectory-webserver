## Setting user gMSA

### Creating account gMSA for Containers Hosts connected on domain
```powershell
# To install the AD module on Windows Server, run Install-WindowsFeature RSAT-AD-PowerShell
# Create the security group
New-ADGroup -Name "Docker Authorized Hosts" -SamAccountName "dockerHosts" -GroupScope DomainLocal -Path "OU=Teste,DC=domain";
# Create the gMSA
New-ADServiceAccount -Name "Docker" -DnsHostName "domain" -ServicePrincipalNames "host/docker", "host/domain" -PrincipalsAllowedToRetrieveManagedPassword "dockerHosts";
# Add your container hosts to the security group
Add-ADGroupMember -Identity "dockerHosts" -Members "DCC20000001$";
```
### Setting up Container Host

#### Docker and Docker-Compose installation
```powershell
# Change TLS version used by Poweshell client to TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

# Install docker
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider

# Install Docker-Compose
Invoke-WebRequest "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-Windows-x86_64.exe" -UseBasicParsing -OutFile $Env:ProgramFiles\Docker\docker-compose.exe

Restart-Computer -Force
```

> (Recommended) _Check if the host can use the gMSA account_
> ```powershell
> # To install the AD module on Windows Server, run Install-WindowsFeature RSAT-AD-PowerShell
> Test-ADServiceAccount Docker
> ```
#### Create Credential Specs 
```powershell
Install-Module CredentialSpec
# 'Docker' no caso, seria o gMSA
New-CredentialSpec -AccountName Docker
```
On this example, the file would be named domain_docker.json (normally stored in C:\ProgramData\docker\credentialspecs) with this kind of content:
```json
{
    "CmsPlugins": [
        "ActiveDirectory"
    ],
    "DomainJoinConfig": {
        "Sid": "S-1-5-21-1234567891-1234567891-1234567891",
        "MachineAccountName": "Docker",
        "Guid": "c784c784-ca78-x878-q78x-123456q781xc",
        "DnsTreeName": "domain",
        "DnsName": "domain",
        "NetBiosName": "DOMAIN"
    },
    "ActiveDirectoryConfig": {
        "GroupManagedServiceAccounts": [{
                "Name": "Docker",
                "Scope": "domain"
            },
            {
                "Name": "Docker",
                "Scope": "DOMAIN"
            }
        ]
    }
}
```

### Reference

Oficial Docs [Microsoft](https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/manage-serviceaccounts).

### Start and test

To start and test:

```sh
docker-compose up -d
```

#### Example endpoints:
group:
```sh
curl --request PUT \
  --url 'http://localhost:8080/groups' \
  --header 'Content-Type: application/json' \
  --data '{
	"source": "CN=Group,OU=Groups,DC=domain",
	"members": [
		{
			"source": "CN=Test_User1,OU=Users,DC=domain"
		},
		{
			"source": "CN=Test_User2,OU=Users,DC=domain"
		},
		{
			"source": "CN=Test_User3,OU=Users,DC=domain"
		},
		{
			"source": "CN=Test_User4,OU=Users,DC=domain"
		}
	]
}'
```
user:
```sh
curl --request POST \
  --url http://localhost:8080/user \
  --header 'Content-Type: application/json' \
  --data '{
	"name": "Ciro Bizelli",
	"manager": "ciro.bizelli",
	"description": "Something",
	"employee_id": "0000",
	"employee_number": "999.999.999-99",
	"company": "Unknow",
	"title": "Developer",
	"department": "IT",
	"phone": "(99) 9999-9999",
	"street_address": "Street 1",
	"zip": "99.999-999",
	"city": "Something",
	"office": "Office",
	"country": "BR",
	"state": "SP",
	"path": "OU=Users,DC=domain"
}'
```
health:
```sh
curl --request GET \
  --url 'http://localhost:8080/health'
```
health ad connectivity:
```sh
curl --request GET \
  --url http://localhost:8080/health/ad/connectivity
```