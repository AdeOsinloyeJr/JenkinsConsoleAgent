pipeline {
  tools {
    jdk 'myjava'
    maven 'mymaven'
  }

  agent none

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  // Poll SCM (no inbound webhooks)
  triggers {
    pollSCM('H/2 * * * *')
  }

  environment {
    DOCKER_HOST_IP = '172.31.44.202'      // your Docker host PRIVATE IP
    REPO           = 'mytestimage/myapp'  // your Docker Hub repo
    APP_NAME       = 'myapp'
    IMAGE_TAG      = "${env.BUILD_NUMBER}"

    SSH_CRED_ID    = 'docker-ssh-key'     // SSH Username with private key (ubuntu)
    REG_CRED_ID    = 'dockerhub-creds'    // Docker Hub username/password
  }

  stages {
    stage('Checkout') {
      agent { label 'agent1' }
      steps {
        echo 'Cloning source...'
        git url: 'https://github.com/theitern/ClassDemoProject.git', branch: 'main'
        stash name: 'source', includes: '**/*'
      }
    }

    stage('Compile') {
      agent { label 'agent1' }
      steps {
        echo 'Compiling...'
        unstash 'source'
        sh 'mvn -B compile'
        stash name: 'compiled', includes: '**/*'
      }
    }

    stage('CodeReview') {
      agent { label 'agent1' }
      steps {
        echo 'Running PMD...'
        unstash 'compiled'
        sh 'mvn -B pmd:pmd'
      }
    }

    stage('UnitTest') {
      agent { label 'agent2' }
      steps {
        echo 'Running unit tests...'
        unstash 'compiled'
        sh 'mvn -B test'
      }
      post {
        success {
          // For multi-module, configure Freestyle JUnit as **/target/surefire-reports/*.xml
          junit 'target/surefire-reports/*.xml'
        }
      }
    }

    stage('Package (WAR)') {
      agent { label 'built-in' }
      steps {
        echo 'Packaging WAR...'
        unstash 'compiled'
        sh 'mvn -B -DskipTests package'
        // Archive any WARs (multi-module safe)
        archiveArtifacts artifacts: '**/target/*.war', fingerprint: true
        // Stash entire workspace so we can locate the WAR on this node
        stash name: 'packaged', includes: '**/*'
      }
    }

    stage('Copy WAR to Docker host') {
      agent { label 'built-in' }
      steps {
        echo 'Copying WAR to Docker host...'
        unstash 'packaged'
        sshagent(credentials: [env.SSH_CRED_ID]) {
          sh '''
            set -euo pipefail
            echo "== Locate WAR in workspace =="
            WAR_PATH="$(find . -type f -path "*/target/*.war" -print | head -n1)"
            if [ -z "$WAR_PATH" ]; then
              echo "❌ No WAR found under */target/*.war"
              find . -maxdepth 4 -type f | sed 's/^/  /'
              exit 1
            fi
            echo "WAR_PATH=$WAR_PATH"

            echo "== Remote sanity =="
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              ubuntu@${DOCKER_HOST_IP} 'echo REMOTE: $(whoami) home=$HOME host=$(hostname) && mkdir -p "$HOME"'

            echo "== SCP WAR -> ~/app.war =="
            scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              "$WAR_PATH" ubuntu@${DOCKER_HOST_IP}:~/app.war

            echo "== Verify on remote =="
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} '
              set -e
              ls -lh ~/app.war
              file ~/app.war || true
            '
          '''
        }
      }
    }

    stage('Build & Push Docker image on Docker host (Tomcat)') {
      agent { label 'built-in' }
      steps {
        echo 'Building & pushing image using Tomcat base...'
        withCredentials([usernamePassword(credentialsId: env.REG_CRED_ID, usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sshagent(credentials: [env.SSH_CRED_ID]) {
            sh '''
              set -e
              ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} '
                set -e
                cd "$HOME"

                # Use Tomcat 9 with JDK21 (safer for classic WARs)
                cat > Dockerfile <<EOF
FROM tomcat:9.0-jdk21-temurin
# Deploy as ROOT.war so app is on /
COPY app.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
EOF

                echo "${PASS}" | docker login -u "${USER}" --password-stdin
                docker build -t ${REPO}:${IMAGE_TAG} .
                docker tag ${REPO}:${IMAGE_TAG} ${REPO}:latest
                docker push ${REPO}:${IMAGE_TAG}
                docker push ${REPO}:latest
              '
            '''
          }
        }
      }
    }

    stage('Deploy container') {
      agent { label 'built-in' }
      steps {
        echo 'Deploying container...'
        sshagent(credentials: [env.SSH_CRED_ID]) {
          sh '''
            set -e
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} "
              set -e
              docker rm -f ${APP_NAME} || true
              docker pull ${REPO}:${IMAGE_TAG} || docker pull ${REPO}:latest
              docker run -d --name ${APP_NAME} -p 8080:8080 ${REPO}:${IMAGE_TAG}
            "
          '''
        }
      }
    }
  }

  post {
    always {
      echo "✅ Deployed ${REPO}:${IMAGE_TAG} (WAR) as ${APP_NAME} on ${DOCKER_HOST_IP}"
      echo "🔎 Access: http://<docker-host-public-or-private-ip>:8080/"
    }
  }
}
