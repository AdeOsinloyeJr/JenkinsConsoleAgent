pipeline {
  agent any
  options { timestamps() }

  environment {
    DOCKER_HOST_IP = '172.31.47.162'                 // your Docker host
    DOCKER_REPO    = 'your-dockerhub-user/webapp'    // e.g. adeosinloyejr/webapp
    IMAGE_TAG      = "build-${env.BUILD_NUMBER}"
  }

  stages {
    stage('Build WAR') {
      steps {
        sh '''
          set -e
          echo "📦 Building WAR with Maven..."
          mvn -B clean package -DskipTests
          WAR_PATH="$(find . -type f -path "*/target/webapp.war" | head -n1)"
          [ -n "$WAR_PATH" ] || { echo "❌ WAR not found"; exit 1; }
          echo "✅ Found WAR at $WAR_PATH"
        '''
        archiveArtifacts artifacts: 'webapp/target/webapp.war', fingerprint: true, onlyIfSuccessful: true
      }
    }

    stage('Copy WAR to Docker host') {
      steps {
        sshagent(credentials: ['ubuntu']) {
          sh '''
            set -e
            echo "📤 Copying WAR to Docker host..."
            scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              ./webapp/target/webapp.war "ubuntu@${DOCKER_HOST_IP}:~/webapp.war"

            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@${DOCKER_HOST_IP}" '
              set -e
              [ -f "$HOME/webapp.war" ] || { echo "❌ webapp.war missing on Docker host"; exit 1; }
              echo "✅ WAR is on Docker host:"
              ls -lh "$HOME/webapp.war"
            '
          '''
        }
      }
    }

    stage('Build & Push Docker Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sshagent(credentials: ['ubuntu']) {
            sh '''
              set -e
              ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@${DOCKER_HOST_IP}" bash -lc "
                set -e
                cd \$HOME

                echo '📝 Writing Dockerfile...'
                cat > Dockerfile <<'EOF'
FROM tomcat:9.0-jdk21-temurin
COPY webapp.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
EOF

                echo '${DOCKER_PASS}' | docker login -u '${DOCKER_USER}' --password-stdin
                docker build -t ${DOCKER_REPO}:${IMAGE_TAG} .
                docker tag ${DOCKER_REPO}:${IMAGE_TAG} ${DOCKER_REPO}:latest
                docker push ${DOCKER_REPO}:${IMAGE_TAG}
                docker push ${DOCKER_REPO}:latest
              "
            '''
          }
        }
      }
    }

    stage('Deploy Container') {
      steps {
        sshagent(credentials: ['ubuntu']) {
          sh '''
            set -e
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@${DOCKER_HOST_IP}" "
              set -e
              docker pull ${DOCKER_REPO}:${IMAGE_TAG} || true
              docker rm -f webapp || true
              docker run -d --name webapp -p 8080:8080 --restart unless-stopped ${DOCKER_REPO}:${IMAGE_TAG}
              echo '✅ Container running:'
              docker ps --filter name=webapp
            "
          '''
        }
      }
    }
  }

  post {
    failure { echo '❌ FAILURE: Pipeline stopped due to error' }
  }
}
