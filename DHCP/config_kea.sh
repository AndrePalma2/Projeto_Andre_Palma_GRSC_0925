#!/bin/bash

set -e

echo "Atualizando o sistema..."
sudo dnf -y update


echo "Instalando o Kea DHCP..."
sudo dnf -y install kea


echo "Fazendo backup do arquivo de configuração original
sudo mv /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.org


echo "Criando o arquivo de configuração do Kea DHCP..."


CONF_FILE="/etc/kea/kea-dhcp4.conf"
LOG_DIR="/var/log/kea"


# Cria nova configuração
echo "[INFO] Criando nova configuração em $CONF_FILE..."
cat > "$CONF_FILE" << 'EOF'
// create new
{
"Dhcp4": {
    "interfaces-config": {
        // specify network interfaces to listen on
        "interfaces": [ "enp1s0" ]
    },
    // settings for expired-leases (follows are default)
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
            // specify your DNS server
            "name": "domain-name-servers",
            "data": "10.0.0.10"
        },
        {
            "name": "domain-name",
            "data": "srv.world"
        },
        {
            "name": "domain-search",
            "data": "srv.world"
        }
    ],
    "subnet4": [
        {
            "id": 1,
            "subnet": "10.0.0.0/24",
            "pools": [ { "pool": "10.0.0.200 - 10.0.0.254" } ],
            "option-data": [
                {
                    "name": "routers",
                    "data": "10.0.0.1"
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




