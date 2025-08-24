pipeline {
    tools {
        jdk 'myjava'
        maven 'mymaven'
    }
    
    agent none
    
    stages {
        stage('Checkout') {
            agent {
                label 'agent1'
            }
            steps {
                echo 'Cloning...'
                git 'https://github.com/theitern/ClassDemoProject.git'
            }
        }
        
        stage('Compile') {
            agent {
                label 'agent1'
            }
            steps {
                echo 'Compiling...'
                sh 'mvn compile'
            }
        }
        
        stage('CodeReview') {
            agent {
                label 'agent1'
            }
            steps {
                echo 'Code Review...'
                sh 'mvn pmd:pmd'
            }
        }
        
        stage('UnitTest') {
            agent {
                label 'agent2'
            }
            steps {
                echo 'Testing...'
                // Re-clone source since we're on a different agent
                git 'https://github.com/theitern/ClassDemoProject.git'
                sh 'mvn test'
            }
            post {
                success {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Package') {
            agent {
                label 'built-in'
            }
            steps {
                echo 'Packaging...'
                // Re-clone source since we're on the controller
                git 'https://github.com/theitern/ClassDemoProject.git'
                sh 'mvn package'
            }
        }
    }
}