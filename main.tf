provider "aws" {
  region = var.aws_region
}

# Crear la VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MainVPC"
  }
}

# Crear el Internet Gateway (para acceso público)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIGW"
  }
}

# Crear las subnets públicas
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}b"

  tags = {
    Name = "PublicSubnet2"
  }
}

# Crear las subnets privadas
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "PrivateSubnet1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "PrivateSubnet2"
  }
}

# Crear la tabla de rutas para las subnets públicas
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Asociar la tabla de rutas con las subnets públicas
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# (Opcional) Crear un NAT Gateway para las subnets privadas
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "NatGateway"
  }
}

# Crear la tabla de rutas para las subnets privadas (para que usen el NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "PrivateRouteTable"
  }
}

# Asociar la tabla de rutas con las subnets privadas
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# Crear el grupo de seguridad para la instancia EC2
resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Crear la instancia EC2
resource "aws_instance" "web" {
  ami             = var.ami_id
  instance_type   = "t3.micro"
  key_name        = var.key_pair_name
  subnet_id       = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]  # Usar vpc_security_group_ids
  user_data       = filebase64("user_data.sh")
}

# Crear el Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.instance_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# Crear el Launch Configuration y el Auto Scaling Group
resource "aws_launch_configuration" "app_lc" {
  name_prefix     = "app-lc-"
  image_id        = var.ami_id
  instance_type   = "t3.micro"
  key_name        = var.key_pair_name
  security_groups = [aws_security_group.instance_sg.id]
  user_data       = file("user_data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                 = "app-asg"
  min_size             = 1
  max_size             = 3
  vpc_zone_identifier  = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  launch_configuration = aws_launch_configuration.app_lc.name

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "app-instance"
    propagate_at_launch = true
  }
}

# Crear el Target Group y el Listener del Application Load Balancer
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Política de Escalado hacia Arriba (Scale Up)
resource "aws_autoscaling_policy" "increase_ec2" {
  name                   = "increase-ec2"
  scaling_adjustment     = 1  # Añadir 1 instancia
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60  # Tiempo de espera entre escalados (en segundos)
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "SimpleScaling"
}

# Política de Escalado hacia Abajo (Scale Down)
resource "aws_autoscaling_policy" "reduce_ec2" {
  name                   = "reduce-ec2"
  scaling_adjustment     = -1  # Reducir 1 instancia
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60  # Tiempo de espera entre escalados (en segundos)
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type            = "SimpleScaling"
}

# Crear las alarmas de CloudWatch
# Alarma para CPU alta
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1  # Número de períodos consecutivos que deben superar el umbral
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60  # Período de evaluación (en segundos)
  statistic           = "Average"
  threshold           = 50  # Umbral de uso de CPU (en porcentaje)
  alarm_actions       = [aws_autoscaling_policy.increase_ec2.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

# Alarma para CPU baja
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1  # Número de períodos consecutivos que deben estar por debajo del umbral
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60  # Período de evaluación (en segundos)
  statistic           = "Average"
  threshold           = 20  # Umbral de uso de CPU (en porcentaje)
  alarm_actions       = [aws_autoscaling_policy.reduce_ec2.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

# Crear la base de datos RDS
resource "aws_db_instance" "rds" {
  allocated_storage      = 20
  engine                = "mysql"
  instance_class        = "db.t3.micro"
  db_name              = "mydatabase"
  username             = var.db_username
  password             = var.db_password
  publicly_accessible  = false
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}