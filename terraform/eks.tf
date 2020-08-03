terraform {
  backend "s3" {
    bucket = "dbk8s-main"
    key    = "terraform-state/myeks.tfstate"
    region = "us-east-1"
  }
}
provider "aws" {
  region = "us-east-1"
}
resource "aws_iam_role" "dbk8s" {
  name = "eks-cluster-dbk8s"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "dbk8s-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.dbk8s.name
}

resource "aws_iam_role_policy_attachment" "dbk8s-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.dbk8s.name
}
resource "aws_eks_cluster" "dbk8s" {
  name = "dbk8s"
  version = "1.17"
  role_arn = aws_iam_role.dbk8s.arn
  tags = {app: "k8s"}
  vpc_config {
    subnet_ids = ["subnet-008790b54ad7f885c", "subnet-07c8428ac57a078d5", "subnet-093c9188148802e13"]
    endpoint_private_access = true
    endpoint_public_access = false
    security_group_ids = ["sg-08bab77121941deea"]
  }
}
resource "aws_iam_role" "dbk8s-private" {
  name = "eks-node-dbk8s-private"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.dbk8s-private.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.dbk8s-private.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.dbk8s-private.name
}

resource "aws_eks_node_group" "dbk8s-private" {
  cluster_name = "dbk8s"
  node_group_name = "dbk8s-private"
  node_role_arn = aws_iam_role.dbk8s-private.arn
  subnet_ids = ["subnet-07c8428ac57a078d5", "subnet-093c9188148802e13"]
  scaling_config {
    desired_size = 3
    max_size = 5
    min_size = 1
  }
  labels = {"network": "private"}
  version = "1.17"
  instance_types = ["m5a.large"]
  remote_access {
    ec2_ssh_key = "main",
    source_security_group_ids = ["sg-08bab77121941deea"]
  }
}