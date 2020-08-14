# Automation script for VPN server instalation and setup

Script tested on Debian 9.5
Configured server tested with:
- Windows 10 default client. CA certificate has to be imported. Login/Password authentication.
- Android StrongSwan VPN Client. Login/Password authentication. CA certificate has to be imported.
- Android StrongSwan VPN Client. Authentication with .p12 certificate.

## Configuring machine
Example using Amazon Web Services virtual machine.

Create Debian 9.5 VM and assign static IP.
Here is an instruction - https://vc.ru/dev/66942-sozdaem-svoy-vpn-server-poshagovaya-instrukciya

Setup VM firewall.
Activate UDP port 500 and UDP port 4500, remove HTTP 80 port.

## Connect to machine via SSH
Download VM SSH key.
Run shell commands:
`mv ~/Downloads/YOUR_DOWNLOADED_KEY.pem ~/.ssh
`cd ~/.ssh/
`chmod 600 YOUR_DOWNLOADED_KEY.pem

Connect to VM:
`ssh -i YOUR_DOWNLOADED_KEY.pem admin@YOUR_LIGHTSAIL_IP

## Download setup script
`wget -link-
`chmod --

## Run setup script
Login as ROOT
`sudo su

Run script in form
`setup.sh "ServerIpOrDomain" "ClientKeyPassword"

## Download CA certificate and Authentication key
`sftp - get ca.pem - root sertificate - install to client
`sftp - get client_key.p12 - client authentication certificate
