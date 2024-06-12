### Install chocolatey
if ([bool](Get-Command -Name 'choco' -ErrorAction SilentlyContinue)) {
    Write-Verbose "Chocolatey is already installed, skip installation." -Verbose
}
else {
    Write-Verbose "Installing Chocolatey..." -Verbose
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}



### Install OpenSSH Server
Write-Verbose "Installing OpenSSH..." -Verbose
$openSSHpackages = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*' | Select-Object -ExpandProperty Name

foreach ($package in $openSSHpackages) {
    Add-WindowsCapability -Online -Name $package
}

# Start the sshd service
Write-Verbose "Starting OpenSSH service..." -Verbose
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
Write-Verbose "Confirm the Firewall rule is configured..." -Verbose
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}
else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}



### SSH Config PubKeyAuthentication
# Define the path to your file
$sshdConfigPath = "$env:PROGRAMDATA\ssh\sshd_config"

# Read the file content into an array
$fileContent = Get-Content -Path $sshdConfigPath

# Loop through each line in the file
for ($i = 0; $i -lt $fileContent.Length; $i++) {
    # Check if the current line contains "#PubKeyAuthentication yes"
    if ($fileContent[$i] -match "#PubKeyAuthentication yes") {
        # Modify the line as needed
        $fileContent[$i] = "PubKeyAuthentication yes"  # Example change
        break  # Exit the loop after making the change
    }
}

# Write the modified content back to the file
$fileContent | Set-Content -Path $sshdConfigPath



### Add SSH public key
# Define the path to the ssh folder and the authorized keys file
$sshFolderPath = "$env:PROGRAMDATA\ssh"
$authorizedKeysFilePath = Join-Path $sshFolderPath "administrators_authorized_keys"

# Create the administrators_authorized_keys file and add the public key
New-Item -ItemType File -Path $authorizedKeysFilePath -Force
"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb9RNnRbyNZbTGGcX2wm0qvURoOKh80FBmipmUah433 ansible@krathwohl.io" | Set-Content $authorizedKeysFilePath

# Get the ACL of the file
$acl = Get-Acl $authorizedKeysFilePath

# Enable access rule protection
$acl.SetAccessRuleProtection($true, $false)

# Define access rules
$administratorsRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")

# Add the access rules to the ACL
$acl.SetAccessRule($administratorsRule)
$acl.SetAccessRule($systemRule)

# Apply the modified ACL to the file
Set-Acl -Path $authorizedKeysFilePath -AclObject $acl

Write-Output "The administrators_authorized_keys file has been created and configured successfully."





### CHANGE ANSIBLE SHELL TYPE

#ansible-galaxy install -r requirements.yml

#ansible-playbook .\playbooks\mx\chocolatey.yml -i inventory.ini -e "hosts=bkrathwohl-pc"