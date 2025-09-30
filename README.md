# OpenVPN Access Server Docker Deployment

Este proyecto proporciona una configuración completa para desplegar OpenVPN Access Server usando Docker, basado en la documentación oficial de OpenVPN.

## 📋 Tabla de Contenidos

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación y Configuración](#instalación-y-configuración)
- [Uso Básico](#uso-básico)
- [Administración Web](#administración-web)
- [Gestión de Usuarios VPN](#gestión-de-usuarios-vpn)
- [Solución de Problemas](#solución-de-problemas)
- [Seguridad](#seguridad)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Referencias](#referencias)

## 📋 Requisitos

### Software Requerido
- **Docker Desktop para Windows** (versión reciente)
- **Puertos disponibles**:
  - `943` - Interfaz web de administración y cliente (HTTPS)
  - `1194/udp` - Servidor OpenVPN (puerto por defecto)

### Recursos del Sistema
- **RAM**: Mínimo 512MB disponibles
- **CPU**: 1 núcleo disponible
- **Almacenamiento**: 2GB libres para el contenedor y datos

### Privilegios del Sistema
- **Docker con privilegios**: El contenedor requiere privilegios especiales para funcionar:
  - `NET_ADMIN` - Capacidades de administración de red
  - `MKNOD` - Crear nodos de dispositivo
  - Acceso a `/dev/net/tun` - Dispositivo TUN para tráfico VPN
  - (Ya están configurados en el `docker-compose.yml`)

## ⚡ Instalación y Configuración

### 1. Clonar o Descargar el Proyecto
```bash
# Si tienes git instalado
git clone <repository-url>
cd openvpn-docker

# O descargar y extraer el archivo ZIP
```

### 2. Iniciar el Servidor OpenVPN
```powershell
# Iniciar el contenedor en segundo plano
docker-compose up -d

# Verificar que esté ejecutándose
docker ps
```

### 3. Verificar el Estado
```powershell
# Ver logs para confirmar que inició correctamente
docker logs openvpn-access-server

# El servidor estará listo cuando veas:
# "Server Agent started"
# "License Info {'concurrent_connections': 2..."
```

## 🖥️ Uso Básico

### Comandos Principales

```powershell
# ▶️ Iniciar el servidor
docker-compose up -d

# ⏸️ Detener el servidor
docker-compose down

# 🔄 Reiniciar el servidor
docker-compose restart

# 📋 Ver estado del contenedor
docker ps | findstr openvpn-access-server

# 📝 Ver logs en tiempo real
docker logs -f openvpn-access-server

# 📊 Ver uso de recursos
docker stats openvpn-access-server --no-stream

# 🔄 Actualizar a la última versión
docker-compose pull
docker-compose up -d
```

### Verificar Conectividad

```powershell
# Verificar puerto web (943)
Test-NetConnection -ComputerName localhost -Port 943

# Verificar puerto VPN (1194) 
Test-NetConnection -ComputerName localhost -Port 1194
```

## 🌐 Administración Web

### Acceso a las Interfaces

Una vez que el servidor esté ejecutándose:

- **🔧 Interfaz de Administración**: https://localhost:943/admin
- **👤 Interfaz de Cliente**: https://localhost:943/

### Configuración Inicial

#### 1. Primer Acceso al Admin
1. Navegar a: https://localhost:943/admin
3. **Contraseña**: Busca la contraseña temporal generada en los logs del contenedor. Ejecuta:

```powershell
docker logs -f openvpn-access-server
```

En la salida, localiza la línea que dice:  
`Auto-generated pass = "<contraseña>". Setting in db...`

Usa esa contraseña junto con el usuario `openvpn` para iniciar sesión en la interfaz de administración.
4. Aceptar el acuerdo de licencia de End User License Agreement (EULA)

#### 2. Configuración Básica del Servidor
1. **Network Settings** → **IMPORTANTE**: Actualizar hostname/IP público para acceso remoto
   - Ir a `Configuration` → `Network Settings`
   - Cambiar `Hostname or IP Address` de `localhost` a tu IP pública o dominio
   - Esto es crítico para que los clientes puedan conectarse remotamente
2. **VPN Settings** → Ajustar protocolos y puertos si es necesario
3. **User Management** → Crear usuarios VPN

#### 3. Configuración de Red (Opcional)
- **Red VPN**: Se asigna automáticamente (típicamente 192.168.255.x)
- **DNS**: Usa servidores DNS del sistema por defecto
- **Routing**: Configuración automática para acceso a internet

## 👥 Gestión de Usuarios VPN

### Crear Usuarios desde la Interfaz Web

1. **Admin UI** → `User Management` → `User Permissions`
2. Buscar el usuario en la lista (inicialmente estará `openvpn`)
3. Click en **More Settings** junto al usuario deseado  
4. **Allow Access**: ✅ Marcar para habilitar VPN
5. **Auto-login**: ✅ Marcar para facilitar conexión
6. Click **Save Settings**

### Crear Usuarios Adicionales

```powershell
# Acceder al contenedor para comandos avanzados
docker exec -it openvpn-access-server bash

# Crear nuevo usuario (dentro del contenedor)
/usr/local/openvpn_as/scripts/sacli --user "usuario1" --key "type" --value "user_connect"
/usr/local/openvpn_as/scripts/sacli --user "usuario1" --key "prop_autologin" --value "true"
/usr/local/openvpn_as/scripts/sacli start

# Salir del contenedor
exit
```

### Descargar Perfiles de Cliente

1. **Cliente navega a**: https://localhost:943/
2. **Login con credenciales** del usuario VPN
3. **Descargar**: 
   - `client.ovpn` - Para OpenVPN Connect u otros clientes
   - Instalador específico para la plataforma

## 🔧 Solución de Problemas

### Problemas Comunes

#### ❌ El contenedor no inicia
```powershell
# Verificar Docker
docker info

# Ver logs detallados
docker logs openvpn-access-server

# Verificar puertos en uso
netstat -an | findstr ":943"
netstat -an | findstr ":1194"

# Reiniciar Docker Desktop si es necesario
```

#### ❌ No puedo acceder a https://localhost:943
```powershell
# Verificar que el contenedor esté corriendo
docker ps

# Verificar logs del contenedor
docker logs openvpn-access-server --tail 50

# Asegurarse de usar HTTPS (no HTTP)
# Aceptar certificado auto-firmado en el navegador
```

#### ❌ Clientes VPN no pueden conectar

**Verificar configuración:**
```powershell
# Entrar al contenedor para diagnóstico
docker exec -it openvpn-access-server bash

# Verificar configuración de red
ip route
iptables -L -n

# Verificar procesos OpenVPN
ps aux | grep openvpn
```

**Para acceso remoto:**
1. **Router**: Abrir puerto 1194/UDP 
2. **Firewall Windows**: Permitir puerto 1194/UDP
3. **Hostname**: Actualizar en Admin UI con IP pública

#### ❌ Problemas de rendimiento
```powershell
# Ver uso de recursos
docker stats openvpn-access-server

# Reiniciar si es necesario
docker-compose restart

# Verificar logs por errores
docker logs openvpn-access-server | findstr -i error
```

### Comandos de Diagnóstico

```powershell
# Estado completo del sistema
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli VPNStatus

# Información de configuración
docker exec openvpn-access-server /usr/local/openvpn_as/scripts/sacli ConfigQuery

# Test de conectividad
docker exec openvpn-access-server ping -c 4 8.8.8.8
```

## 🔒 Seguridad

### Configuración Básica de Seguridad

#### 1. Cambiar Contraseña por Defecto
- Acceder al Admin UI inmediatamente después de la instalación
- Configurar una contraseña fuerte para el usuario `openvpn`

#### 2. Firewall de Windows
```powershell
# Permitir puertos OpenVPN (ejecutar como Administrador)
netsh advfirewall firewall add rule name="OpenVPN-Admin" dir=in action=allow protocol=TCP localport=943
netsh advfirewall firewall add rule name="OpenVPN-Server" dir=in action=allow protocol=UDP localport=1194
```

#### 3. Para Uso en Producción
- **Certificados SSL**: Reemplazar certificado auto-firmado
- **Hostname público**: Configurar dominio o IP pública válida
- **Backup regular**: De la configuración y usuarios
- **Monitoring**: Supervisar conexiones y logs regularmente

### Configuraciones de Seguridad Avanzada

```powershell
# Acceder al contenedor para configuraciones avanzadas
docker exec -it openvpn-access-server bash

# Dentro del contenedor:
# Configurar cifrado fuerte
/usr/local/openvpn_as/scripts/sacli --key "vpn.server.cipher" --value "AES-256-GCM" ConfigPut

# TLS mínimo
/usr/local/openvpn_as/scripts/sacli --key "vpn.server.tls_version_min" --value "1.2" ConfigPut

# Aplicar cambios
/usr/local/openvpn_as/scripts/sacli start
```

## 📁 Estructura del Proyecto

```
VPN_Practice/
├── docker-compose.yml    # ✅ Configuración principal (ultra-simple)
├── README.md             # ✅ Esta documentación
├── LICENSE               # ✅ Licencia del proyecto
├── config/               # ✅ Configuraciones persistentes (auto-creado)
├── data/                 # ✅ Datos del servidor (auto-creado)
└── logs/                 # ✅ Logs del sistema (auto-creado)
```

### Descripción de Archivos

- **`docker-compose.yml`**: Única configuración necesaria, sin variables complejas
- **Directorios de datos**: Creados automáticamente por Docker con permisos correctos
- **Volumen `openvpn-data`**: Almacena toda la configuración persistente del servidor

## 💾 Backup y Mantenimiento

### Crear Backup Manual

```powershell
# Crear directorio de backup
mkdir backups
$backup_date = Get-Date -Format "yyyyMMdd_HHmmss"
mkdir "backups\$backup_date"

# Backup del volumen completo
docker run --rm -v vpn_practice_openvpn-data:/data -v "${PWD}\backups\$backup_date:/backup" alpine tar czf /backup/openvpn-data.tar.gz -C /data .

# Backup de configuración específica
docker exec openvpn-access-server tar czf - /opt/openvpn-as/etc > "backups\$backup_date\config.tar.gz"
```

### Restaurar Backup

```powershell
# Detener servidor
docker-compose down

# Restaurar volumen
docker run --rm -v vpn_practice_openvpn-data:/data -v "${PWD}\backups\FECHA:/backup" alpine tar xzf /backup/openvpn-data.tar.gz -C /data

# Reiniciar servidor
docker-compose up -d
```

## 🔄 Actualización

```powershell
# Obtener la última imagen
docker-compose pull

# Recrear contenedor con nueva imagen
docker-compose up -d

# Verificar versión actualizada
docker logs openvpn-access-server | Select-String "version"
```

## 📚 Referencias

### Documentación Oficial
- **[OpenVPN Access Server Docker](https://hub.docker.com/r/openvpn/openvpn-as)** - Imagen oficial
- **[OpenVPN AS Documentation](https://openvpn.net/as-docs/)** - Documentación completa
- **[Docker Compose Reference](https://docs.docker.com/compose/)** - Referencia de Docker Compose

### Soporte y Comunidad
- **[OpenVPN Community Forums](https://forums.openvpn.net/)** - Foros de la comunidad
- **[Docker Community](https://www.docker.com/community/)** - Soporte de Docker

---

## ⚠️ Notas Importantes

- **Licencia**: OpenVPN AS permite 2 conexiones simultáneas gratuitas
- **Producción**: Para más conexiones, se requiere licencia comercial de OpenVPN
- **Privilegios Docker**: Requiere `NET_ADMIN`, `MKNOD` y acceso a `/dev/net/tun` (ya configurado en docker-compose.yml)
- **Seguridad**: Cambiar contraseñas por defecto inmediatamente
- **Acceso remoto**: Configurar firewall y router apropiadamente
- **IP Pública**: Para acceso remoto, se recomienda tener una IP pública o nombre de dominio
