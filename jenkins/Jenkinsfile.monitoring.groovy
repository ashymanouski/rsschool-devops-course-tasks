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
                                    --values values.yaml
                            """
                        }
                        
                        echo "Prometheus monitoring stack deployed successfully"
                    }
                }
                
                container('kubectl') {
                    script {
                        def healthCheck = {
                            try {
                                sh "helm status prometheus -n monitoring"
                                
                                sh "kubectl wait --for=condition=ready --timeout=300s pod -l 'app.kubernetes.io/instance=prometheus' -n monitoring"
                                
                                sh """
                                    kubectl run health-check-\${BUILD_NUMBER} --image=curlimages/curl:latest --rm -i --restart=Never -n monitoring --timeout=60s -- \
                                    sh -c 'curl -f -s --max-time 10 http://prometheus-server:9090/-/healthy && echo "Health check: PASS"'
                                """
                                
                                sh """
                                    kubectl run metrics-check-\${BUILD_NUMBER} --image=curlimages/curl:latest --rm -i --restart=Never -n monitoring --timeout=60s -- \
                                    sh -c 'curl -f -s --max-time 10 http://prometheus-server:9090/api/v1/query?query=up | grep -q "success" && echo "Metrics endpoint: PASS"'
                                """
                                
                                return true
                            } catch (Exception e) {
                                echo "Health check failed: ${e.getMessage()}"
                                sh "kubectl describe pods -n monitoring"
                                sh "kubectl logs -l app.kubernetes.io/instance=prometheus --tail=50 -n monitoring"
                                throw e
                            }
                        }
                        
                        echo "Executing comprehensive health checks..."
                        healthCheck()
                        echo "All health checks passed successfully"
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