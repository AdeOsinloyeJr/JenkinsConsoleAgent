pipeline {
    agent any

    environment {
        DOCKER_HOST = "172.31.47.162"
        REPO = "adeosinloyejr/webapp"   // Replace with your Docker Hub repo
        IMAGE_TAG = "v${BUILD_NUMBER}"
    }

    stages {
        stage('Build WAR') {
            steps {
                sh '''
                    set -e
                    echo "📦 Building WAR with Maven..."
                    mvn -B clean package -DskipTests

                    WAR_PATH=$(find . -type f -path "*/target/webapp.war" | head -n1)
                    if [ -z "$WAR_PATH" ]; then
                      echo "❌ ERROR: WAR file not found!"
                      exit 1
                    fi

                    echo "✅ Found WAR at $WAR_PATH"
                '''
                archiveArtifacts artifacts: '**/target/webapp.war', fingerprint: true
            }
        }

        stage('Copy WAR to Docker host') {
            steps {
                sshagent(credentials: ['ubuntu']) {
                    sh '''
                        set -e
                        WAR_PATH=$(find . -type f -path "*/target/webapp.war" | head -n1)

                        echo "📤 Copying WAR to Docker host..."
                        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$WAR_PATH" ubuntu@${DOCKER_HOST}:~/webapp.war

                        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST} << 'EOF'
                        #!/bin/bash
                        set -e
                        if [ ! -f ~/webapp.war ]; then
                          echo "❌ ERROR: webapp.war missing on Docker host"
                          exit 1
                        fi
                        echo "✅ WAR is on Docker host:"
                        ls -lh ~/webapp.war
                        EOF
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
                            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST} << EOF
                            #!/bin/bash
                            set -e
                            cd "\$HOME"

                            if [ ! -f webapp.war ]; then
                              echo "❌ ERROR: webapp.war missing on remote"
                              exit 1
                            fi

                            echo "📝 Writing Dockerfile..."
                            cat > Dockerfile <<EOT
                            FROM tomcat:9.0-jdk21-temurin
                            COPY webapp.war /usr/local/tomcat/webapps/ROOT.war
                            EXPOSE 8080
                            EOT

                            echo "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
                            docker build -t ${REPO}:${IMAGE_TAG} .
                            docker tag ${REPO}:${IMAGE_TAG} ${REPO}:latest
                            docker push ${REPO}:${IMAGE_TAG}
                            docker push ${REPO}:latest
                            EOF
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
                        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST} << EOF
                        #!/bin/bash
                        set -e
                        echo "🚀 Stopping old container (if any)..."
                        docker rm -f webapp || true

                        echo "🚀 Starting new container..."
                        docker run -d --name webapp -p 8080:8080 ${REPO}:${IMAGE_TAG}
                        EOF
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ SUCCESS: Build, push, and deploy completed."
        }
        failure {
            echo "❌ FAILURE: Pipeline stopped due to error"
        }
    }
}
