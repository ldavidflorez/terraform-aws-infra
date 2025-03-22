#!/bin/bash

# Crear variable de entorno con valor random
export RANDOM_VALUE=$(openssl rand -hex 12)

# Instalar Docker
yum update -y
yum install -y docker
service docker start
usermod -a -G docker ec2-user
systemctl enable docker

# Ejecutar contenedor
docker run -d -p 80:80 -e RANDOM_VALUE=$RANDOM_VALUE --name my_service my_service:latest