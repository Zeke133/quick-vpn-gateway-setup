# VPN server instalation and setup automation script

StrongSwan VPN server will be installed and configured on Linux Debian 9.5.

Tested with:
- Windows 10 default client. CA certificate has to be imported. Login/Password authentication.
- Android StrongSwan VPN Client. Login/Password authentication. CA certificate has to be imported.
- Android StrongSwan VPN Client. Authentication with .p12 certificate.

## Configuring machine
Example using Amazon Web Services virtual machine.

Create Debian 9.5 VM and assign static IP.
[Here is an instruction](https://vc.ru/dev/66942-sozdaem-svoy-vpn-server-poshagovaya-instrukciya)

Setup VM firewall:
- Activate UDP port 500 and UDP port 4500.
- Remove HTTP 80 port.

## Connect to machine via SSH
Download VM SSH key.

Run shell commands:

    mv ~/Downloads/YOUR_DOWNLOADED_KEY.pem ~/.ssh
    cd ~/.ssh/
    chmod 600 YOUR_DOWNLOADED_KEY.pem

Connect to VM:

    ssh -i YOUR_DOWNLOADED_KEY.pem admin@YOUR_LIGHTSAIL_IP

## Download setup script

    wget https://raw.githubusercontent.com/Zeke133/test/master/setup.sh
    chmod +x setup.sh

## Run setup script
Login as ROOT:

    sudo su

Run script in form:

    setup.sh $ServerIpOrDomain $ClientKeyPassword

## Download CA certificate and Authentication key

    sftp -i YOUR_DOWNLOADED_KEY.pem admin@YOUR_LIGHTSAIL_IP

Download CA root certificate. Has to be added to Windows certificate repository.
[How to setup VPN on Windows](https://wiki.strongswan.org/projects/strongswan/wiki/Win7Certs)

    get /etc/ipsec.d/cacerts/ca.pem

Download client authentication key certificate. Can be used on Android StrongSwan client to authenticate w/o login/password.

    get /etc/ipsec.d/client_key.p12

After downloading share certificates to devices you'll connect.
