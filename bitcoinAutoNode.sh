#!/bin/bash

# WARNING!
# Change these constants below to improve security
# of the server before running this executable script!
currentSshPort=22
newSshPort=44
rpcport=8332
btcport=8333
email="admin@foo.com"

echo "########### The server will reboot when the script is complete"

echo "########### Adding firewall rules; changing default SSH port to: $newSshPort"
sed -i 's/Port $currentSshPort/Port $newSshPort/g' /etc/ssh/sshd_config
service ssh restart
ufw allow $newSshPort/tcp
ufw allow $rpcport/tcp
ufw allow $btcport/tcp
ufw --force enable

echo "########### Creating swap"
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap sw 0 0" >> /etc/fstab
sysctl vm.swappiness=20
echo "vm.swappiness=20" >> /etc/sysctl.conf

echo "########### Updating Ubuntu"
apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get install python-software-properties mailutils -y

echo "########### Adding Bitcoin software repository and installing Bitcoin daemon (bitcoind)"
add-apt-repository -y ppa:bitcoin/bitcoin
apt-get update -y
mkdir ~/.bitcoin/
apt-get install bitcoind -y

config="~/.bitcoin/bitcoin.conf"
echo "########### Creating config file ($config)"
touch $config
echo "# Server" > $config
echo "testnet=0" >> $config
echo "daemon=1" >> $config
echo "connections=125" >> $config
echo "port=$btcport"
echo "paytxfee=0.0001" >> $config
echo "gen=0" >> $config
echo "4way=1" >> $config
echo "#txindex=1" >> $config
echo "#reindex=1" >> $config
echo "alertnotify=echo %s | mail -s \"Bitcoin Daemon: Alert Notification\" $email" >> $config
echo "blocknotify=echo %s | mail -s \"Bitcoin Daemon: Block Notification\" $email" >> $config
echo "walletnotify=echo %s | mail -s \"Bitcoin Daemon: Wallet Notification\" $email" >> $config
echo "# RPC" >> $config
echo "server=1" >> $config
randuser=`< /dev/urandom tr -dc A-Za-z0-9 | head -c30`
randpass=`< /dev/urandom tr -dc A-Za-z0-9 | head -c30`
echo "rpcuser=$randuser" >> $config
echo "rpcpassword=$randpass" >> $config
echo "rpcport=$rpcport" >> $config
echo "rpctimeout=30" >> $config
echo "#rpcallowip=*" >> $config
echo "#rpcssl=1" >> $config
echo "#rpcsslciphers=TLSv1.2+HIGH:TLSv1+HIGH:!SSLv2:!aNULL:!eNULL:!3DES:@STRENGTH" >> $config
echo "#rpcsslcertificatechainfile=/etc/bitcoin/server.cert" >> $config
echo "#rpcsslprivatekeyfile=/etc/bitcoin/server.pem" >> $config
chmod 600 $config

echo "########### Setting up autostart (cron)"
crontab -l > tempcron
echo "@reboot bitcoind -daemon" >> tempcron
crontab tempcron
rm tempcron

echo "########### Rebooting server"
reboot
