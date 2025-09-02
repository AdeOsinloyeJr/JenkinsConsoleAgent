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

  triggers {
    pollSCM('H/2 * * * *')
  }

  environment {
    DOCKER_HOST_IP = '172.31.44.202'
    REPO           = 'mytestimage/myapp'
    APP_NAME       = 'myapp'
    IMAGE_TAG      = "${env.BUILD_NUMBER}"

    SSH_CRED_ID    = 'docker-ssh-key'
    REG_CRED_ID    = 'dockerhub-creds'
  }

  stages {
    stage('Checkout') {
      agent { label 'agent1' }
      steps {
        git url: 'https://github.com/theitern/ClassDemoProject.git', branch: 'main'
        stash name: 'source', includes: '**/*'
      }
    }

    stage('Package (WAR)') {
      agent { label 'built-in' }
      steps {
        unstash 'source'
        sh '''
          set -euo pipefail
          echo "📦 Packaging WAR..."
          mvn -B clean package -DskipTests

          echo "🔍 Looking for WAR..."
          WAR_PATH=$(find . -type f -path "*/target/webapp.war" | head -n1 || true)

          if [ -z "$WAR_PATH" ]; then
            echo "❌ ERROR: No webapp.war found after build"
            exit 1
          fi

          echo "✅ Found WAR at $WAR_PATH"
        '''
        archiveArtifacts artifacts: '**/target/*.war', fingerprint: true
        stash name: 'artifact', includes: '**/target/*.war'
      }
    }

    stage('Copy WAR to Docker host') {
      agent { label 'built-in' }
      steps {
        unstash 'artifact'
        sshagent(credentials: [env.SSH_CRED_ID]) {
          sh '''
            set -euo pipefail
            WAR_PATH=$(find . -type f -path "*/target/webapp.war" | head -n1 || true)

            if [ -z "$WAR_PATH" ]; then
              echo "❌ ERROR: No WAR available to copy"
              exit 1
            fi

            echo "📤 Copying $WAR_PATH to Docker host..."
            scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              "$WAR_PATH" ubuntu@${DOCKER_HOST_IP}:~/webapp.war || {
                echo "❌ ERROR: SCP failed"
                exit 1
            }

            echo "🔍 Verifying on remote..."
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} '
              set -e
              if [ ! -f ~/webapp.war ]; then
                echo "❌ ERROR: webapp.war missing on remote"
                exit 1
              fi
              ls -lh ~/webapp.war
              file ~/webapp.war || true
            '
          '''
        }
      }
    }

    stage('Build & Push Docker image') {
      agent { label 'built-in' }
      steps {
        withCredentials([usernamePassword(credentialsId: env.REG_CRED_ID, usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sshagent(credentials: [env.SSH_CRED_ID]) {
            sh '''
              ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} '
                set -e
                cd "$HOME"

                if [ ! -f webapp.war ]; then
                  echo "❌ ERROR: webapp.war not found, aborting Docker build"
                  exit 1
                fi

                echo "📝 Writing Dockerfile..."
                cat > Dockerfile <<EOF
FROM tomcat:9.0-jdk21-temurin
COPY webapp.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
EOF

                echo "🐳 Building Docker image..."
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
    always {
      echo "✅ Pipeline finished. Image: ${REPO}:${IMAGE_TAG}"
    }
    failure {
      echo "❌ Pipeline FAILED — check logs above"
    }
  }
}
