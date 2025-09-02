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
    DOCKER_HOST_IP = '172.31.44.202'      // Docker host private IP
    REPO           = 'mytestimage/myapp'  // Docker Hub repo
    APP_NAME       = 'myapp'
    IMAGE_TAG      = "${env.BUILD_NUMBER}"

    SSH_CRED_ID    = 'docker-ssh-key'     // Jenkins SSH key for Docker host
    REG_CRED_ID    = 'dockerhub-creds'    // Jenkins Docker Hub creds
  }

  stages {
    stage('Checkout') {
      agent { label 'agent1' }
      steps {
        git url: 'https://github.com/theitern/ClassDemoProject.git', branch: 'main'
        stash name: 'source', includes: '**/*'
      }
    }

    stage('Compile') {
      agent { label 'agent1' }
      steps {
        unstash 'source'
        sh 'mvn -B compile'
        stash name: 'compiled', includes: '**/*'
      }
    }

    stage('CodeReview') {
      agent { label 'agent1' }
      steps {
        unstash 'compiled'
        sh 'mvn -B pmd:pmd'
      }
    }

    stage('UnitTest') {
      agent { label 'agent2' }
      steps {
        unstash 'compiled'
        sh 'mvn -B test'
      }
      post {
        success {
          junit '**/target/surefire-reports/*.xml'
        }
      }
    }

    stage('Package (WAR)') {
      agent { label 'built-in' }
      steps {
        unstash 'compiled'
        sh 'mvn -B -DskipTests package'
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
            WAR_PATH="$(find . -type f -path "*/target/webapp.war" -print | head -n1)"
            if [ -z "$WAR_PATH" ]; then
              echo "❌ No webapp.war found"
              exit 1
            fi
            echo "Found WAR: $WAR_PATH"

            scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              "$WAR_PATH" ubuntu@${DOCKER_HOST_IP}:~/webapp.war

            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} '
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
      echo "✅ WAR deployed as Docker container ${APP_NAME}"
      echo "🌐 Access: http://${DOCKER_HOST_IP}:8080/"
    }
  }
}
