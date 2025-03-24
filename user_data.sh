#!/bin/bash

# Crear variable de entorno con valor random
export RANDOM_VALUE=$(openssl rand -hex 12)

# Instalar Apache HTTP Server
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Crear un archivo HTML con el valor de RANDOM_VALUE
cat <<EOF > /var/www/html/index.html
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

# Reiniciar Apache para aplicar los cambios
systemctl restart httpd