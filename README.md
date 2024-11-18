# ECR CICD

# Create Resources using Terraform script

Creates an EKS cluster with one worker node and Jenkins server 

NOTE: replace with your key pair name in [variable.tf](http://variable.tf) file

## JENKINS CONFIGURATON

### Login to the serve

and install docker, aws cli

```yaml
sudo apt update -y 
sudo apt install docker.io -y
sudo usermod -aG docker jenkins 

```

### Login to jenkins user

```yaml
# install aws cli 
sudo apt install unzip -y 
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# configure aws 
aws configure 
# Enter your access key and secret key 

# Insatll kubectl version 1.31
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-09-12/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
```

reboot the instance 

### Add k8s config file

on your local mechine connect to kubernetes api using aws cli 

```yaml
aws eks update-kubeconfig --region ap-south-1 --name <eks_cluster_name>
```

now your have acces to your cluster

### create a jenkins creadential

kind: secret file 

now selete the file, path: /home/$USER/.kube/config

ID: k8sconfig ( name should be same in script ) 

### plugins to install

1. **Git Plugin**:
    - **Description**: This plugin allows Jenkins to clone repositories from Git, including GitHub.
    - **Installation**: Go to **Manage Jenkins** > **Manage Plugins** > **Available** tab, search for "Git Plugin", and install it.
2. **Docker Pipeline**:
    - **Description**: This plugin provides support for Docker in Jenkins pipelines, allowing you to build and publish Docker images.
    - **Installation**: Search for "Docker Pipeline" in the **Available** tab and install it.
3. **Kubernetes CLI Plugin**:
    - **Description**: This plugin integrates Kubernetes with Jenkins, allowing you to run **`kubectl`** commands directly from your pipeline.
    - **Installation**: Search for "Kubernetes CLI Plugin" in the **Available** tab and install it.
4. **Environment Injector Plugin** :
    - **Description**: This plugin allows you to inject environment variables into the build process, which can be useful for dynamic configurations.
    - **Installation**: Search for "Environment Injector Plugin" in the **Available** tab and install it.
5. **AWS Steps (haven’t use in script)**:
    - **Description**: This plugin provides steps for interacting with AWS services, including ECR.
    - **Installation**: Search for "AWS Steps" in the **Available** tab and install it.

### Jenkisnfile

```groovy
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

```
