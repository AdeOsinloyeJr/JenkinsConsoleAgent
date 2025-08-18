#!/usr/bin/env bash
# agent setup (no Jenkins, just Java + Maven + SSH)
# 📝 Paste the agent script here

#!/usr/bin/env bash
set -e

# Run non-interactive everywhere
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

## 1) Update base tools
sudo -E apt-get update -y
sudo -E apt-get install -y curl wget git unzip gnupg apt-transport-https ca-certificates software-properties-common

## 2) Install Java 8 (OpenJDK)
sudo -E apt-get install -y openjdk-8-jdk

## 3) Set JAVA_HOME (for consistency)
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee -a /etc/profile.d/java.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/java.sh
sudo chmod +x /etc/profile.d/java.sh
source /etc/profile.d/java.sh

## 4) Install Maven (from Ubuntu repo)
sudo -E apt-get install -y maven

## 5) Make Maven use Java 8 by default (system-wide)
sudo tee /etc/profile.d/maven.sh >/dev/null <<'EOF'
export M2_HOME=/usr/share/maven
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$M2_HOME/bin:$JAVA_HOME/bin:$PATH
EOF
sudo chmod 644 /etc/profile.d/maven.sh

## 6) Show versions for verification
source /etc/profile.d/maven.sh
java -version
mvn -v

## 7) Create your workspace directory
sudo mkdir -p /tmp/jenkinsdir
sudo chmod -R 777 /tmp/jenkinsdir
cd /tmp
