
pipeline {
    agent any

    environment {
        DOCKERHUB_USER = 'YOUR_DOCKERHUB_USERNAME'
        IMAGE_NAME = 'traffic-management-dashboard'
        K8S_DEPLOYMENT = 'traffic-dashboard'
        K8S_CONTAINER = 'traffic-app'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate Files') {
            steps {
                sh '''
                    test -f index.html
                    test -f Dockerfile
                    test -f deployment.yaml
                    grep -q "Intelligent Traffic Management" index.html
                    echo "Required files and dashboard title verified."
                '''
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                    docker build \
                      -t ${DOCKERHUB_USER}/${IMAGE_NAME}:build-${BUILD_NUMBER} \
                      -t ${DOCKERHUB_USER}/${IMAGE_NAME}:latest .
                '''
            }
        }

        stage('Container Smoke Test') {
            steps {
                sh '''
                    set -eu
                    IMAGE="${DOCKERHUB_USER}/${IMAGE_NAME}:build-${BUILD_NUMBER}"
                    docker rm -f traffic-smoke-test >/dev/null 2>&1 || true
                    docker run -d --name traffic-smoke-test "$IMAGE"
                    trap 'docker rm -f traffic-smoke-test >/dev/null 2>&1 || true' EXIT

                    for attempt in $(seq 1 10); do
                      if docker exec traffic-smoke-test \
                        wget -q -O - http://127.0.0.1/ \
                        | grep -q "Intelligent Traffic Management"; then
                        echo "Smoke test passed."
                        exit 0
                      fi
                      sleep 2
                    done

                    echo "Smoke test failed."
                    exit 1
                '''
            }
        }

        stage('Publish Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x
                        echo "$DH_TOKEN" | docker login \
                          -u "$DH_USER" --password-stdin

                        docker push \
                          ${DOCKERHUB_USER}/${IMAGE_NAME}:build-${BUILD_NUMBER}
                        docker push \
                          ${DOCKERHUB_USER}/${IMAGE_NAME}:latest

                        docker logout
                    '''
                }
            }
        }

        stage('Deploy and Verify') {
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kubeconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    sh '''
                        set -eu
                        IMAGE="${DOCKERHUB_USER}/${IMAGE_NAME}:build-${BUILD_NUMBER}"

                        kubectl apply -f deployment.yaml

                        if kubectl set image \
                          deployment/${K8S_DEPLOYMENT} \
                          ${K8S_CONTAINER}="$IMAGE" \
                          && kubectl rollout status \
                            deployment/${K8S_DEPLOYMENT} --timeout=120s; then
                          echo "Deployment verified."
                        else
                          echo "Deployment failed; attempting rollback."
                          kubectl rollout undo \
                            deployment/${K8S_DEPLOYMENT} || true
                          exit 1
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
        success {
            echo 'Traffic dashboard pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Review the stage logs.'
        }
    }
}
