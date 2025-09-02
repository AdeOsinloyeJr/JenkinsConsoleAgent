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

  // 🔔 Cron-based trigger (polls repo every 2 minutes)
  triggers {
    pollSCM('H/2 * * * *')
  }

  environment {
    DOCKER_HOST_IP = '172.31.44.202'       // 👈 your Docker host PRIVATE IP
    REPO           = 'mytestimage/myapp'   // 👈 your Docker Hub repo
    APP_NAME       = 'myapp'
    IMAGE_TAG      = "${env.BUILD_NUMBER}"

    SSH_CRED_ID    = 'docker-ssh-key'      // 👈 ID of SSH key credential you created
    REG_CRED_ID    = 'dockerhub-creds'     // 👈 ID of Docker Hub creds you created
  }

  stages {
    stage('Checkout') {
      agent { label 'agent1' }
      steps {
        echo 'Cloning source code...'
        git url: 'https://github.com/AdeOsinloyeJr/JenkinsConsoleAgent', branch: 'main'
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
        echo 'Running code review...'
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
          junit 'target/surefire-reports/*.xml'
        }
      }
    }

    stage('Package') {
      agent { label 'built-in' }
      steps {
        echo 'Packaging application...'
        unstash 'compiled'
        sh 'mvn -B -DskipTests package'
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
        stash name: 'artifact', includes: 'target/*.jar'
      }
    }

   stage('Copy artifact to Docker host') {
  agent { label 'built-in' }
  steps {
    echo 'Copying JAR to Docker host...'
    unstash 'artifact' // ensure target/*.jar exists on this node
    sshagent(credentials: [env.SSH_CRED_ID]) {
      sh '''
        set -e
        # show home on remote for sanity
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} 'echo REMOTE_HOME=$HOME && hostname'
        # copy jar directly to home
        scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          target/*.jar ubuntu@${DOCKER_HOST_IP}:~/app.jar
        # verify
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} 'ls -lh ~/app.jar'
      '''
    }
  }
}


    stage('Build & Push Docker image on Docker host') {
      agent { label 'built-in' }
      steps {
        echo 'Building and pushing Docker image on remote host...'
        withCredentials([usernamePassword(credentialsId: env.REG_CRED_ID, usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sshagent(credentials: [env.SSH_CRED_ID]) {
            sh '''
              ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} "
                set -e
                cat > Dockerfile <<EOF
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY app.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT [\\"java\\",\\"-jar\\",\\"/app/app.jar\\"]
EOF
                echo \\"${PASS}\\" | docker login -u \\"${USER}\\" --password-stdin
                docker build -t ${REPO}:${IMAGE_TAG} .
                docker tag ${REPO}:${IMAGE_TAG} ${REPO}:latest
                docker push ${REPO}:${IMAGE_TAG}
                docker push ${REPO}:latest
              "
            '''
          }
        }
      }
    }

    stage('Deploy container') {
      agent { label 'built-in' }
      steps {
        echo 'Deploying container on Docker host...'
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
      echo "✅ Pipeline complete: Image ${REPO}:${IMAGE_TAG} deployed as ${APP_NAME}."
    }
  }
}
