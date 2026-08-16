#!/bin/bash
set -e

# Variables
PROMETHEUS_VERSION="2.53.0"
GRAFANA_VERSION="11.1.0"
CLOUDWATCH_EXPORTER_VERSION="0.16.0"

# Update system
dnf update -y

# Install dependencies
dnf install -y wget tar java-17-amazon-corretto

# ---- Install Prometheus ----
useradd --no-create-home --shell /bin/false prometheus

mkdir -p /etc/prometheus /var/lib/prometheus

wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /etc/prometheus
cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus

chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Prometheus config
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "cloudwatch-ecs"
    static_configs:
      - targets: ["localhost:9106"]
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Prometheus systemd service
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
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# ---- Install Grafana ----
cat > /etc/yum.repos.d/grafana.repo << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

dnf install -y grafana

systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# ---- Install CloudWatch Exporter ----
mkdir -p /opt/cloudwatch_exporter

wget -O /opt/cloudwatch_exporter/cloudwatch_exporter.jar \
  https://github.com/prometheus/cloudwatch_exporter/releases/download/v${CLOUDWATCH_EXPORTER_VERSION}/cloudwatch_exporter-${CLOUDWATCH_EXPORTER_VERSION}-jar-with-dependencies.jar

mkdir -p /etc/cloudwatch_exporter

cat > /etc/cloudwatch_exporter/config.yml << 'EOF'
region: us-east-1
metrics:
  - aws_namespace: AWS/ECS
    aws_metric_name: CPUUtilization
    aws_dimensions: [ClusterName, ServiceName]
    aws_statistics: [Average]
    aws_dimension_select:
      ClusterName: [tomato-cluster]

  - aws_namespace: AWS/ECS
    aws_metric_name: MemoryUtilization
    aws_dimensions: [ClusterName, ServiceName]
    aws_statistics: [Average]
    aws_dimension_select:
      ClusterName: [tomato-cluster]

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: RequestCount
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]

  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: HTTPCode_Target_5XX_Count
    aws_dimensions: [LoadBalancer]
    aws_statistics: [Sum]
EOF

# CloudWatch Exporter systemd service
cat > /etc/systemd/system/cloudwatch_exporter.service << 'EOF'
[Unit]
Description=CloudWatch Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=ec2-user
ExecStart=/usr/bin/java -jar /opt/cloudwatch_exporter/cloudwatch_exporter.jar 9106 /etc/cloudwatch_exporter/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudwatch_exporter
systemctl start cloudwatch_exporter

echo "Prometheus running on port 9090"
echo "Grafana running on port 3000 (admin/admin)"
echo "CloudWatch Exporter running on port 9106"
