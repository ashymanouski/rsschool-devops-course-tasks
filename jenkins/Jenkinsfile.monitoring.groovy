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
                        
                        // echo "Testing Prometheus connectivity with retries..."
                        // sh """
                        //     for i in {1..10}; do
                        //         echo "Attempt \$i/10: Testing Prometheus health..."
                        //         if kubectl run test-prometheus-\$i --image=curlimages/curl:latest --rm -i --restart=Never -n monitoring -- \
                        //            curl -f -s http://prometheus-server/-/healthy; then
                        //             echo "Prometheus health check PASSED on attempt \$i"
                        //             break
                        //         else
                        //             echo "Prometheus is not ready yet ..."
                        //             if [ \$i -eq 10 ]; then
                        //                 echo "All 10 attempts failed. Prometheus health check FAILED"
                        //                 echo "Checking pod status for debugging..."
                        //                 kubectl get pods -n monitoring
                        //                 kubectl describe pods -n monitoring | head -20
                        //                 exit 1
                        //             else
                        //                 sleep 10
                        //             fi
                        //         fi
                        //     done
                        // """
                        
                        // echo "Prometheus verification completed successfully"
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