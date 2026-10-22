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
        // Use the kubeconfig that works in your interactive Windows account.
        // Ensure the Jenkins service account has read access to this file.
        KUBECONFIG = 'C:\\Users\\BALAJI\\.kube\\config'
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
                    if not exist index.html exit /b 1
                    if not exist Dockerfile exit /b 1
                    if not exist deployment.yaml exit /b 1
                    if not exist Jenkinsfile exit /b 1
                    echo Required application files found.
                '''
            }
        }

        stage('Check Docker and Kubernetes Access') {
            steps {
                bat '''
                    "%DOCKER%" --version
                    if errorlevel 1 exit /b 1

                    "%KUBECTL%" version --client
                    if errorlevel 1 exit /b 1

                    echo Using kubeconfig: %KUBECONFIG%
                    if not exist "%KUBECONFIG%" (
                        echo ERROR: kubeconfig file not found or not accessible.
                        exit /b 1
                    )

                    "%KUBECTL%" config current-context
                    if errorlevel 1 exit /b 1

                    "%KUBECTL%" get nodes
                    if errorlevel 1 (
                        echo ERROR: Kubernetes API access failed. Check kubeconfig and certificate trust.
                        exit /b 1
                    )
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
                // This test expects an Nginx-based Dockerfile serving the site on port 80.
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
        success {
            echo 'Traffic Management pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Review the first failing stage. Do not disable TLS verification; fix kubeconfig or certificate trust.'
        }
    }
}
