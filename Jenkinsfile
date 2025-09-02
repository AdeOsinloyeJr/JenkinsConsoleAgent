pipeline {
  tools {
    jdk 'myjava'
    maven 'mymaven'
  }

  agent any   // 👈 everything runs on Jenkins itself

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  triggers {
    pollSCM('H/2 * * * *')   // poll GitHub every 2 minutes
  }

  environment {
    DOCKER_HOST_IP = '172.31.44.202'      // Docker EC2 private IP
    REPO           = 'mytestimage/myapp'  // Docker Hub repo
    APP_NAME       = 'myapp'
    IMAGE_TAG      = "${env.BUILD_NUMBER}"

    SSH_CRED_ID    = 'docker-ssh-key'     // Jenkins SSH key for Docker host
    REG_CRED_ID    = 'dockerhub-creds'    // Jenkins Docker Hub creds
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/AdeOsinloyeJr/JenkinsConsoleAgent', branch: 'main'
      }
    }

    stage('Build WAR') {
      steps {
        sh '''
          set -euo pipefail
          echo "📦 Building WAR with Maven..."
          mvn -B clean package -DskipTests

          WAR_PATH=$(find . -type f -path "*/target/webapp.war" | head -n1 || true)
          if [ -z "$WAR_PATH" ]; then
            echo "❌ ERROR: No webapp.war found after build"
            exit 1
          fi
          echo "✅ Found WAR at $WAR_PATH"
        '''
        archiveArtifacts artifacts: '**/target/*.war', fingerprint: true
      }
    }

    stage('Copy WAR to Docker host') {
      steps {
        sshagent(credentials: [env.SSH_CRED_ID]) {
          sh '''
            set -euo pipefail
            WAR_PATH=$(find . -type f -path "*/target/webapp.war" | head -n1 || true)
            if [ -z "$WAR_PATH" ]; then
              echo "❌ ERROR: WAR not found in workspace"
              exit 1
            fi

            echo "📤 Copying WAR to Docker host..."
            scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              "$WAR_PATH" ubuntu@${DOCKER_HOST_IP}:~/webapp.war || {
                echo "❌ ERROR: SCP failed"
                exit 1
            }

            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} '
              set -e
              if [ ! -f ~/webapp.war ]; then
                echo "❌ ERROR: WAR missing on Docker host"
                exit 1
              fi
              echo "✅ WAR is on Docker host:"
              ls -lh ~/webapp.war
            '
          '''
        }
      }
    }

    stage('Build & Push Docker Image') {
      steps {
        withCredentials([usernamePassword(credentialsId: env.REG_CRED_ID, usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sshagent(credentials: [env.SSH_CRED_ID]) {
            sh '''
              ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} '
                set -e
                cd "$HOME"

                if [ ! -f webapp.war ]; then
                  echo "❌ ERROR: webapp.war missing on remote"
                  exit 1
                fi

                cat > Dockerfile <<EOF
FROM tomcat:9.0-jdk21-temurin
COPY webapp.war /usr/local/tomcat/webapps/ROOT.war
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

    stage('Deploy Container') {
      steps {
        sshagent(credentials: [env.SSH_CRED_ID]) {
          sh '''
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
    success {
      echo "✅ SUCCESS: ${APP_NAME} deployed to Docker host"
    }
    failure {
      echo "❌ FAILURE: Pipeline stopped due to error"
    }
  }
}
