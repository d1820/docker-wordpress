
param(
    [Parameter(Mandatory = $true)]
    [string]$Domain
)

Write-Host "Building Folder Structure" -ForegroundColor Blue
Write-Host ""
New-Item -ItemType Directory -Path "../kubedata/mysql" -Force > $null
New-Item -ItemType Directory -Path "../kubedata/certs" -Force > $null
New-Item -ItemType Directory -Path "../kubedata/wp" -Force > $null
New-Item -ItemType Directory -Path "../kubedata/www" -Force > $null

Write-Host "Installing MkCert" -ForegroundColor Blue
Write-Host ""
choco install mkcert  > $null

Write-Host "Creating Cert for $Domain" -ForegroundColor Blue
Write-Host ""
mkcert -install -cert-file "..\kubedata\certs\$Domain.crt"  -key-file "..\kubedata\certs\$Domain.key" "$Domain"

Write-Host "Updating compose with domain $Domain" -ForegroundColor Blue
Write-Host ""
$content = Get-Content -Path ".\templates\wordpress-compose.yml" -Raw
$content = $content -replace '\{DOMAIN\}', $Domain
$content | Set-Content -Path ".\wordpress-compose.yml"

Write-Host "Updating apache2 for SSL with domain $Domain" -ForegroundColor Blue
Write-Host ""
$content = Get-Content -Path ".\templates\default-ssl.conf" -Raw
$content = $content -replace '\{DOMAIN\}', $Domain
$content | Set-Content -Path ".\default-ssl.conf"

Write-Host "Verifying hosts file contains $Domain" -ForegroundColor Blue
Write-Host ""
$hostsFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
$ipAddress = "127.0.0.1"

# Check if the domain exists in the hosts file
if (Get-Content -Path $hostsFilePath | Select-String -Pattern $Domain -Quiet) {
    Write-Host "$Domain already exists in the hosts file."
}
else {
    # Add the domain to the hosts file
    Add-Content -Path $hostsFilePath -Value "$ipAddress $Domain"
    Write-Host "$Domain added to the hosts file."
}

Write-Host "Starting Containers" -ForegroundColor Blue
Write-Host ""
docker-compose  -f ".\wordpress-compose.yml" up -d --remove-orphans


do {
    $containerStatus = docker inspect -f '{{.State.Status}}' wp
    if ($containerStatus -eq "running") {
        break
    }
    else {
        Write-Host "Container 'wp' is not running yet. Waiting..."
        Start-Sleep -Seconds 5
    }
} until ($false)

Write-Host "Setting domain $Domain in wp servername.conf" -ForegroundColor Blue
Write-Host ""
# docker exec -it wp sh -c 'echo "127.0.0.1	leslierae.com localhost"  | tee /etc/hosts'
#docker exec -it wp sh -c 'echo "ServerName 127.0.0.1" | tee -a /etc/apache2/conf-available/servername.conf' > $null
docker exec -it wp sh -c 'echo "ServerName 127.0.0.1" | tee -a /etc/apache2/apache2.conf'

Write-Host "Enabling SSL for domain $Domain in wp" -ForegroundColor Blue
Write-Host ""
docker exec -it wp sh -c 'a2enmod ssl'
docker exec -it wp sh -c 'a2ensite default-ssl'

do {
    $serviceReloaded = docker exec -it wp sh -c 'service apache2 reload' 2>&1
    if ($serviceReloaded -match "failed!") {
        Write-Host "Apache2 service is not running yet. Waiting..."
        Start-Sleep -Seconds 10
    }
    else {
        break
    }
} until ($false)

docker exec -it wp sh -c 'service apache2 restart' > $null

Write-Host ""
Write-Host "MyPHPAdmin: User:admin Password:password!" -ForegroundColor Cyan
Write-Host "MySql: User:wordpress Password:wordpress RootPsw: password!" -ForegroundColor Cyan
Write-Host "Initial Wordpress: User:wordpress Password:wordpress!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Wordpress site running at https://$($Domain)" -ForegroundColor Green

