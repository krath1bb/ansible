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


    ###Doesnt work if its an admin user
#C:\Users\bkrathwohl\.ssh\authorized_keys
#    cd $env:USERPROFILE; mkdir .ssh; cd .ssh; New-Item authorized-keys; "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb9RNnRbyNZbTGGcX2wm0qvURoOKh80FBmipmUah433 ansible@krathwohl.io" | Set-Content authorized_keys
cd $env:PROGRAMDATA\ssh; New-Item administrators_authorized_keys;"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOb9RNnRbyNZbTGGcX2wm0qvURoOKh80FBmipmUah433 ansible@krathwohl.io" | Set-Content administrators_authorized_keys
$acl = Get-Acl $env:PROGRAMDATA\ssh\administrators_authorized_keys
$acl.SetAccessRuleProtection($true, $false)
$administratorsRule = New-Object system.security.accesscontrol.filesystemaccessrule("Administrators","FullControl","Allow")
$systemRule = New-Object system.security.accesscontrol.filesystemaccessrule("SYSTEM","FullControl","Allow")
$acl.SetAccessRule($administratorsRule)
$acl.SetAccessRule($systemRule)
$acl | Set-Acl

### CHANGE ANSIBLE SHELL TYPE
### AUTOMATE PubKeyAuthentication ADJUST


pip3 install --upgrade pip
pip3 install ansible

ansible-galaxy install -r requirements.yml

ansible-playbook .\playbooks\mx\chocolatey.yml -i inventory.ini -e "hosts=bkrathwohl-pc"