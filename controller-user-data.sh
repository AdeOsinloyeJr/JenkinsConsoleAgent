#!/usr/bin/env bash
# controller setup (Jenkins, Maven, Java)
# 📝 Paste the full controller script content below

#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# === Base Packages ===
apt-get update -y
apt-get install -y curl wget ca-certificates gnupg apt-transport-https git tar

# === Java ===
apt-get install -y openjdk-21-jdk || apt-get install -y openjdk-21-jre || apt-get install -y openjdk-17-jdk
apt-get install -y openjdk-8-jdk || true

# === Maven ===
apt-get install -y maven

# === Maven + Java 8 Default for Login Shells ===
tee /etc/profile.d/maven.sh >/dev/null <<'EOF'
export M2_HOME=/usr/share/maven
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export PATH=$M2_HOME/bin:$JAVA_HOME/bin:$PATH
EOF
chmod 644 /etc/profile.d/maven.sh

# === Jenkins Install ===
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
  -o /usr/share/keyrings/jenkins-keyring.asc

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update -y
apt-get install -y jenkins

# === Force Jenkins to Use Java 21 ===
if [ -x /usr/lib/jvm/java-21-openjdk-amd64/bin/java ]; then
  sed -i 's|^JAVA=.*|JAVA=/usr/lib/jvm/java-21-openjdk-amd64/bin/java|' /etc/default/jenkins || true
fi

# === Enable Jenkins ===
systemctl enable jenkins
systemctl restart jenkins || true

# === Print Java & Maven Versions ===
source /etc/profile.d/maven.sh
echo "JAVA_HOME=$JAVA_HOME"
java -version || true
mvn -v || true

# === Final Hint ===
echo "Jenkins initial admin password is in: /var/lib/jenkins/secrets/initialAdminPassword"
