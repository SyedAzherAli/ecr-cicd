pipeline {
    agent any 

    environment {
        AWS_ACCOUNT_ID = ""
        AWS_REGION = "ap-south-1"
        GIT_REPO = 'https://github.com/SyedAzherAli/ecr-cicd.git'
        IMAGE_NAME = "ecr-cicd-test"
        IMAGE_TAG = "latest"
        REPOSITORY_URL = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        K8S_CLUSTER_NAME = "my_first_cluster"
    }

    stages {
        stage("Cleanup Workspace and Docker Images") {
            steps {
                cleanWs() // Built-in Jenkins method to clean workspace
                sh '''
                # Remove dangling images to prevent unnecessary storage issues
                docker rmi -f $(docker images -f "dangling=true" -q) || echo "No dangling images to remove."
                '''
            }
        }
        stage("Checkout Source Code") {
            steps {
                git branch: "main", url: "${GIT_REPO}"
            }
        }
        stage("Build Docker Image") {
            steps {
                script {
                    dockerImage = docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                }
            }
        }
        stage("Login to AWS ECR") {
            steps {
                script {
                    sh '''
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${REPOSITORY_URL}
                    '''
                }
            }
        }
        stage("Push Docker Image to ECR") {
            steps {
                script {
                    sh '''
                    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REPOSITORY_URL}/${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${REPOSITORY_URL}/${IMAGE_NAME}:${IMAGE_TAG}
                    '''
                }
            }
        }
        stage("Deploy to Kubernetes") {
            steps {
                withKubeConfig([credentialsId: 'k8sconfig']) {
                    sh '''
                    # Ensure the secret is created or skipped if it already exists
                    ../../kubectl create secret generic my-registry-key \
                        --from-file=.dockerconfigjson=/var/lib/jenkins/.docker/config.json \
                        --type=kubernetes.io/dockerconfigjson || echo "Secret already exists, skipping creation."
                    
                    # Apply Kubernetes manifests
                    ../../kubectl apply -f react-dep-sev.yaml
                    '''
                }
            }
        }
    }
}

