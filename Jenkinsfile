pipeline {
    agent any

    tools {
        // Use tools that are ACTUALLY configured in Jenkins (check Global Tool Config)
        jdk 'myjava'      // ✅ replace with your actual JDK name
        maven 'mymaven'    // ✅ replace with your actual Maven name
    }

    environment {
        JAVA_HOME = "${tool 'myjava'}"
        MAVEN_HOME = "${tool 'mymaven'}"
        PATH = "${env.JAVA_HOME}/bin:${env.MAVEN_HOME}/bin:${env.PATH}"
    }

    stages {
        stage('Compile the code') {
            steps {
                sh 'mvn compile'
            }
        }

        stage('Code Analysis') {
            steps {
                sh 'mvn pmd:pmd'
            }
        }

        stage('Code Coverage') {
            steps {
                sh 'mvn cobertura:cobertura -Dcobertura.report.format=xml'
            }
        }

        stage('Build the artifact') {
            steps {
                sh 'mvn package'
            }
        }
    }
}

