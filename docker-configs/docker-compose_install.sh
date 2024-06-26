#!/bin/bash
#
###############################################################################
# Copyright (C) 2020 Simon Adlem, G7RZU <g7rzu@gb7fr.org.uk>  
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software Foundation,
#   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
###############################################################################

echo FreeDMR Docker installer...

echo Installing required packages...
echo Install Docker Community Edition...
apt-get -y remove docker docker-engine docker.io &&
apt-get -y update &&
apt-get -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common &&
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - &&
ARCH=`/usr/bin/arch`
echo "System architecture is $ARCH" 
if [ "$ARCH" == "x86_64" ]
then
    ARCH="amd64"
fi
add-apt-repository \
   "deb [arch=$ARCH] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable" &&
apt-get -y update &&
apt-get -y install docker-ce &&

echo Install Docker Compose...
apt-get -y install docker-compose &&

echo Set userland-proxy to false...
cat <<EOF > /etc/docker/daemon.json &&
{
     "userland-proxy": false,
     "experimental": true,
     "log-driver": "json-file",
     "log-opts": {
        "max-size": "10m",
        "max-file": "3"
      }
}
EOF

echo Restart docker...
systemctl restart docker &&

echo Make config directory...
mkdir /etc/freedmr &&
mkdir -p /etc/freedmr/acme.sh && 
mkdir -p /etc/freedmr/certs &&
chmod -R 755 /etc/freedmr &&

echo make json directory...
mkdir -p /etc/freedmr/json &&
chown 54000:54000 /etc/freedmr/json &&

echo Install /etc/freedmr/freedmr.cfg ... 
cat << EOF > /etc/freedmr/freedmr.cfg
#This empty config file will use defaults for everything apart from OBP and HBP config
#This is usually a sensible choice. 

#I have moved to a config like this to encourage servers to use the accepted defaults 
#unless you really know what you are doing.

[GLOBAL]
#If you join the FreeDMR network, you need to add your ServerID Here.
SERVER_ID: 0

[REPORTS]

[LOGGER]

[ALIASES]

[ALLSTAR]

#This is an example OpenBridgeProtocol (OBP) or FreeBridgeProtocol (FBP) configuration
#If you joing FreeDMR, you will be given a config like this to paste in
[OBP-TEST]
MODE: OPENBRIDGE
ENABLED: False
IP:
PORT: 62044
#The ID which you expect to see sent from the other end of the link. 
NETWORK_ID: 1
PASSPHRASE: mypass
TARGET_IP: 
TARGET_PORT: 62044
USE_ACL: True
SUB_ACL: DENY:1
TGID_ACL: PERMIT:ALL
#Should always be true if using docker. 
RELAX_CHECKS: True
#True for FBP, False for OBP
ENHANCED_OBP: True
#PROTO_VER should be 5 for FreeDMR servers using FBP
#1 for other servers using OBP
PROTO_VER: 5

#This defines parameters for repeater/hotspot connections 
#via HomeBrewProtocol (HBP)
#I don't recommend changing most of this unless you know what you are doing
[SYSTEM]
MODE: MASTER
ENABLED: True
REPEAT: True
MAX_PEERS: 1
EXPORT_AMBE: False
IP: 127.0.0.1
PORT: 54000
PASSPHRASE:
GROUP_HANGTIME: 5
USE_ACL: True
REG_ACL: DENY:1
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL
DEFAULT_UA_TIMER: 10
SINGLE_MODE: True
VOICE_IDENT: True
TS1_STATIC:
TS2_STATIC:
DEFAULT_REFLECTOR: 0
ANNOUNCEMENT_LANGUAGE: en_GB
GENERATOR: 100
ALLOW_UNREG_ID: False
PROXY_CONTROL: True
OVERRIDE_IDENT_TG:

#Echo (Loro / Parrot) server
[ECHO]
MODE: PEER
ENABLED: True
LOOSE: False
EXPORT_AMBE: False
IP: 127.0.0.1
PORT: 54916
MASTER_IP: 127.0.0.1
MASTER_PORT: 54915
PASSPHRASE: passw0rd
CALLSIGN: ECHO
RADIO_ID: 1000001
RX_FREQ: 449000000
TX_FREQ: 444000000
TX_POWER: 25
COLORCODE: 1
SLOTS: 1
LATITUDE: 00.0000
LONGITUDE: 000.0000
HEIGHT: 0
LOCATION: Earth
DESCRIPTION: ECHO
URL: www.freedmr.uk
SOFTWARE_ID: 20170620
PACKAGE_ID: MMDVM_FreeDMR
GROUP_HANGTIME: 5
OPTIONS:
USE_ACL: True
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL
ANNOUNCEMENT_LANGUAGE: en_GB
EOF


echo Set perms on config directory...
chown -R 54000 /etc/freedmr &&

echo Get docker-compose.yml...
cd /etc/freedmr &&
curl https://gitlab.hacknix.net/hacknix/FreeDMR/-/raw/master/docker-configs/docker-compose.yml -o docker-compose.yml &&

chmod 755 /etc/cron.daily/lastheard

echo Tune network stack...
cat << EOF > /etc/sysctl.conf &&
net.core.rmem_default=134217728
net.core.rmem_max=134217728
net.core.wmem_max=134217728                       
net.core.rmem_default=134217728
net.core.netdev_max_backlog=250000
net.netfilter.nf_conntrack_udp_timeout=15
net.netfilter.nf_conntrack_udp_timeout_stream=35
EOF

/usr/sbin/sysctl -p &&

echo Run FreeDMR container...
docker-compose up -d

echo Read notes in /etc/freedmr/docker-compose.yml to understand how to implement extra functionality.
echo FreeDMR setup complete!
