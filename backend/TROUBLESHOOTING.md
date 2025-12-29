# Guía de Troubleshooting - Backend en Digital Ocean

## Problema: Las playlists no se transfieren desde la app móvil

### 1. Verificar que el servidor está corriendo

En tu servidor SSH, ejecuta:
```bash
docker ps
```

Deberías ver un contenedor llamado `music-transfer-backend` con estado `Up`.

### 2. Ver los logs en tiempo real

Desde la carpeta `/root/personal-transfer-music/backend`, ejecuta:
```bash
docker compose logs -f
```

Esto te mostrará todos los logs del servidor. Mantén esta ventana abierta mientras usas la app móvil para ver si llegan las peticiones.

**¿Qué deberías ver cuando la app hace una petición?**
- Líneas que empiecen con la IP de tu teléfono
- El método HTTP (GET, POST) y la ruta (ej: `/transfer-all`, `/playlists`)
- El código de respuesta (200, 400, 500, etc.)

Ejemplo:
```
192.168.1.100 - - [29/Dec/2024 15:30:45] "POST /playlists HTTP/1.1" 200 -
```

### 3. Verificar conectividad básica

**Desde tu teléfono móvil:**
Abre el navegador y ve a: `http://134.199.211.130`

Deberías ver: `{"message": "Server Online"}`

Si no ves esto, hay un problema de red o firewall.

### 4. Revisar configuración de CORS

El backend necesita permitir peticiones desde tu app móvil. Verifica tu archivo `.env` en el servidor:

```bash
cat /root/personal-transfer-music/backend/.env
```

**Problema común:** La variable `FRONTEND_URL` podría estar bloqueando las peticiones.

**Solución:** Edita el `.env`:
```bash
nano /root/personal-transfer-music/backend/.env
```

Y asegúrate de que `FRONTEND_URL` esté configurado correctamente o comentado:
```
# FRONTEND_URL=http://localhost:3000
```

Si haces cambios, reinicia el contenedor:
```bash
docker compose restart
```

### 5. Verificar que la app tiene la IP correcta

En tu código Flutter (`android/lib/config/app_config.dart`), verifica:
```dart
static const String apiBaseUrl = 'http://134.199.211.130';
```

**IMPORTANTE:** No debe tener puerto (`:8080`) ni barra al final (`/`).

### 6. Probar endpoints manualmente

Desde tu computadora local, prueba hacer una petición:

```bash
curl http://134.199.211.130/
```

Deberías recibir: `{"message":"Server Online"}`

### 7. Firewall de Digital Ocean

Verifica que el puerto 80 esté abierto en el firewall de Digital Ocean:
1. Ve al panel de Digital Ocean
2. Networking → Firewalls
3. Asegúrate de que el puerto 80 (HTTP) esté permitido para "All IPv4" y "All IPv6"

### 8. Logs detallados del contenedor

Si necesitas ver logs más antiguos:
```bash
docker compose logs --tail 100
```

Para ver solo errores:
```bash
docker compose logs | grep -i error
```

### 9. Reiniciar el servidor completamente

Si nada funciona, reinicia todo:
```bash
docker compose down
docker compose up -d --build
```

### 10. Verificar autenticación de Spotify

Si las peticiones llegan pero fallan, puede ser un problema de autenticación:

1. Ve al [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Selecciona tu app
3. Settings → Redirect URIs
4. Asegúrate de tener: `http://134.199.211.130/auth/callback`

## Comandos útiles de Docker

```bash
# Ver contenedores corriendo
docker ps

# Ver logs en tiempo real
docker compose logs -f

# Ver logs de las últimas 50 líneas
docker compose logs --tail 50

# Reiniciar el contenedor
docker compose restart

# Detener y eliminar todo
docker compose down

# Reconstruir y arrancar
docker compose up -d --build

# Entrar al contenedor (para debugging avanzado)
docker exec -it music-transfer-backend bash
```

## Checklist rápido

- [ ] El servidor responde en `http://134.199.211.130`
- [ ] Los logs muestran peticiones cuando uso la app
- [ ] El `.env` tiene las credenciales correctas
- [ ] `FRONTEND_URL` no está bloqueando peticiones
- [ ] La app tiene `apiBaseUrl = 'http://134.199.211.130'`
- [ ] El firewall permite el puerto 80
- [ ] Spotify tiene el redirect URI correcto
