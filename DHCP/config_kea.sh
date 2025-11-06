#!/bin/bash

set -e

echo "Atualizando o sistema..."
sudo dnf -y update


echo "Instalando o Kea DHCP..."
sudo dnf -y install kea


echo "Fazendo backup do arquivo de configuração original
sudo cp /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.org


echo "Criando o arquivo de configuração do Kea DHCP..."


CONF="/etc/kea/kea-dhcp4.conf"


# Interfaces
sed -i 's,"interfaces": [  ],"interfaces": [ "ins33" ]' "$CONF"

# DNS Servers
sed -i 's,"name": "domain-name-servers","name": "domain-name-servers",' "$CONF"
sed -i 's,"data": "192.0.2.1, 192.0.2.2" "data": "192.168.10.10",' "$CONF"

# Domain Name (code 15 → name + data)
sed -i 's,"code": 15,"name": "domain-name",' "$CONF"
sed -i 's,"data": "example.org","data": "srv.world"/' "$CONF"

# Domain Search
sed -i 's,"name": "domain-search","name": "domain-search",' "$CONF"
sed -i 's,"data": "mydomain-example.com, example.com","data": "srv.world",' "$CONF"

# Subnet
sed -i 's,"subnet": "192.0.2.0/24","subnet": "192.168.10.0/24",' "$CONF"

# Pool
sed -i 's,"pools": [ { "pool": "192.0.2.1 - 192.0.2.200" } ],"pools": [ { "pool": "192.168.10.50 - 192.168.10.200" } ],' "$CONF"

# Gateway (routers)
sed -i 's,"name": "routers","name": "routers",' "$CONF"
sed -i 's,"data": "192.0.2.1","data": "192.168.10.1",' "$CONF"

# Reservas (reservations)
sudo sed -i 's,"ip-address": "192.0.2.201" "ip-address": "192.168.10.2",' "$CONF"
sudo sed -i 's,"ip-address": "192.0.2.202" "ip-address": "192.168.10.101",' "$CONF"
sudo sed -i 's,"ip-address": "192.0.2.203" "ip-address": "192.168.10.100",' "$CONF"
sudo sed -i 's,"ip-address": "192.0.2.204" "ip-address": "192.168.10.102",' "$CONF"
sudo sed -i 's,"ip-address": "192.0.2.205" "ip-address": "192.168.10.106",' "$CONF"
sudo sed -i 's,"ip-address": "192.0.2.206" "ip-address": "192.168.10.105",' "$CONF"
sudo sed -i 's,"next-server": "192.0.2.1" "next-server": "192.168.10.103",' "$CONF"

# data (DNS dentro das reservas)
sed -i 's,"data": "10.1.1.202, 10.1.1.203" "data": "8.8.8.8",' "$CONF"

# logging output
sed -i 's,"output": "kea-dhcp4.log","output": "/var/log/kea/kea-dhcp4.log",' "$CONF"



echo "Alterando permissões e propriedade do arquivo de configuração..."
chown root:kea /etc/kea/kea-dhcp4.conf
chmod 640 /etc/kea/kea-dhcp4.conf


echo "Habilitando e iniciando o serviço Kea DHCP..."
systemctl enable --now kea-dhcp4


echo "Verificando o status do Kea DHCP..."
systemctl status kea-dhcp4 


echo "Configuração do Kea DHCP concluída. O serviço está rodando."


echo "Habilitando a firewall"
firewall-cmd --add-service=dhcp
firewall-cmd --runtime-to-permanent

echo "Lista os arquivos e diretórios no diretório /var/lib/kea com detalhes adicionais"
sudo ls -l /var/lib/kea



