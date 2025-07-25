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
                    securityContext:
                      runAsUser: 1000
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
                        echo "Checking Prometheus status..."
                        sh "kubectl get pods -n monitoring --no-headers"
                        
                        echo "Verifying Prometheus deployment..."
                        
                        def maxRetries = 10
                        def retryDelay = 10
                        def attempt = 1
                        
                        while (attempt <= maxRetries) {
                            echo "Health check attempt ${attempt}/${maxRetries}"
                            
                            try {
                                sh """
                                    kubectl run prometheus-health-check-${BUILD_NUMBER}-${attempt} \\
                                        --image=curlimages/curl:latest \\
                                        --rm \\
                                        -i \\
                                        --restart=Never \\
                                        -n monitoring \\
                                        -- \\
                                        curl -f -s http://prometheus-server:80/-/healthy
                                """
                                echo "Prometheus health check PASSED on attempt ${attempt}"
                                echo "Prometheus verification completed successfully"
                                break
                            } catch (Exception e) {
                                echo "Health check attempt ${attempt} failed: ${e.getMessage()}"
                                
                                if (attempt == maxRetries) {
                                    echo "All ${maxRetries} health check attempts failed"
                                    echo "Collecting diagnostic information..."
                                    sh """
                                        kubectl get pods -n monitoring
                                        kubectl describe pods -n monitoring | head -50
                                        kubectl logs -l app.kubernetes.io/instance=prometheus -n monitoring --tail=20
                                    """
                                    error "Prometheus health check failed after ${maxRetries} attempts"
                                } else {
                                    echo "Waiting ${retryDelay} seconds before next attempt..."
                                    sleep retryDelay
                                }
                            }
                            attempt++
                        }
                    }
                }
            }
        }

        stage('Deploy Grafana') {
            steps {
                container('helm') {
                    script {
                        echo "Deploying Grafana visualization platform..."

                        // Get credentials from Jenkins
                        withCredentials([usernamePassword(credentialsId: 'grafana-admin-credentials', usernameVariable: 'GRAFANA_USER', passwordVariable: 'GRAFANA_PASSWORD')]) {
                            dir('helm/monitoring/grafana') {
                                sh "helm dependency update"
                                sh """
                                    helm upgrade --install grafana . \\
                                        --namespace monitoring \\
                                        --create-namespace \\
                                        --values values.yaml \\
                                        --set admin.user=${GRAFANA_USER} \\
                                        --set admin.password=${GRAFANA_PASSWORD}
                                """
                            }
                        }

                        echo "Grafana visualization platform deployed successfully"
                    }
                }

                container('kubectl') {
                    script {
                        echo "Checking Grafana status..."
                        sh "kubectl get pods -n monitoring --no-headers"

                        echo "Verifying Grafana deployment..."

                        def maxRetries = 10
                        def retryDelay = 10
                        def attempt = 1

                        while (attempt <= maxRetries) {
                            echo "Grafana health check attempt ${attempt}/${maxRetries}"

                            try {
                                sh """
                                    kubectl run grafana-health-check-${BUILD_NUMBER}-${attempt} \\
                                        --image=curlimages/curl:latest \\
                                        --rm \\
                                        -i \\
                                        --restart=Never \\
                                        -n monitoring \\
                                        -- \\
                                        curl -f -s http://grafana:3000/api/health
                                """
                                echo "Grafana health check PASSED on attempt ${attempt}"
                                echo "Grafana verification completed successfully"
                                break
                            } catch (Exception e) {
                                echo "Grafana health check attempt ${attempt} failed: ${e.getMessage()}"

                                if (attempt == maxRetries) {
                                    echo "All ${maxRetries} Grafana health check attempts failed"
                                    echo "Collecting diagnostic information..."
                                    sh """
                                        kubectl get pods -n monitoring
                                        kubectl describe pods -n monitoring | head -50
                                        kubectl logs -l app.kubernetes.io/instance=grafana -n monitoring --tail=20
                                    """
                                    error "Grafana health check failed after ${maxRetries} attempts"
                                } else {
                                    echo "Waiting ${retryDelay} seconds before next attempt..."
                                    sleep retryDelay
                                }
                            }
                            attempt++
                        }
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