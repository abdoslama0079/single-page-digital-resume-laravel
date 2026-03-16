pipeline {
    agent any

    environment {
        // Infrastructure Details
        ACR_NAME        = 'nodejsproject884215'
        ACR_URL         = "${ACR_NAME}.azurecr.io"
        IMAGE_NAME      = 'laravel-resume'
        RESOURCE_GROUP  = 'nodejs-aks-project'
        CLUSTER_NAME    = 'nodejs_aks_cluster'

        // Credentials (IDs from your Jenkins Credential Store)
        AZURE_SP_ID     = 'ARM_CLIENT_ID'
        AZURE_SP_SECRET = 'ARM_CLIENT_SECRET'
        AZURE_TENANT    = 'ARM_TENANT_ID'

        // Laravel specific
        APP_ENV         = 'production'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout & Versioning') {
            steps {
                checkout scm
                script {
                    // Create a unique tag using Build Number and Git Hash
                    env.APP_TAG = "v${BUILD_NUMBER}-${sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()}"
                }
            }
        }

        stage('Laravel Quality Check') {
            steps {
                // Check for syntax errors before building the image
                sh "find . -name '*.php' -exec php -l {} \\;"
            }
        }

        stage('Docker Build & Scan') {
            steps {
                script {
                    // Build the production image
                    sh "docker build -t ${ACR_URL}/${IMAGE_NAME}:${APP_TAG} ."
                    sh "docker tag ${ACR_URL}/${IMAGE_NAME}:${APP_TAG} ${ACR_URL}/${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Push to Azure Registry') {
            steps {
                withCredentials([
                    string(credentialsId: "${AZURE_SP_ID}", variable: 'CLIENT_ID'),
                    string(credentialsId: "${AZURE_SP_SECRET}", variable: 'CLIENT_SECRET'),
                    string(credentialsId: "${AZURE_TENANT}", variable: 'TENANT_ID')
                ]) {
                    sh "az login --service-principal -u ${CLIENT_ID} -p ${CLIENT_SECRET} --tenant ${TENANT_ID}"
                    sh "az acr login --name ${ACR_NAME}"
                    sh "docker push ${ACR_URL}/${IMAGE_NAME}:${APP_TAG}"
                    sh "docker push ${ACR_URL}/${IMAGE_NAME}:latest"
                }
            }
        }

        stage('Deploy to AKS (Rolling Update)') {
            steps {
                withCredentials([
                    string(credentialsId: "${AZURE_SP_ID}", variable: 'CLIENT_ID'),
                    string(credentialsId: "${AZURE_SP_SECRET}", variable: 'CLIENT_SECRET'),
                    string(credentialsId: "${AZURE_TENANT}", variable: 'TENANT_ID')
                ]) {
                   sh "az login --service-principal -u ${CLIENT_ID} -p ${CLIENT_SECRET} --tenant ${TENANT_ID}"
            sh "az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME} --overwrite-existing"

            // 1. Update the image tag inside your YAML file
            sh "sed -i 's|ACR_IMAGE_PLACEHOLDER|${ACR_URL}/${IMAGE_NAME}:${APP_TAG}|g' k8s/deployment.yaml"

            // 2. Apply the updated YAML
            sh "kubectl apply -f k8s/deployment.yaml"

            // 3. Verify the rollout
            sh "kubectl rollout status deployment/resume-app"
                script {
                    echo "Waiting for Azure to assign an External IP..."
                    def iterations = 0
                    while (iterations < 10) {
                        env.SERVICE_IP = sh(
                            script: "kubectl get svc resume-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'",
                            returnStdout: true
                        ).trim()
                        
                        if (env.SERVICE_IP) {
                            echo "IP Assigned: ${env.SERVICE_IP}"
                            break
                        } else {
                            echo "Still waiting... (Attempt ${iterations + 1}/10)"
                            sh "sleep 15"
                            iterations++
                        }
                    }
                }
                }
            }
        }
    }

    post {
        always {
            sh "docker logout ${ACR_URL}"
        }
        success {
            echo "Successfully deployed version ${APP_TAG} to AKS!"
        }
        failure {
            echo "Deployment failed. Check logs for details."
        }
    }
}
