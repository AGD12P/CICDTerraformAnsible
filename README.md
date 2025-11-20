# Proyecto GitOps-Terraform-Ansible

La infraestructura desplegada en AWS incluye los siguientes componentes:

- **Application Load Balancer (ALB)**: Distribuye el tráfico entrante entre las instancias EC2.
- **AutoScaling Group (ASG)**: Se encarga de gestionar el escalado automático de las instancias EC2, asegurando alta disponibilidad.
- **RDS PostgreSQL**: Base de datos desplegada en 2 subredes privadas y 2 az distintas.
- **NAT Gateway**: Permite el acceso a Internet para las instancias en la subred privada (usado por RDS).
- **GitHub Actions CI/CD Pipeline**: Automáticamente ejecuta Terraform para crear la infraestructura y luego Ansible para configurar las instancias.
