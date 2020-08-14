#!/bin/bash

# check script parameters
if [ -n "$1" ]
then
echo "SERVER_IP set to $1"
else
echo "No server IP or Domain found"
exit
fi

if [ -n "$2" ]
then
echo "client_key.p12 password set to $2"
else
echo "No key password found"
exit
fi

SERVER_IP=$1
KEY_PASS=$2

# install required packages
sudo su
apt-get update
apt-get upgrade
apt-get install strongswan
apt-get install strongswan-pki

# ----------------------------
# Generate sertificates
# ----------------------------
# go to certificates directory
cd /etc/ipsec.d/

# clean old certificates
rm private/*
rm cacerts/*
rm certs/*

# generate root certificate key
ipsec pki --gen --type rsa --size 4096 --outform pem > private/ca.pem

# generate root certificate
ipsec pki --self --ca --lifetime 3650 \
--in private/ca.pem --type rsa \
--dn "C=US, O=VPN Server, CN=${SERVER_IP}" \
--outform pem > cacerts/ca.pem
#--digest sha256

# generate server certificate key
ipsec pki --gen --type rsa --size 4096 --outform pem > private/debian.pem

# generate server certificate
ipsec pki --pub --in private/debian.pem --type rsa |
ipsec pki --issue --lifetime 3650 \
--cacert cacerts/ca.pem --cakey private/ca.pem \
--dn "C=US, O=VPN Server, CN=${SERVER_IP}" \
--san ${SERVER_IP} --flag serverAuth --flag ikeIntermediate \
--outform pem > certs/debian.pem
#--digest sha256

# generate client key
ipsec pki --gen --type rsa --size 4096 --outform pem > private/me.pem

# generate client sertificate
ipsec pki --pub --in private/me.pem --type rsa |
ipsec pki --issue --lifetime 3650 \
--cacert cacerts/ca.pem --cakey private/ca.pem \
--dn "C=US, O=VPN Server, CN=me" \
--san me --flag clientAuth --flag ikeIntermediate \
--outform pem > certs/me.pem

# pack client key to .p12 file

openssl pkcs12 -export \
-inkey /etc/ipsec.d/private/me.pem \
-in /etc/ipsec.d/certs/me.pem \
-name "me" \
-certfile /etc/ipsec.d/cacerts/ca.pem \
-password pass:"${KEY_PASS}" \
> client_key.p12

# ----------------------------
# StrongSwap VPN server setup
# ----------------------------

# clean default config
> /etc/ipsec.conf

# write server config
cat > /etc/ipsec.conf << EOF1
include /var/lib/strongswan/ipsec.conf.inc

config setup
        charondebug="ike 1, knl 1, cfg 0"
        uniqueids=never

conn %default
        keyexchange=ikev2
        auto=add
        compress=yes
        type=tunnel
        fragmentation=yes
        forceencaps=yes

        ike=aes256-sha1-modp1024,3des-sha1-modp1024,aes128gcm16-sha2_256-prfsha256-ecp256!
        esp=aes256-sha1,3des-sha1,aes128gcm16-sha2_256-ecp256!

        dpdaction=clear
        dpddelay=300s
        rekey=no

        # server
        left=%any
        leftauth=pubkey
        leftsourceip=$SERVER_IP
        leftid=$SERVER_IP
        leftcert=debian.pem
        leftsendcert=always
        leftsubnet=0.0.0.0/0

        # client
        right=%any
        rightsourceip=10.10.10.0/24
        rightdns=8.8.8.8,8.8.4.4

# android
conn ikev2-pubkey
        rightauth=pubkey

# win10
conn ikev2-eap
        rightauth=eap-mschapv2
        eap_identity=%identity
EOF1

# write server authentication configuration
cat > /etc/ipsec.secrets << EOF1
# This file holds shared secrets or RSA private keys for authentication.

# RSA private key for this host, authenticating it to any other host
# which knows the public part.

# this file is managed with debconf and will contain the automatically created private key

include /var/lib/strongswan/ipsec.secrets.inc

: RSA debian.pem

user %any% : EAP "user"
EOF1

# restart VPN server with new configuration
ipsec restart

# ----------------------------
# Machine network configuration setup
# ----------------------------

sed -i -e "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf
sed -i -e "s/#net.ipv4.conf.all.accept_redirects = 0/net.ipv4.conf.all.accept_redirects = 0/g" /etc/sysctl.conf
sed -i -e "s/#net.ipv4.conf.all.send_redirects = 0/net.ipv4.conf.all.send_redirects = 0/g" /etc/sysctl.conf
sed -i -e "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" /etc/sysctl.conf
echo 'net.ipv4.ip_no_pmtu_disc = 1' >> /etc/sysctl.conf

sysctl -p

# IP tables setup
apt-get install iptables-persistent
# here 

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -Z

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

iptables -A INPUT -i lo -j ACCEPT

iptables -A INPUT -p udp --dport  500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT

iptables -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s 10.10.10.0/24 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT

iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o eth0 -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o eth0 -j MASQUERADE

iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP

netfilter-persistent save
netfilter-persistent reload

reboot
