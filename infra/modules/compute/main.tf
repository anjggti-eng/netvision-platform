# AMI mais recente do Amazon Linux 2023 (arm64) — public param, sem custo de pipeline.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_iam_role" "node" {
  name = "${var.project_name}-k3s-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# SSM Session Manager: acesso ao cluster SEM porta 22 aberta e sem par de chaves.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.project_name}-k3s-node"
  role = aws_iam_role.node.name
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-k3s-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  user_data     = base64encode(templatefile("${path.module}/user_data.sh", {}))

  iam_instance_profile {
    arn = aws_iam_instance_profile.node.arn
  }

  vpc_security_group_ids = [var.sg_id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-k3s"
      Role = "k3s-server"
    }
  }

  tags = {
    Name = "${var.project_name}-k3s-lt"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "k3s" {
  name                = "${var.project_name}-k3s"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  vpc_zone_identifier = [var.subnet_id]

  # Spot com múltiplos tipos: sobrevive a interrupção/indisponibilidade de zona.
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this.id
        version            = "$Latest"
      }

      override {
        instance_type = "t4g.medium"
      }

      override {
        instance_type = "t4g.large"
      }
    }

    instances_distribution {
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-k3s"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "k3s-server"
    propagate_at_launch = true
  }
}
