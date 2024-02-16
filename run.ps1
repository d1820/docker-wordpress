
param(
    [Parameter(Mandatory = $true)]
    [string]$Domain
)

Write-Host "Building Folder Structure" -ForegroundColor Blue
New-Item -ItemType Directory -Path "../kubedata/mysql" -Force
New-Item -ItemType Directory -Path "../kubedata/certs" -Force
New-Item -ItemType Directory -Path "../kubedata/wp" -Force
New-Item -ItemType Directory -Path "../kubedata/www" -Force

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

Write-Host "Updating ngix with domain $Domain" -ForegroundColor Blue
Write-Host ""
$content = Get-Content -Path ".\templates\nginx.conf" -Raw
$content = $content -replace '\{DOMAIN\}', $Domain
$content | Set-Content -Path ".\nginx.conf"

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

Write-Host ""
Write-Host "MyPHPAdmin: User:admin Password:password!" -ForegroundColor Cyan
Write-Host "MySql: User:wordpress Password:wordpress RootPsw: password!" -ForegroundColor Cyan
Write-Host "Initial Wordpress: User:wordpress Password:wordpress!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Wordpress site running at http://$($Domain):8282" -ForegroundColor Green
Write-Host "Wordpress site running at https://$($Domain):8585" -ForegroundColor Green

