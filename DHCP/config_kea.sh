#!/bin/bash
set -e

read -p "Por favor, insira o NOME da interface de rede a usar (ex: ens160): " IFACE

if [ -z "$IFACE" ]; then
    exit 1
fi

IP_ADDRESS="192.168.10.20/24"
DNS_SERVER="127.0.0.1" 
GATEWAY="192.168.10.1"
NETWORK_CIDR="192.168.10.0/24"
DOMAIN="empresa.local"
REVERSE_NETWORK="10.168.192"
REVERSE_ZONE="$REVERSE_NETWORK.in-addr.arpa"
ZONE_FILE_FW="empresa.local.zone"

sudo nmcli connection modify "$IFACE" ipv4.addresses "$IP_ADDRESS"
sudo nmcli connection modify "$IFACE" ipv4.method manual
sudo nmcli connection modify "$IFACE" ipv4.gateway "$GATEWAY"
sudo nmcli connection modify "$IFACE" ipv4.dns "$DNS_SERVER"

sudo nmcli connection down "$IFACE"
sudo nmcli connection up "$IFACE"

sudo mv /etc/named.conf /etc/named.conf.orig || true 

cat << EOF | sudo tee /etc/named.conf
acl "internal-network" {
    $NETWORK_CIDR;
};

options {
    listen-on port 53 { any; };
    listen-on-v6 { none; };
    directory       "/var/named";
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    secroots-file   "/var/named/data/named.secroots";
    recursing-file  "/var/named/data/named.recursing";
    allow-query     { localhost; internal-network; };
    allow-transfer  { localhost; };
    recursion yes;

    managed-keys-directory "/var/named/dynamic";
    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";
    include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

zone "." IN {
    type hint;
    file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

zone "$DOMAIN" IN {
    type master;
    file "$ZONE_FILE_FW";
    allow-update { none; };
};

zone "$REVERSE_ZONE" IN {
    type master;
    file "$REVERSE_NETWORK.db";
    allow-update { none; };
};
EOF

cat << EOF | sudo tee /var/named/$ZONE_FILE_FW
\$TTL 86400
@ IN SOA $DOMAIN. root.$DOMAIN. (
    2025110604
    3600
    1800
    604800
    86400
)

@   IN  NS      ns.$DOMAIN.
ns  IN  A       192.168.10.20
srv IN  A       192.168.10.10
dns IN  A       192.168.10.20
client IN A     192.168.10.100
EOF

cat << EOF | sudo tee /var/named/$REVERSE_NETWORK.db
\$TTL 86400
@ IN SOA $DOMAIN. root.$DOMAIN. (
    2025110604
    3600
    1800
    604800
    86400
)

@   IN  NS      ns.$DOMAIN.
10  IN  PTR     srv.$DOMAIN.      
20  IN  PTR     dns.$DOMAIN.      
100 IN  PTR     client.$DOMAIN.   
EOF

echo 'OPTIONS="-4"' | sudo tee -a /etc/sysconfig/named

sudo chown named:named /var/named/*.db /var/named/*.zone
sudo restorecon -Rv /var/named

sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --reload

sudo systemctl enable --now named

sudo systemctl status named | head -n 5
