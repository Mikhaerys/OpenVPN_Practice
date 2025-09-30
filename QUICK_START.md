# 🚀 Guía de Inicio Rápido - OpenVPN Docker

## Prerequisitos
- Docker Desktop instalado
- Puerto 943 y 1194 disponibles
- Acceso de administrador

## Instalación en 3 Pasos

### 1. Configurar el Proyecto
```bash
# En Windows PowerShell (como Administrador)
cd m:\Work\Universidad\ServiTelematicos\VPN_Practice\openvpn-docker
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\setup.ps1
```

```bash
# En Linux/macOS
cd openvpn-docker
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### 2. Personalizar Configuración
Edita el archivo `.env`:
```bash
# IMPORTANTE: Cambiar estas configuraciones
SERVER_HOSTNAME=tu-ip-publica-o-dominio.com
ADMIN_PASSWORD=tu-contraseña-segura
```

### 3. Reiniciar para Aplicar Cambios
```bash
docker-compose restart
```

## Acceso Inmediato

### Interfaz de Administración
- **URL**: https://localhost:943/admin
- **Usuario**: openvpn
- **Contraseña**: (la que configuraste en .env)

### Interfaz de Cliente
- **URL**: https://localhost:943/

## Primeros Pasos Después de la Instalación

### 1. Configuración Inicial del Servidor
1. Accede al Admin UI
2. Ve a `Configuration > Network Settings`
3. Actualiza el hostname con tu IP/dominio público
4. Configura el rango de IPs para clientes VPN

### 2. Crear Usuarios VPN
```bash
# Método 1: Línea de comandos
make add-user USERNAME=juan

# Método 2: Interfaz web
# Admin UI → User Management → User Permissions
```

### 3. Descargar Configuración de Cliente
1. Cliente se conecta a https://tu-servidor:943/
2. Descarga el perfil de conexión
3. Importa en OpenVPN Connect

## Comandos Útiles

```bash
# Ver estado del servidor
make status

# Ver logs en tiempo real
make logs-follow

# Crear backup
make backup

# Reiniciar servidor
make restart

# Listar usuarios
make list-users
```

## Solución de Problemas Rápida

### No puedo acceder a la interfaz web
```bash
# Verificar que el contenedor esté ejecutándose
docker ps

# Verificar logs
docker logs openvpn-access-server

# Verificar firewall (Windows)
netsh advfirewall firewall add rule name="OpenVPN" dir=in action=allow protocol=TCP localport=943
```

### Los clientes no pueden conectar
1. Verificar que `SERVER_HOSTNAME` en `.env` sea tu IP pública
2. Abrir puerto 1194/UDP en tu router/firewall
3. Verificar que el cliente use el protocolo correcto (UDP/TCP)

### Olvidé la contraseña de admin
```bash
make reset-admin PASSWORD=nueva-contraseña
```

## ¿Necesitas Ayuda?
- Revisa el README.md completo para documentación detallada
- Ejecuta `make health-check` para diagnóstico automático
- Revisa logs con `make logs-follow`

---
¡Listo! Tu servidor OpenVPN debería estar funcionando. 🎉