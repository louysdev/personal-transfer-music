# Guía de Despliegue en Digital Ocean

Esta guía te ayudará a desplegar tu backend en un Droplet de Digital Ocean de la forma más económica posible ($4/mes).

## 1. Crear el Droplet (Servidor Virtual)

1. Ve a tu panel de Digital Ocean y haz clic en **Create -> Droplets**.
2. **Region**: Elige la más cercana a ti (ej. New York o San Francisco).
3. **OS**: Elige **Ubuntu 24.04 (LTS) x64**.
4. **Droplet Type**: "Basic".
5. **CPU Options**: "Regular".
6. **Price**: Selecciona la opción de **$4/mo** (512MB RAM, 1 CPU, 10GB SSD). Es suficiente para este backend.
7. **Authentication**: Selecciona "SSH Key" (recomendado) o "Password".
8. **Hostname**: Ponle un nombre fácil, ej: `music-backend`.
9. Haz clic en **Create Droplet**.

## 2. Conectarse al Servidor

Una vez creado, copia la IP de tu Droplet. Abre tu terminal y ejecuta:

```bash
ssh root@TU_IP_DEL_DROPLET
```

(Si usaste password, te lo pedirá. Si usaste SSH Key, entrarás directo).

## 3. Instalar Docker

Una vez dentro del servidor, ejecuta estos comandos uno por uno para instalar Docker:

```bash
apt update
apt install -y docker.io docker-compose-v2
```

## 4. Subir tu Código

Desde **tu computadora local** (no en el servidor), navega a la carpeta de tu proyecto (`/Users/laetus/Desktop/Herramientas/personal-transfer-music`) y copia la carpeta `backend` al servidor usando `scp`.

Ejecuta este comando en tu terminal local (reemplaza `TU_IP` con la IP real):

```bash
scp -r backend root@TU_IP:/root/
```

> **Nota:** Si tienes un archivo `.env` local con tus credenciales, asegúrate de que se copie o créalo en el servidor. El comando anterior copiará todo en la carpeta backend.

### Configuración del .env en Producción

Es **CRÍTICO** que actualices tu archivo `.env` en el servidor para que funcione con la nueva IP.
Puedes editarlo en el servidor con `nano .env`:

1. **REDIRECT_URI**: Debe apuntar a tu nueva IP.
   `REDIRECT_URI=http://TU_IP_DEL_DROPLET/auth/callback`
   (Nota: Ya no lleva el puerto 8080, porque Docker lo expone en el puerto 80 por defecto).

2. **FRONTEND_URL**: Si tu app móvil espera conectarse a esta IP, asegúrate de actualizar esta variable si la usas para validaciones en tu app.

## 5. Desplegar

Vuelve a tu terminal SSH conectada al servidor. Ve a la carpeta que acabas de subir:

```bash
cd backend
```

Da permisos de ejecución al script de instalación y ejecútalo:

```bash
chmod +x setup_server.sh
./setup_server.sh
```

Este script:
1. Creará los archivos JSON necesarios (vacíos) si no existen.
2. Verificará que tengas un archivo `.env`.
3. Construirá y arrancará el contenedor Docker.

## 6. Verificar

Tu backend estará corriendo en el puerto 80. Puedes probarlo visitando en tu navegador:

`http://TU_IP_DEL_DROPLET`

You should not modify the provided arguments.
Deberías ver `{"message": "Server Online"}`.

## 7. Configurar la App Móvil

Una vez que tengas tu backend corriendo y sepas tu IP (ej: `142.93.xxx.xxx`), debes actualizar tu aplicación Flutter para que apunte a este nuevo servidor.

1. Abre el archivo `android/lib/config/app_config.dart`.
2. Actualiza la variable `apiBaseUrl`:

```dart
static const String apiBaseUrl = 'http://TU_IP_DEL_DROPLET';
```

(Reemplaza `TU_IP_DEL_DROPLET` por la IP real de tu servidor).

## Actualizaciones Futuras

Si haces cambios en el código:
1. Copia los archivos actualizados con `scp`.
2. En el servidor, ejecuta: `docker-compose up -d --build`.
