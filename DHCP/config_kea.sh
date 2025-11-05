#!/bin/bash

# Atualizar o sistema
echo "Atualizando o sistema..."
sudo dnf -y update

# Instalar o Kea DHCP
echo "Instalando o Kea DHCP..."
sudo dnf -y install kea

# Verificar a instalação
echo "Verificando a instalação do Kea DHCP..."
if ! command -v keactrl &> /dev/null
then
    echo "Kea DHCP não foi instalado corretamente. Abortando."
    exit 1
fi

# Backup do arquivo de configuração original (caso já exista)
echo "Fazendo backup do arquivo de configuração original (se existir)..."
sudo mv /etc/kea/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf.org

# Criar o arquivo de configuração do Kea DHCP
echo "Criando o arquivo de configuração do Kea DHCP..."

sudo cat > /etc/kea/kea-dhcp4.conf <<EOL
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": [ "ens33" ]
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
        "data": "192.168.10.10"
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
EOL

# Alterar permissões e propriedade do arquivo de configuração
echo "Alterando permissões e propriedade do arquivo de configuração..."
chown root:kea /etc/kea/kea-dhcp4.conf
chmod 640 /etc/kea/kea-dhcp4.conf

# Criar diretório de logs (se não existir)
echo "Criando diretório de logs..."
mkdir -p /var/log/kea
chown kea:kea /var/log/kea

# Habilitar e iniciar o serviço do Kea DHCP
echo "Habilitando e iniciando o serviço Kea DHCP..."
systemctl enable --now kea-dhcp4

# Verificar o status do serviço
echo "Verificando o status do Kea DHCP..."
systemctl status kea-dhcp4 | grep "Active"

# Finalização
echo "Configuração do Kea DHCP concluída. O serviço está rodando."

# Mostrar os logs para verificar se tudo está funcionando
echo "Exibindo as últimas linhas dos logs do Kea..."
tail -n 20 /var/log/kea/kea-dhcp4.log
