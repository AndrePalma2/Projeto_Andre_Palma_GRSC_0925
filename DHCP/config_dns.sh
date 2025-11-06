#!/bin/bash
set -e

# =======================================================
# 1. PEDIR INTERFACE E DEFINIÇÕES
# =======================================================

echo "-----------------------------------------------------"
echo "CONFIGURAÇÃO AUTOMÁTICA DO SERVIDOR BIND (DNS)"
echo "-----------------------------------------------------"

read -p "Por favor, insira o NOME da interface de rede a usar (ex: ens160): " IFACE

if [ -z "$IFACE" ]; then
    echo "Erro: O nome da interface não pode estar vazio. Abortando."
    exit 1
fi

# DEFINIÇÕES DO SERVIDOR BIND (Servidor 2)
IP_ADDRESS="192.168.10.20/24"
DNS_SERVER="127.0.0.1" # O BIND usa o seu próprio IP como DNS primário
GATEWAY="192.168.10.1"
DOMAIN="srv.world"
REVERSE_ZONE="10.168.192.in-addr.arpa"

echo "Interface: $IFACE. IP Fixo: $IP_ADDRESS"
sleep 2

# =======================================================
# 2. CONFIGURAR INTERFACE COM IP FIXO (nmcli)
# =======================================================

echo "====================================================="
echo "2. CONFIGURANDO A INTERFACE $IFACE PARA $IP_ADDRESS..."
echo "====================================================="

sudo nmcli connection modify "$IFACE" ipv4.addresses "$IP_ADDRESS"
sudo nmcli connection modify "$IFACE" ipv4.method manual
sudo nmcli connection modify "$IFACE" ipv4.gateway "$GATEWAY"
sudo nmcli connection modify "$IFACE" ipv4.dns "$DNS_SERVER"

sudo nmcli connection down "$IFACE"
sudo nmcli connection up "$IFACE"

echo "Endereço IP aplicado: $(nmcli device show "$IFACE" | grep "IP4.ADDRESS" | awk '{print $2}')"
sleep 2

# =======================================================
# 3. INSTALAR O BIND (Com correção para o pacote)
# =======================================================

echo "====================================================="
echo "3. INSTALANDO O BIND E UTILITÁRIOS..."
echo "====================================================="

sudo dnf -y update

# Instala bind ou bind-utils, resolvendo o erro not found
sudo dnf -y install bind bind-utils || sudo dnf -y install bind || { echo "Falha na instalação do BIND. Verifique a conexão."; exit 1; }
sleep 2

# =======================================================
# 4. CONFIGURAÇÃO DO BIND (named.conf)
# =======================================================

echo "====================================================="
echo "4. CONFIGURANDO FICHEIROS DE ZONA..."
echo "====================================================="

sudo mv /etc/named.conf /etc/named.conf.orig 

echo "Criando o ficheiro named.conf..."
cat << EOF | sudo tee /etc/named.conf
options {
    listen-on port 53 { 127.0.0.1; $IP_ADDRESS; }; 
    directory       "/var/named";
    allow-query     { localhost; 192.168.10.0/24; }; 
    recursion yes;
    dnssec-enable yes;
    dnssec-validation yes;
    managed-keys-directory "/var/named/dynamic";
    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";
    include "/etc/crypto/mkeys.asc";
};

zone "." IN { type hint; file "named.ca"; };
zone "$DOMAIN" IN {
    type master;
    file "srv.world.zone"; 
    allow-update { none; };
};
zone "$REVERSE_ZONE" IN {
    type master;
    file "192.168.10.zone";
    allow-update { none; };
};
include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF

# Cria a Zona de Forward (srv.world)
echo "Criando a Zona de Forward ($DOMAIN)..."
cat << EOF | sudo tee /var/named/srv.world.zone
\$TTL 86400
@ IN SOA srv.world. root.srv.world. (
    2025110602  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400       ; Minimum TTL
)

@   IN  NS      ns.$DOMAIN.
ns  IN  A       192.168.10.20
srv IN  A       192.168.10.10
dns IN  A       192.168.10.20
client IN A     192.168.10.100
EOF

# Cria a Zona de Reverse (192.168.10.x)
echo "Criando a Zona de Reverse ($REVERSE_ZONE)..."
cat << EOF | sudo tee /var/named/192.168.10.zone
\$TTL 86400
@ IN SOA $DOMAIN. root.$DOMAIN. (
    2025110602  ; Serial
    3600        ; Refresh
    1800        ; Retry
    604800      ; Expire
    86400       ; Minimum TTL
)

@   IN  NS      ns.$DOMAIN.
10  IN  PTR     srv.$DOMAIN.      ; 192.168.10.10 (Kea Server)
20  IN  PTR     dns.$DOMAIN.      ; 192.168.10.20 (BIND Server)
100 IN  PTR     client.$DOMAIN.   ; 192.168.10.100 (Cliente DHCP)
EOF

# =======================================================
# 5. PERMISSÕES, FIREWALL E INÍCIO
# =======================================================

echo "====================================================="
echo "5. PERMISSÕES, FIREWALL E INÍCIO DO BIND..."
echo "====================================================="

# Permissões do ficheiro de zona
sudo chown named:named /var/named/*.zone
sudo restorecon -Rv /var/named

# Abre a porta DNS (53/UDP) na firewall
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --reload

# Inicia e habilita o serviço BIND
sudo systemctl enable --now named

echo "Verificação do status do BIND:"
sudo systemctl status named
