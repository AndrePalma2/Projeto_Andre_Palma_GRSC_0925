#!/bin/bash
set -e

echo "-----------------------------------------------------"
echo "CONFIGURAÇÃO AUTOMÁTICA DO KEA DHCP4"
echo "-----------------------------------------------------"
read -p "Por favor, insira o NOME da interface de rede a usar (ex: ens160, eth0): " IFACE

if [ -z "$IFACE" ]; then
    echo "Erro: O nome da interface não pode estar vazio. Abortando."
    exit 1
fi

IP_ADDRESS="192.168.10.20/24"  # Definindo apenas um IP
DNS_SERVER="192.168.10.10"
GATEWAY="192.168.10.1"
CONF_FILE="/etc/kea/kea-dhcp4.conf"
LOG_DIR="/var/log/kea"

echo "Interface selecionada: $IFACE"
echo "IP Fixo a ser aplicado: $IP_ADDRESS"
sleep 2

echo "====================================================="
echo "CONFIGURANDO A INTERFACE $IFACE..."
echo "====================================================="
NETWORK_CIDR="192.168.10.0/24"
DOMAIN="empresa.local"
REVERSE_NETWORK="10.168.192"
REVERSE_ZONE="$REVERSE_NETWORK.in-addr.arpa"
ZONE_FILE_FW="empresa.local.zone"

# Configura a interface de rede
sudo nmcli connection modify "$IFACE" ipv4.addresses "$IP_ADDRESS"
sudo nmcli connection modify "$IFACE" ipv4.method manual
sudo nmcli connection modify "$IFACE" ipv4.gateway "$GATEWAY"
sudo nmcli connection modify "$IFACE" ipv4.dns "$DNS_SERVER"

# Aplica as novas configurações de rede
sudo nmcli connection down "$IFACE"
sudo nmcli connection up "$IFACE"

echo "Endereço IP aplicado: $(nmcli device show "$IFACE" | grep "IP4.ADDRESS" | awk '{print $2}')"
sleep 2

echo "====================================================="
echo "INSTALANDO E CONFIGURANDO O KEA DHCP4..."
echo "====================================================="
sudo dnf -y update
sudo dnf -y install kea
sleep 2

echo "Fazendo backup do arquivo de configuração original"
sudo mv /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.org
sleep 2

echo "Criando o arquivo de configuração do Kea DHCP..."
sleep 2

# Cria nova configuração
echo "Criando nova configuração em $CONF_FILE..."
cat > "$CONF_FILE" << 'EOF'
{
"Dhcp4": {
    "interfaces-config": {
        "interfaces": [ "$IFACE" ]
    },
    "expired-leases-processing": {
        "reclaim-timer-wait-time": 10,
        "flush-reclaimed-timer-wait-time": 25,
        "hold-reclaimed-time": 3600,
        "max-reclaim-leases": 100,
        "max-reclaim-time": 250,
        "unwarned-reclaim-cycles": 5
    },
    
    "renew-timer": 900,
    
    "rebind-timer": 1800,
    
    "valid-lifetime": 3600,
    "option-data": [
        {
            "name": "domain-name-servers",
            "data": "192.168.10.20"
        },
        {
            "name": "domain-name",
            "data": "empresa.local"
        },
        {
            "name": "domain-search",
            "data": "empresa.local"
        }
    ],
    "subnet4": [
        {
            "id": 1,
            "subnet": "192.168.10.0/24",
            "pools": [ { "pool": "192.168.10.100 - 192.168.10.200" } ],
            "option-data": [
                {
                    "name": "routers",
                    "data": "192.168.10.1"
                }
            ]
        }
    ],
    "loggers": [
    {
        "name": "kea-dhcp4",
        "output-options": [
            {
                "output": "/var/log/kea/kea-dhcp4.log"
            }
        ],
        "severity": "INFO",
        "debuglevel": 0
    }
    ]
}
}
EOF

# Alterar o proprietário e as permissões
chown root:kea /etc/kea/kea-dhcp4.conf
chmod 640 /etc/kea/kea-dhcp4.conf

# Habilitar e iniciar o serviço Kea DHCP4
systemctl enable --now kea-dhcp4

# Se o Firewalld estiver em execução, permitir o serviço DHCP (porta 67/UDP)
firewall-cmd --add-service=dhcp
firewall-cmd --runtime-to-permanent

# Verificar os arquivos de leases IPv4 no diretório /var/lib/kea
echo "Verificando os arquivos de leases no diretório /var/lib/kea:"
sudo ls -l /var/lib/kea

echo "Conteúdo do arquivo /var/lib/kea/kea-leases4.csv:"
cat /var/lib/kea/kea-leases4.csv

