stage('Copy WAR to Docker host') {
  agent { label 'built-in' }
  steps {
    echo 'Copying WAR to Docker host...'
    unstash 'packaged'
    sshagent(credentials: [env.SSH_CRED_ID]) {
      sh '''
        set -euo pipefail
        echo "== Locate WAR in workspace =="
        WAR_PATH="$(find . -type f -path "*/target/webapp.war" -print | head -n1)"
        if [ -z "$WAR_PATH" ]; then
          echo "❌ No webapp.war found"
          find . -maxdepth 4 -type f -name "*.war" | sed 's/^/  /'
          exit 1
        fi
        echo "WAR_PATH=$WAR_PATH"

        echo "== SCP WAR -> remote home dir =="
        scp -v -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          "$WAR_PATH" ubuntu@${DOCKER_HOST_IP}:~/webapp.war

        echo "== Verify on remote =="
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${DOCKER_HOST_IP} '
          ls -lh ~/webapp.war
          file ~/webapp.war || true
        '
      '''
    }
  }
}
