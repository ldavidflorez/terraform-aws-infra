# Infraestructura en AWS con Terraform

Este proyecto despliega una infraestructura en AWS utilizando Terraform. La infraestructura incluye una VPC con subredes públicas y privadas, una instancia EC2, un Auto Scaling Group (ASG) con un Application Load Balancer (ALB), una base de datos RDS, y configuraciones de seguridad y monitoreo.

---

## Requisitos Previos

Antes de ejecutar este proyecto, asegúrate de tener lo siguiente:

1. **Terraform instalado**: Descarga e instala Terraform desde [aquí](https://www.terraform.io/downloads.html).
2. **Key Pair**: Un key pair de AWS para acceder a la instancia EC2 por SSH.

---

## Estructura del Proyecto

El proyecto está organizado de la siguiente manera:

```
terraform-aws-infra/
├── main.tf              # Configuración principal de la infraestructura.
├── variables.tf         # Variables utilizadas en el proyecto.
├── outputs.tf           # Valores de salida después de aplicar la infraestructura.
├── user_data.sh         # Script de user data para la instancia EC2.
├── terraform.tfvars     # Valores de las variables (opcional, no se incluye en el repositorio).
└── README.md            # Este archivo.
```

---

## Descripción de la Infraestructura

El proyecto implementa la siguiente infraestructura en AWS:

### 1. **VPC con Subredes Públicas y Privadas**
   - Se crea una VPC con un rango CIDR `10.0.0.0/16`.
   - Dos subredes públicas y dos privadas, distribuidas en dos zonas de disponibilidad (AZ).
   - Un Internet Gateway (IGW) para permitir acceso a Internet desde las subredes públicas.
   - Un NAT Gateway en una subred pública para permitir acceso a Internet desde las subredes privadas.

### 2. **Instancia EC2 en la Subred Pública**
   - Una instancia EC2 tipo `t3.micro` en una subred pública.
   - Acceso SSH habilitado mediante un key pair proporcionado como variable.
   - User data para instalar Apache Server y servir una aplicación básica.
   - Se crea una variable de entorno con un valor aleatorio en el user data, para mostrarla en el index.html de la aplicación, y verificar el balanceo de carga.

### 3. **Auto Scaling Group (ASG) con Application Load Balancer (ALB)**
   - Un ASG que utiliza la AMI de la instancia EC2 creada en el paso 2.
   - Un ALB con listener en el puerto 80 (HTTP).
   - El ASG escala automáticamente basado en métricas de CloudWatch (porcentaje de uso del CPU).

### 4. **Base de Datos RDS en la Subred Privada**
   - Una instancia RDS elegible para el free tier (por ejemplo, MySQL).
   - La base de datos se despliega en las subredes privadas.
---

## Cómo Ejecutar el Proyecto

Sigue estos pasos para desplegar la infraestructura:

### 1. **Clona el Repositorio**
   ```bash
   git clone https://github.com/ldavidflorez/terraform-aws-infra.git
   cd terraform-aws-infra
   ```

### 2. **Configura las Variables**
   - Crea un archivo `terraform.tfvars` en la raíz del proyecto con los siguientes valores:
     ```hcl
     aws_region      = "us-east-1"
     ami_id          = "ami-0c02fb55956c7d316" # Amazon Linux 2 en us-east-1
     key_pair_name   = "my-key-pair"
     db_username     = "admin"
     db_password     = "supersecurepassword"
     ```

### 3. **Inicializa Terraform**
   ```bash
   terraform init
   ```

### 4. **Revisa el Plan de Ejecución**
   ```bash
   terraform plan
   ```

### 5. **Aplica la Infraestructura**
   ```bash
   terraform apply
   ```

### 6. **Revisa los Outputs**
   Después de aplicar la infraestructura, Terraform mostrará los siguientes valores:
   - **IP pública de la instancia EC2**: Para conectarte por SSH.
   - **Endpoint de RDS**: Para conectarte a la base de datos.
   - **DNS name del ALB**: Para acceder a la aplicación a través del balanceador de carga.

---

## Detalles Técnicos

### User Data para la Instancia EC2

El archivo `user_data.sh` contiene el script que se ejecuta al iniciar la instancia EC2. Este script:
1. Instala Apache Server.
2. Crea una variable de entorno con un valor aleatorio.
3. Ejecuta un archivo index.html con el valor de RANDOM_VALUE (para verificar visualmente el funcionamiento del ALB).

```bash
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
```

### Métricas de CloudWatch

Se configuran alarmas de CloudWatch para monitorear el uso de CPU. Estas alarmas desencadenan acciones de escalado en el ASG.

---

## Limpieza de Recursos

Para eliminar toda la infraestructura creada y evitar costos innecesarios, ejecuta:

```bash
terraform destroy
```

---