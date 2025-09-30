# OpenVPN Access Server Docker Deployment

Este proyecto proporciona una configuración completa para desplegar OpenVPN Access Server usando Docker, basado en la documentación oficial de OpenVPN.

## 📋 Tabla de Contenidos

- [Características](#características)
- [Requisitos del Sistema](#requisitos-del-sistema)
- [Instalación Rápida](#instalación-rápida)
- [Configuración](#configuración)
- [Uso](#uso)
- [Administración](#administración)
- [Backup y Restauración](#backup-y-restauración)
- [Solución de Problemas](#solución-de-problemas)
- [Seguridad](#seguridad)
- [Referencias](#referencias)

## 🚀 Características

- **Despliegue con un comando**: Script automatizado de configuración
- **Configuración persistente**: Datos y configuraciones se mantienen entre reinicios
- **Seguridad robusta**: Configuración con privilegios mínimos necesarios
- **Monitoreo integrado**: Health checks y logging configurado
- **Multiplataforma**: Scripts para Linux/macOS y Windows PowerShell
- **Configuración flexible**: Variables de entorno para personalización fácil

## 📋 Requisitos del Sistema

### Software Requerido
- **Docker Engine** 20.10+ o **Docker Desktop**
- **Docker Compose** 2.0+ (o docker-compose 1.29+)
- **Puerto 943/tcp** disponible (Admin Web UI)
- **Puerto 1194/udp** disponible (OpenVPN)

### Requisitos de Hardware
- **RAM**: Mínimo 1GB, recomendado 2GB+
- **CPU**: 1 núcleo mínimo, 2+ recomendado
- **Almacenamiento**: 10GB libres mínimo
- **Red**: Acceso a internet para descargar imágenes

### Consideraciones de Red
- **IP Pública** o **Nombre de Dominio** (para acceso remoto)
- **Firewall** configurado para permitir puertos OpenVPN
- **NAT/Port Forwarding** configurado si está detrás de router

## ⚡ Instalación Rápida

### 1. Clonar o Descargar el Proyecto
```bash
# Si tienes git instalado
git clone <repository-url>
cd openvpn-docker

# O descargar y extraer el archivo ZIP
```

### 2. Ejecutar el Script de Configuración

#### En Linux/macOS:
```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

#### En Windows PowerShell:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\setup.ps1
```

### 3. Acceder a la Interfaz Web
- **Admin UI**: https://localhost:943/admin
- **Client UI**: https://localhost:943/
- **Usuario**: openvpn
- **Contraseña**: changeme123! (¡CAMBIAR INMEDIATAMENTE!)

## ⚙️ Configuración

### Variables de Entorno

Edita el archivo `.env` para personalizar tu instalación:

```bash
# Configuración del Servidor
SERVER_HOSTNAME=tu-servidor.com        # ¡IMPORTANTE! Cambia por tu IP/dominio público
ADMIN_PASSWORD=tu-contraseña-segura     # ¡CAMBIAR POR SEGURIDAD!

# Puertos
ADMIN_UI_PORT=943                       # Puerto de la interfaz de administración
OPENVPN_PORT=1194                       # Puerto del servidor OpenVPN

# Red VPN
VPN_NETWORK=192.168.255.0               # Red para clientes VPN
VPN_PROTOCOL=udp                        # Protocolo (udp/tcp)

# Recursos
MEMORY_LIMIT=1G                         # Límite de memoria
CPU_LIMIT=2.0                          # Límite de CPU
```

### Configuración Avanzada

#### Certificados SSL Personalizados
```bash
# Coloca tus certificados en:
./config/certs/server.crt
./config/certs/server.key

# Actualiza .env:
SSL_CERT_PATH=./config/certs/server.crt
SSL_KEY_PATH=./config/certs/server.key
```

#### DNS Personalizado
```bash
# En .env:
DNS_SERVERS=1.1.1.1,1.0.0.1            # Cloudflare DNS
# o
DNS_SERVERS=8.8.8.8,8.8.4.4            # Google DNS
```

## 📖 Uso

### Comandos Básicos

```bash
# Iniciar el servidor
docker-compose up -d

# Ver logs
docker logs openvpn-access-server

# Detener el servidor
docker-compose down

# Reiniciar el servidor
docker-compose restart

# Actualizar imagen
docker-compose pull && docker-compose up -d
```

### Configuración Inicial del Servidor

1. **Accede al Admin UI**: https://tu-servidor:943/admin
2. **Login inicial**: usuario `openvpn`, contraseña del `.env`
3. **Configurar red**:
   - Ve a `Configuration > Network Settings`
   - Configura tu hostname/IP público
   - Ajusta el rango de IPs para clientes
4. **Configurar usuarios**:
   - Ve a `User Management > User Permissions`
   - Crea usuarios VPN
   - Asigna permisos y grupos

### Crear Usuarios VPN

#### Método 1: Interfaz Web
1. Admin UI → `User Management` → `User Permissions`
2. Click `More Settings` junto al usuario
3. Marcar `Allow Access` y configurar opciones
4. Click `Save Settings`

#### Método 2: Línea de Comandos
```bash
# Entrar al contenedor
docker exec -it openvpn-access-server bash

# Crear usuario
/usr/local/openvpn_as/scripts/sacli --user "usuario1" --key "type" --value "user_connect"
/usr/local/openvpn_as/scripts/sacli --user "usuario1" --key "prop_autologin" --value "true"

# Establecer contraseña
/usr/local/openvpn_as/scripts/sacli --user "usuario1" SetLocalPassword
```

## 👨‍💼 Administración

### Interfaz de Administración

**URL**: https://tu-servidor:943/admin

#### Secciones Principales:
- **Status Overview**: Estado del servidor y conexiones activas
- **Network Settings**: Configuración de red y protocolos
- **VPN Settings**: Configuración específica de OpenVPN
- **User Management**: Administración de usuarios y permisos
- **Authentication**: Configuración de autenticación (LDAP, RADIUS, etc.)
- **Logging**: Configuración de logs y auditoría

### Monitoreo

#### Ver Conexiones Activas
```bash
# Dentro del contenedor
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli VPNStatus
```

#### Logs del Sistema
```bash
# Logs del contenedor
docker logs openvpn-access-server

# Logs específicos de OpenVPN
docker exec openvpn-access-server tail -f /var/log/openvpnas.log
```

#### Health Check
```bash
# Verificar estado del contenedor
docker ps
docker inspect openvpn-access-server
```

## 💾 Backup y Restauración

### Scripts de Backup

Ejecuta los scripts de backup incluidos:

```bash
# Backup completo
./scripts/backup.sh

# Backup solo configuración
./scripts/backup.sh --config-only

# Backup con compresión
./scripts/backup.sh --compress
```

### Backup Manual

```bash
# Crear directorio de backup
mkdir -p backups/$(date +%Y%m%d_%H%M%S)

# Backup de configuración
docker cp openvpn-access-server:/opt/openvpn-as/etc backups/$(date +%Y%m%d_%H%M%S)/

# Backup de datos
docker cp openvpn-access-server:/opt/openvpn-as/tmp backups/$(date +%Y%m%d_%H%M%S)/

# Backup de la base de datos
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli ConfigQuery > backups/$(date +%Y%m%d_%H%M%S)/config_backup.txt
```

### Restauración

```bash
# Detener el servidor
docker-compose down

# Restaurar configuración
docker cp backup_folder/etc/. openvpn-access-server:/opt/openvpn-as/etc/

# Reiniciar servidor
docker-compose up -d
```

## 🔧 Solución de Problemas

### Problemas Comunes

#### 1. El contenedor no inicia
```bash
# Verificar logs
docker logs openvpn-access-server

# Problemas de permisos
sudo chown -R 1000:1000 ./config ./data ./logs

# Verificar puertos en uso
netstat -tlnp | grep :943
netstat -ulnp | grep :1194
```

#### 2. No se puede acceder a la interfaz web
```bash
# Verificar firewall
sudo ufw allow 943/tcp
sudo ufw allow 1194/udp

# En Windows
netsh advfirewall firewall add rule name="OpenVPN-Admin" dir=in action=allow protocol=TCP localport=943
netsh advfirewall firewall add rule name="OpenVPN-Server" dir=in action=allow protocol=UDP localport=1194
```

#### 3. Clientes no pueden conectar
```bash
# Verificar routing
docker exec openvpn-access-server ip route

# Verificar iptables
docker exec openvpn-access-server iptables -L -n

# Verificar configuración de red
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli ConfigQuery | grep -E "host|port|proto"
```

#### 4. Rendimiento lento
```bash
# Aumentar límites de recursos en .env
MEMORY_LIMIT=2G
CPU_LIMIT=4.0

# Recrear contenedor
docker-compose down
docker-compose up -d
```

### Logs de Diagnóstico

```bash
# Log completo del sistema
docker exec openvpn-access-server tail -f /var/log/openvpnas.log

# Logs de conexiones
docker exec openvpn-access-server tail -f /var/log/openvpn.log

# Debug de configuración
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli ConfigQuery
```

### Comandos de Diagnóstico

```bash
# Estado del servicio
docker exec openvpn-access-server systemctl status openvpnas

# Información de red
docker exec openvpn-access-server ip addr show

# Prueba de conectividad
docker exec openvpn-access-server ping -c 4 8.8.8.8

# Verificar certificados
docker exec openvpn-access-server openssl x509 -in /opt/openvpn-as/etc/certs/server.crt -text -noout
```

## 🔒 Seguridad

### Mejores Prácticas

#### 1. Cambiar Credenciales Predeterminadas
```bash
# Editar .env
ADMIN_PASSWORD=una-contraseña-muy-segura
ADMIN_USERNAME=mi-admin-usuario
```

#### 2. Usar Certificados SSL Válidos
```bash
# Obtener certificado Let's Encrypt
certbot certonly --standalone -d tu-servidor.com

# Copiar certificados
cp /etc/letsencrypt/live/tu-servidor.com/fullchain.pem ./config/certs/server.crt
cp /etc/letsencrypt/live/tu-servidor.com/privkey.pem ./config/certs/server.key
```

#### 3. Configurar Firewall
```bash
# Ubuntu/Debian
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 943/tcp
sudo ufw allow 1194/udp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=943/tcp
sudo firewall-cmd --permanent --add-port=1194/udp
sudo firewall-cmd --reload
```

#### 4. Autenticación de Dos Factores
1. Admin UI → `Authentication` → `General`
2. Habilitar `Google Authenticator MFA`
3. Configurar usuarios para usar 2FA

#### 5. Limitar Acceso por IP
```bash
# En Admin UI → Authentication → General
# Configurar "Access Control" con rangos de IP permitidos
```

### Configuración de Seguridad Avanzada

```bash
# Deshabilitar protocolos inseguros
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli --key "vpn.server.tls_version_min" --value "1.2" ConfigPut

# Configurar cifrado fuerte
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli --key "vpn.server.cipher" --value "AES-256-GCM" ConfigPut

# Deshabilitar compresión (seguridad)
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli --key "vpn.server.comp_lzo" --value "no" ConfigPut
```

## 📚 Referencias

### Documentación Oficial
- [OpenVPN Access Server Docker Guide](https://openvpn.net/as-docs/docker.html)
- [OpenVPN Docker Hub](https://hub.docker.com/r/openvpn/openvpn-as)
- [OpenVPN Access Server Documentation](https://openvpn.net/as-docs/)

### Recursos Adicionales
- [Docker Official Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [OpenVPN Community](https://community.openvpn.net/)

### Soporte y Comunidad
- [OpenVPN Support](https://support.openvpn.com/)
- [Docker Community Forums](https://forums.docker.com/)
- [Stack Overflow - OpenVPN](https://stackoverflow.com/questions/tagged/openvpn)

---

## 📄 Licencia

Este proyecto está disponible bajo la licencia MIT. Consulta el archivo `LICENSE` para más detalles.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## ⚠️ Disclaimer

Este proyecto es para fines educativos y de práctica. Para uso en producción, asegúrate de seguir todas las mejores prácticas de seguridad y cumplir con las regulaciones locales.