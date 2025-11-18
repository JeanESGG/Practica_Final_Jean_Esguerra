#!/bin/bash

echo "=========================================="
echo "PROVISION DEL SERVIDOR"
echo "=========================================="

# ============================================
# 1. ACTUALIZACIÓN DEL SISTEMA
# ============================================
echo "→ Actualizando sistema..."
apt-get update
apt-get upgrade -y

# ============================================
# 2. INSTALACIÓN DE DOCKER Y DOCKER COMPOSE
# ============================================
echo "→ Instalando Docker..."
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Agregar usuario vagrant al grupo docker (para usar docker sin sudo)
usermod -aG docker vagrant

echo "✓ Docker instalado correctamente"
echo "  Nota: Los contenedores NO se han iniciado automáticamente"
echo "  Para iniciarlos: cd /home/vagrant && docker compose up -d --build"

# ============================================
# 3. INSTALACIÓN DE PROMETHEUS
# ============================================
echo "→ Instalando Prometheus..."
useradd --no-create-home --shell /bin/false prometheus
mkdir -p /etc/prometheus /var/lib/prometheus

cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
tar -xvf prometheus-2.47.0.linux-amd64.tar.gz
cd prometheus-2.47.0.linux-amd64

cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/
cp -r consoles /etc/prometheus
cp -r console_libraries /etc/prometheus

chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus

cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  - "rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Flask vía Nginx (con HTTPS)
  - job_name: 'webapp_public'
    static_configs:
      - targets: ['localhost:443']
        labels:
          app: 'flask_webapp'
          tier: 'frontend'
    metrics_path: '/metrics'
    scheme: https
    tls_config:
      insecure_skip_verify: true

  - job_name: 'mysql'
    static_configs:
      - targets: ['localhost:9104']
        labels:
          service: 'mysql'

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          service: 'system'
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Configurar reglas de alertas
cat > /etc/prometheus/rules.yml << 'EOF'
groups:
  - name: infrastructure_alerts
    interval: 30s
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instancia {{ $labels.instance }} caída"
          description: "La instancia {{ $labels.instance }} del job {{ $labels.job }} ha estado caída por más de 1 minuto."
      
      - alert: WebAppDown
        expr: up{job=~"webapp.*"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Aplicación Web caída"
          description: "La aplicación Flask no responde desde hace más de 1 minuto."

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de CPU en {{ $labels.instance }}"
          description: "El uso de CPU está por encima del 80%."

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de memoria en {{ $labels.instance }}"
          description: "El uso de memoria está por encima del 85%."
EOF

chown prometheus:prometheus /etc/prometheus/rules.yml

cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

# ============================================
# 4. INSTALACIÓN DE GRAFANA
# ============================================
echo "→ Instalando Grafana..."
apt-get install -y adduser libfontconfig1

cd /tmp
wget https://dl.grafana.com/oss/release/grafana_10.4.2_amd64.deb
dpkg -i grafana_10.4.2_amd64.deb
apt-get install -f -y

systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# ============================================
# 5. INSTALACIÓN DE MYSQL EXPORTER
# ============================================
echo "→ Instalando MySQL Exporter..."
useradd --no-create-home --shell /bin/false mysqld_exporter

cd /tmp
wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.0/mysqld_exporter-0.15.0.linux-amd64.tar.gz
tar -xvf mysqld_exporter-0.15.0.linux-amd64.tar.gz
cp mysqld_exporter-0.15.0.linux-amd64/mysqld_exporter /usr/local/bin/
chown mysqld_exporter:mysqld_exporter /usr/local/bin/mysqld_exporter

cat > /etc/.mysqld_exporter.cnf << 'EOF'
[client]
user=exporter
password=exporter_password
host=127.0.0.1
port=3306
EOF

chown mysqld_exporter:mysqld_exporter /etc/.mysqld_exporter.cnf
chmod 600 /etc/.mysqld_exporter.cnf

cat > /etc/systemd/system/mysqld_exporter.service << 'EOF'
[Unit]
Description=MySQL Exporter
After=network.target

[Service]
User=mysqld_exporter
Group=mysqld_exporter
Type=simple
ExecStart=/usr/local/bin/mysqld_exporter \
    --config.my-cnf=/etc/.mysqld_exporter.cnf \
    --collect.global_status \
    --collect.info_schema.innodb_metrics \
    --collect.info_schema.processlist

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mysqld_exporter
# NO iniciamos mysqld_exporter porque MySQL aún no está corriendo
echo "  Nota: MySQL Exporter configurado pero NO iniciado (esperando MySQL)"

# ============================================
# 6. INSTALACIÓN DE NODE EXPORTER
# ============================================
echo "→ Instalando Node Exporter..."
useradd --no-create-home --shell /bin/false node_exporter

cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# ============================================
# 7. CONFIGURAR DATASOURCE EN GRAFANA
# ============================================
echo "→ Configurando Grafana..."
sleep 20

curl -X POST -H "Content-Type: application/json" -d '{
  "name": "Prometheus",
  "type": "prometheus",
  "access": "proxy",
  "url": "http://localhost:9090",
  "isDefault": true
}' http://admin:admin@localhost:3000/api/datasources 2>/dev/null

# ============================================
# VERIFICACIÓN FINAL
# ============================================
echo ""
echo "=========================================="
echo " VERIFICANDO SERVICIOS"
echo "=========================================="

systemctl is-active --quiet docker && echo "✓ Docker: INSTALADO Y ACTIVO" || echo "✗ Docker: INACTIVO"
systemctl is-active --quiet prometheus && echo "✓ Prometheus: ACTIVO" || echo "✗ Prometheus: INACTIVO"
systemctl is-active --quiet grafana-server && echo "✓ Grafana: ACTIVO" || echo "✗ Grafana: INACTIVO"
systemctl is-active --quiet node_exporter && echo "✓ Node Exporter: ACTIVO" || echo "✗ Node Exporter: INACTIVO"
echo "⏸  MySQL Exporter: CONFIGURADO (iniciar después de MySQL)"

echo ""
echo "=========================================="
echo " PROVISION COMPLETADO"
echo "=========================================="
echo ""
echo "   ACCESO A SERVICIOS:"
echo "   Aplicación (después de iniciar Docker):"
echo "   → https://192.168.50.3"
echo ""
echo "   Monitoreo (YA disponibles):"
echo "   → Prometheus: http://192.168.50.3:9090"
echo "   → Grafana:    http://192.168.50.3:3000 (admin/admin)"
echo ""
echo "   INICIAR MYSQL EXPORTER (después de Docker):"
echo "   $ vagrant ssh"
echo "   $ sudo systemctl start mysqld_exporter"
echo "   $ sudo systemctl status mysqld_exporter"
echo ""
echo "=========================================="