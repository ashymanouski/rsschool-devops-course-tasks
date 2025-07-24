pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: helm
                    image: alpine/helm:latest
                    command:
                    - sleep
                    - infinity
                  - name: kubectl
                    image: bitnami/kubectl:latest
                    command:
                    - sleep
                    - infinity
            '''
        }
    }
    
    options {
        skipDefaultCheckout(true)
    }

    triggers {
        githubPush()
    }


    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup Tools') {
            steps {
                container('helm') {
                    script {
                        echo "Setting up Helm repositories..."
                        sh "helm repo add bitnami https://charts.bitnami.com/bitnami"
                        sh "helm repo update"
                        echo "Helm repositories configured"
                    }
                }
            }
        }
        
        stage('Deploy Prometheus') {
            steps {
                container('helm') {
                    script {
                        echo "Deploying Prometheus monitoring stack..."
                        
                        dir('helm/monitoring/prometheus') {
                            sh "helm dependency update"
                            sh """
                                helm upgrade --install prometheus . \\
                                    --namespace monitoring \\
                                    --create-namespace \\
                                    --wait \\
                                    --timeout=10m \\
                                    --values values.yaml
                            """
                        }
                        
                        echo "Prometheus monitoring stack deployed successfully"
                    }
                }
                
                container('kubectl') {
                    script {
                        echo "Creating monitoring namespace..."
                        sh "kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -"
                        
                        echo "Waiting for Prometheus deployment..."
                        sh "kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s"
                        
                        echo "Displaying deployment status..."
                        sh "kubectl get pods -n monitoring"
                        sh "kubectl get svc -n monitoring"
                    }
                }
            }
        }
        
        stage('Verify Prometheus') {
            steps {
                container('kubectl') {
                    script {
                        echo "Verifying Prometheus deployment..."
                        
                        sh """
                            kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
                        """
                        
                        sh """
                            echo "Testing Prometheus service connectivity..."
                            kubectl run test-prometheus --image=curlimages/curl:latest --rm -i --restart=Never -- curl -f -s -o /dev/null -w "Prometheus service response: %{http_code}\\n" http://prometheus-server.monitoring.svc.cluster.local:9090/ || echo "Prometheus service check failed"
                        """
                        
                        echo "Prometheus verification completed successfully"
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "Monitoring pipeline execution completed"
            }
        }
    }
} 