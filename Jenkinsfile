pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        DOCKER = 'C:\\Program Files\\Docker\\Docker\\resources\\bin\\docker.exe'
        KUBECTL = 'C:\\Program Files\\Docker\\Docker\\resources\\bin\\kubectl.exe'
        DOCKER_IMAGE = 'balaji00002/traffic-management-dashboard'
        IMAGE_TAG = "build-${BUILD_NUMBER}"
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
        DEPLOYMENT_NAME = 'traffic-dashboard'
        CONTAINER_NAME = 'traffic-app'
        SERVICE_NAME = 'traffic-dashboard-service'
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
                    if not exist index.html (
                        echo ERROR: index.html is missing
                        exit /b 1
                    )
                    if not exist Dockerfile (
                        echo ERROR: Dockerfile is missing
                        exit /b 1
                    )
                    if not exist deployment.yaml (
                        echo ERROR: deployment.yaml is missing
                        exit /b 1
                    )
                    if not exist Jenkinsfile (
                        echo ERROR: Jenkinsfile is missing
                        exit /b 1
                    )
                    echo Required application files found.
                '''
            }
        }

        stage('Check Tools and Kubernetes') {
            steps {
                bat '''
                    "%DOCKER%" --version
                    if errorlevel 1 exit /b 1
                    "%KUBECTL%" version --client
                    if errorlevel 1 exit /b 1
                    "%KUBECTL%" config current-context
                    if errorlevel 1 exit /b 1
                    "%KUBECTL%" get nodes
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                bat '''
                    "%DOCKER%" build -t %DOCKER_IMAGE%:%IMAGE_TAG% -t %DOCKER_IMAGE%:latest .
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Smoke Test Image') {
            steps {
                // This expects the Dockerfile to use nginx and serve the site on port 80.
                bat '''
                    "%DOCKER%" run --rm %DOCKER_IMAGE%:%IMAGE_TAG% nginx -t
                    if errorlevel 1 exit /b 1
                '''
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
                        echo %DOCKERHUB_TOKEN% | "%DOCKER%" login -u %DOCKERHUB_USER% --password-stdin
                        if errorlevel 1 exit /b 1
                        "%DOCKER%" push %DOCKER_IMAGE%:%IMAGE_TAG%
                        if errorlevel 1 exit /b 1
                        "%DOCKER%" push %DOCKER_IMAGE%:latest
                        if errorlevel 1 exit /b 1
                        "%DOCKER%" logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    try {
                        bat '''
                            "%KUBECTL%" apply -f deployment.yaml
                            if errorlevel 1 exit /b 1

                            "%KUBECTL%" set image deployment/%DEPLOYMENT_NAME% %CONTAINER_NAME%=%DOCKER_IMAGE%:%IMAGE_TAG% -n %K8S_NAMESPACE%
                            if errorlevel 1 exit /b 1

                            "%KUBECTL%" rollout status deployment/%DEPLOYMENT_NAME% -n %K8S_NAMESPACE% --timeout=120s
                            if errorlevel 1 exit /b 1
                        '''
                    } catch (err) {
                        echo 'Deployment failed. Attempting rollback to the previous Kubernetes revision.'
                        bat '''
                            "%KUBECTL%" rollout undo deployment/%DEPLOYMENT_NAME% -n %K8S_NAMESPACE%
                            "%KUBECTL%" rollout status deployment/%DEPLOYMENT_NAME% -n %K8S_NAMESPACE% --timeout=120s
                        '''
                        throw err
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                bat '''
                    "%KUBECTL%" get deployment %DEPLOYMENT_NAME% -n %K8S_NAMESPACE%
                    if errorlevel 1 exit /b 1
                    "%KUBECTL%" get pods -n %K8S_NAMESPACE% -l app=traffic-dashboard
                    if errorlevel 1 exit /b 1
                    "%KUBECTL%" get service %SERVICE_NAME% -n %K8S_NAMESPACE%
                    if errorlevel 1 exit /b 1
                '''
            }
        }
    }

    post {
        always {
            bat 'if exist deployment.yaml type deployment.yaml > nul'
        }
        success {
            echo 'Traffic Management pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Review the failed stage. Deployment stage attempts rollback if rollout fails.'
        }
    }
}
