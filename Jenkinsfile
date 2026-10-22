pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        DOCKER_IMAGE = 'balaji00002/traffic-management-dashboard'
        IMAGE_TAG = "build-${BUILD_NUMBER}"
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
        DEPLOYMENT_NAME = 'traffic-dashboard'
        CONTAINER_NAME = 'traffic-app'
        K8S_NAMESPACE = 'default'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                bat 'git --version'
            }
        }

        stage('Validate Files') {
            steps {
                bat '''
                    if not exist index.html exit /b 1
                    if not exist Dockerfile exit /b 1
                    if not exist deployment.yaml exit /b 1
                    if not exist Jenkinsfile exit /b 1
                    echo Required application files found.
                '''
            }
        }

        stage('Check Tools') {
            steps {
                bat '''
                    docker --version
                    kubectl version --client
                    kubectl get nodes
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                bat 'docker build -t %DOCKER_IMAGE%:%IMAGE_TAG% -t %DOCKER_IMAGE%:latest .'
            }
        }

        stage('Smoke Test Image') {
            steps {
                bat 'docker run --rm %DOCKER_IMAGE%:%IMAGE_TAG% nginx -t'
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDENTIALS_ID}",
                    usernameVariable: 'DOCKERHUB_USER',
                    passwordVariable: 'DOCKERHUB_TOKEN'
                )]) {
                    bat '''
                        @echo off
                        echo %DOCKERHUB_TOKEN% | docker login -u %DOCKERHUB_USER% --password-stdin
                        if errorlevel 1 exit /b 1
                        docker push %DOCKER_IMAGE%:%IMAGE_TAG%
                        if errorlevel 1 exit /b 1
                        docker push %DOCKER_IMAGE%:latest
                        if errorlevel 1 exit /b 1
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    try {
                        bat '''
                            kubectl apply -f deployment.yaml
                            if errorlevel 1 exit /b 1

                            kubectl set image deployment/%DEPLOYMENT_NAME% %CONTAINER_NAME%=%DOCKER_IMAGE%:%IMAGE_TAG% -n %K8S_NAMESPACE%
                            if errorlevel 1 exit /b 1

                            kubectl rollout status deployment/%DEPLOYMENT_NAME% -n %K8S_NAMESPACE% --timeout=120s
                            if errorlevel 1 exit /b 1
                        '''
                    } catch (err) {
                        echo 'Deployment failed. Attempting rollback to the previous Kubernetes revision.'
                        bat '''
                            kubectl rollout undo deployment/%DEPLOYMENT_NAME% -n %K8S_NAMESPACE%
                            kubectl rollout status deployment/%DEPLOYMENT_NAME% -n %K8S_NAMESPACE% --timeout=120s
                        '''
                        throw err
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                bat '''
                    kubectl get deployment %DEPLOYMENT_NAME% -n %K8S_NAMESPACE%
                    kubectl get pods -n %K8S_NAMESPACE% -l app=traffic-dashboard
                    kubectl get service traffic-dashboard-service -n %K8S_NAMESPACE%
                '''
            }
        }
    }

    post {
        always {
            bat 'docker image ls %DOCKER_IMAGE%'
        }
        success {
            echo 'Traffic Management pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Review the stage logs above; Kubernetes deployment stage attempts rollback on deployment failure.'
        }
    }
}
