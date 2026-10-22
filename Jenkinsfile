
pipeline {
    agent any

    parameters {
        string(
            name: 'IMAGE_TAG',
            defaultValue: 'v1',
            description: 'Docker image version'
        )
        booleanParam(
            name: 'DEPLOY_TO_K8S',
            defaultValue: true,
            description: 'Deploy to Kubernetes'
        )
    }

    environment {
        DOCKER = 'C:\\Program Files\\Docker\\Docker\\resources\\bin\\docker.exe'
        KUBECTL = 'C:\\Program Files\\Docker\\Docker\\resources\\bin\\kubectl.exe'
        KUBECONFIG = 'C:\\Users\\BALAJI\\.kube\\config'
        IMAGE = 'balaji00002/traffic-management-dashboard'
    }

    stages {
        stage('Pull Latest Code') {
            steps {
                checkout scm
                bat 'git log -1 --oneline'
            }
        }

        stage('Parallel Validation and Tests') {
            parallel {
                stage('Validate Required Files') {
                    steps {
                        bat '''
                            if not exist index.html exit /b 1
                            if not exist Dockerfile exit /b 1
                            if not exist Jenkinsfile exit /b 1
                            if not exist deployment.yaml exit /b 1
                            echo All required files exist.
                        '''
                    }
                }

                stage('Test Application HTML') {
                    steps {
                        bat '''
                            powershell -NoProfile -Command ^
                            "$html = Get-Content index.html -Raw; ^
                            if ($html -notmatch '<html' -or $html -notmatch '</html>') { ^
                                Write-Error 'HTML validation failed'; exit 1 ^
                            }; ^
                            if ($html -notmatch 'Intersection') { ^
                                Write-Error 'Traffic dashboard content missing'; exit 1 ^
                            }; ^
                            Write-Output 'HTML smoke test passed.'"
                        '''
                    }
                }

                stage('Check Docker and Kubernetes Tools') {
                    steps {
                        bat '''
                            "%DOCKER%" --version
                            if errorlevel 1 exit /b 1
                            "%KUBECTL%" version --client
                            if errorlevel 1 exit /b 1
                        '''
                    }
                }
            }
        }

        stage('Archive Build Artifacts') {
            steps {
                archiveArtifacts artifacts:
                    'index.html,Dockerfile,deployment.yaml,Jenkinsfile',
                    fingerprint: true
            }
        }

        stage('Build Docker Image') {
            steps {
                bat '''
                    "%DOCKER%" build -t %IMAGE%:%IMAGE_TAG% .
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat '''
                        "%DOCKER%" login -u "%DOCKER_USER%" --password-stdin
                        if errorlevel 1 exit /b 1
                    '''
                }
                bat '''
                    "%DOCKER%" push %IMAGE%:%IMAGE_TAG%
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Deploy to Kubernetes') {
            when {
                expression { params.DEPLOY_TO_K8S }
            }
            steps {
                bat '''
                    "%KUBECTL%" apply -f deployment.yaml
                    if errorlevel 1 exit /b 1

                    "%KUBECTL%" set image deployment/traffic-dashboard traffic-dashboard=%IMAGE%:%IMAGE_TAG%
                    if errorlevel 1 exit /b 1

                    "%KUBECTL%" rollout status deployment/traffic-dashboard --timeout=120s
                    if errorlevel 1 (
                        "%KUBECTL%" rollout undo deployment/traffic-dashboard
                        exit /b 1
                    )

                    "%KUBECTL%" get pods
                    "%KUBECTL%" get service traffic-dashboard-service
                '''
            }
        }
    }

    post {
        success {
            echo 'Traffic Management pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Check the failed stage in Console Output.'
        }
        always {
            echo 'Pipeline execution finished.'
        }
    }
}
