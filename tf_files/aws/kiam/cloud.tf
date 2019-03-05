terraform {
  backend "s3" {
    encrypt = "true"
  }
}

provider "aws" {}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "server_node" {
  name = "server_node"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "server_node" {
  name = "server_node"
  role = "${aws_iam_role.server_node.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "arn:aws:iam:${data.aws_caller_identity.current.account_id}:role/kiam-server"
    }
    ]
  }
EOF
}

resource "aws_iam_instance_profile" "server_node" {
  name = "server_node"
  role = "${aws_iam_role.server_node.name}"
}

resource "aws_iam_role" "server_role" {
  name        = "kiam-server"
  description = "Role the Kiam Server process assumes"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/server_node"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "server_policy" {
  name        = "kiam_server_policy"
  description = "Policy for the Kiam Server process"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "server_policy_attach" {
  name       = "kiam-server-attachment"
  roles      = ["${aws_iam_role.server_role.name}"]
  policy_arn = "${aws_iam_policy.server_policy.arn}"
}