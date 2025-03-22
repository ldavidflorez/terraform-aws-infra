#!/bin/bash

# Crear variable de entorno con valor random
export RANDOM_VALUE=$(openssl rand -hex 12)

# Instalar Docker
yum update -y
yum install -y docker
service docker start
usermod -a -G docker ec2-user
systemctl enable docker

# Crear un archivo HTML con el valor de RANDOM_VALUE
cat <<EOF > /tmp/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Random Value</title>
</head>
<body>
    <h1>Random Value: $RANDOM_VALUE</h1>
</body>
</html>
EOF

# Crear un Dockerfile personalizado para Nginx
cat <<EOF > /tmp/Dockerfile
FROM nginx:latest
COPY /tmp/index.html /usr/share/nginx/html/index.html
EOF

# Construir la imagen Docker personalizada
docker build -t custom_nginx /tmp

# Ejecutar el contenedor con la imagen personalizada
docker run -d -p 80:80 --name my_service custom_nginx