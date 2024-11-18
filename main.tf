provider "aws" {
    region = "ap-south-1"
}
//creating vpc 
resource "aws_vpc" "custom_vpc"{
    cidr_block = "172.31.0.0/16"
}

//creating subnet 1 
resource "aws_subnet" "custom_subnet01" {
    vpc_id = aws_vpc.custom_vpc.id
    cidr_block = "172.31.0.0/20"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
}

//creatin subnet 2
resource "aws_subnet" "custom_subnet02" { 
    vpc_id = aws_vpc.custom_vpc.id
    cidr_block = "172.31.16.0/20"
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
}

//creating subnet 3 
resource "aws_subnet" "custom_subnet03" {
  vpc_id = aws_vpc.custom_vpc.id
  cidr_block = "172.31.32.0/20"
  availability_zone = "ap-south-1a"
}
resource "aws_subnet" "custom_subnet04"{
  vpc_id = aws_vpc.custom_vpc.id
  cidr_block = "172.31.48.0/20"
  availability_zone = "ap-south-1b"
}
//creating internet gateway 
resource "aws_internet_gateway" "custom_IGW" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "customIG"
  }

}

//creating route table 
resource "aws_route_table" "custom_RT" {
    vpc_id = aws_vpc.custom_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.custom_IGW.id
    }

    tags = {
        Name = "customRT"
    }
}

//creating subnet association
resource "aws_route_table_association" "subnet_association01" {
  subnet_id      = aws_subnet.custom_subnet01.id
  route_table_id = aws_route_table.custom_RT.id
}
resource "aws_route_table_association" "subnet_association02" {
  subnet_id      = aws_subnet.custom_subnet02.id
  route_table_id = aws_route_table.custom_RT.id
}
resource "aws_eip" "nat-ip" {
}
resource "aws_nat_gateway" "custom_NAT" {
  allocation_id = aws_eip.nat-ip.id
  subnet_id = aws_subnet.custom_subnet01.id
  tags = {
    "name" = "custom_NAT"
  }
}
resource "aws_route_table" "custom_RT02" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.custom_NAT.id

  }
}
resource "aws_route_table_association" "subnet_association03" {
  subnet_id = aws_subnet.custom_subnet03.id
  route_table_id = aws_route_table.custom_RT02.id
}
resource "aws_route_table_association" "subnet_association04" {
  subnet_id = aws_subnet.custom_subnet04.id
  route_table_id = aws_route_table.custom_RT02.id
}
//crating security group 
resource "aws_security_group" "EKS_SG" {
  name        = "EKS-SG"
  vpc_id      = aws_vpc.custom_vpc.id

  tags = {
    Name = "allow_ssh"
  }
}
//inbound rules 
resource "aws_vpc_security_group_ingress_rule" "allow_ipv4" {
  security_group_id = aws_security_group.EKS_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  ip_protocol       = "tcp"
  to_port           = 65535
}
//outbound rules 
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.EKS_SG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
//outbond rules for ipv6
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.EKS_SG.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}
# Attach Required Policies to Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
# IAM Role for Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Required Policies to Node Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
// Attach this policy when working with statefulset application for data persistency and use to create PVs (EBS) in aws
resource "aws_iam_role_policy_attachment" "CSI_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role = aws_iam_role.eks_node_role.name
}
# Creating a ec2 instance for interacting to the cluster 
# resource "aws_instance" "controller"{
#   ami = "ami-04a37924ffe27da53"
#   instance_type = "t2.micro"
#   key_name = var.key_name
#   subnet_id = aws_subnet.custom_subnet01.id
#   vpc_security_group_ids = [aws_security_group.EKS_SG.id]
#   user_data = <<-EOF
#     #!/bin/bash
#     # Installing kubectl
#     curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-09-12/bin/linux/amd64/kubectl
#     chmod +x ./kubectl
#     mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
#     yum install git -y 
#   EOF
# }
# output "controller_publicIP" {
#   value = aws_instance.controller.public_ip
# }

# Install aws cli if not and install kubectl 
# https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
# configure aws 
# configure cluster with kubectl 
# aws eks --region ap-south-1 update-kubeconfig --name my_first_cluster

# Creating eks cluster 
resource "aws_eks_cluster" "my_first_cluster" { 
  name     = "my_first_cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.custom_subnet01.id, aws_subnet.custom_subnet02.id]
    security_group_ids = [aws_security_group.EKS_SG.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  
  access_config {
    authentication_mode = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}
output "endpoint" {
  value = aws_eks_cluster.my_first_cluster.endpoint
}
# addons for eks cluster 
# resource "aws_eks_addon" "addon_coredns" {
# cluster_name = aws_eks_cluster.my_first_cluster.name
#   addon_name   = "coredns"
#   addon_version               = "v1.11.3-eksbuild.1"
#   resolve_conflicts_on_update = "PRESERVE"
# }
resource "aws_eks_addon" "addon_vpc_cni" {
  cluster_name = aws_eks_cluster.my_first_cluster.name
  addon_name   = "vpc-cni"
  addon_version               = "v1.18.3-eksbuild.2"
  resolve_conflicts_on_update = "PRESERVE"
}
resource "aws_eks_addon" "addon_kubeproxy" {
cluster_name = aws_eks_cluster.my_first_cluster.name
  addon_name   = "kube-proxy"
  addon_version               = "v1.31.0-eksbuild.2"
  resolve_conflicts_on_update = "PRESERVE" 
}
resource "aws_eks_addon" "addon_eksPodIdentityAgent" {
cluster_name = aws_eks_cluster.my_first_cluster.name
  addon_name   = "eks-pod-identity-agent"
  addon_version               = "v1.3.2-eksbuild.2"
  resolve_conflicts_on_update = "PRESERVE" 
}
 
# Creating nodegroup 
resource "aws_eks_node_group" "eks_nodegroup" { 
  cluster_name    = aws_eks_cluster.my_first_cluster.name
  node_group_name = "my_nodegroup_eks"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.custom_subnet03.id, aws_subnet.custom_subnet04.id]
  ami_type = "AL2_x86_64"
  instance_types = ["t2.medium"]
  disk_size = 20
  

  remote_access {
    ec2_ssh_key = var.key_name
    source_security_group_ids = [ aws_security_group.EKS_SG.id ]
  }

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
    aws_iam_role_policy_attachment.CSI_driver_policy,
  ]
}
//--------creating instance for Jenkins server------------
resource "aws_instance" "Jenkins_server" {
  ami           = "ami-0dee22c13ea7a9a67" 
  instance_type = "t2.medium"
  key_name = var.key_name
  subnet_id = aws_subnet.custom_subnet01.id
  vpc_security_group_ids = [aws_security_group.EKS_SG.id]
  user_data = <<-EOF
    #!/bin/bash

    # Update the package index to ensure we have the latest list of available packages
    apt update -y

    # Install fontconfig and OpenJDK 17, both are dependencies required for Jenkins
    apt install fontconfig openjdk-17-jre -y

    # Download the Jenkins signing key and save it to the system’s trusted keyring
    wget -O /usr/share/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

    # Add the Jenkins repository to the system’s package sources, referencing the signing key
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    # Update the package index again to include packages from the newly added Jenkins repository
    apt-get update -y

    # Install Jenkins from the Jenkins repository
    apt-get install jenkins -y
  EOF

  tags = {
    Name = "Jenkins_server"
  }
}
output "Jenkins_server_PublicIP" {
    value = aws_instance.Jenkins_server.public_ip
}


