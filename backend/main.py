from flask import Flask, request, redirect, session, jsonify
from flask_cors import CORS
from ytm import create_ytm_playlist, transfer_all_playlists, delete_all_ytm_playlists, transfer_selected_tracks, get_ytm_playlists, delete_selected_ytm_playlists
from spotify import get_user_playlists, get_playlist_tracks_by_id
import os
import secrets
import urllib.parse
import threading
import requests
from dotenv import load_dotenv
from apscheduler.schedulers.background import BackgroundScheduler
from token_manager import (
    save_spotify_tokens, 
    save_youtube_headers,
    save_youtube_oauth,
    get_spotify_access_token, 
    get_youtube_headers,
    get_youtube_oauth,
    has_valid_credentials
)

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', secrets.token_hex(16))

CORS(app, resources={
    r"/*" : {
        "origins": [os.getenv('FRONTEND_URL')],
        "methods" : ["POST", "GET"],
        "supports_credentials": True
    }
})

# Almacenamiento en memoria del progreso de transferencia
transfer_progress = {}

# Almacenamiento en memoria de transferencias canceladas
cancelled_transfers = set()

# Almacenamiento en memoria del progreso de eliminación
delete_progress = {}

# Almacenamiento en memoria de eliminaciones canceladas
cancelled_deletions = set()

# Scheduler para sincronización automática
scheduler = BackgroundScheduler()
auto_sync_enabled = False


@app.route('/auth/google', methods=['POST'])
def google_auth():
    """
    Intercambia el server auth code de Google por tokens.
    """
    data = request.get_json()
    code = data.get('code')
    
    if not code:
        return {"message": "Authorization code is required"}, 400
        
    try:
        # Intercambiar código por tokens
        token_url = "https://oauth2.googleapis.com/token"
        
        client_id = os.getenv('GOOGLE_CLIENT_ID')
        client_secret = os.getenv('GOOGLE_CLIENT_SECRET')
        
        payload = {
            'client_id': client_id,
            'client_secret': client_secret,
            'code': code,
            'grant_type': 'authorization_code',
            'redirect_uri': ''  # Para flujo Android/iOS -> Backend no se suele requerir URI
        }
        
        response = requests.post(token_url, data=payload)
        
        if response.status_code != 200:
            return {"message": f"Failed to exchange code: {response.text}"}, 400
            
        token_data = response.json()
        
        # Guardar tokens
        save_youtube_oauth(token_data)
        
        return {"message": "Google authentication successful", "authenticated": True}, 200
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        return {"message": f"Error authenticating with Google: {str(e)}"}, 500


@app.route('/create', methods=['POST'])
def create_playlist():
    data = request.get_json()
    playlist_link = data.get('playlist_link')
    auth_headers = data.get('auth_headers')
    
    # Guardar headers de YouTube Music si se proporcionan
    if auth_headers:
        save_youtube_headers(auth_headers)
    
    try:
        missed_tracks = create_ytm_playlist(playlist_link, auth_headers)
        return {"message": "Playlist created successfully!",
                "missed_tracks": missed_tracks
        }, 200
    except Exception as e:
        return {"message": str(e)}, 500


@app.route('/playlists', methods=['POST'])
def get_playlists():
    """
    Obtiene todas las playlists del usuario de Spotify.
    Requiere el token de acceso OAuth del usuario.
    """
    data = request.get_json() if request.data else {}
    spotify_token = data.get('spotify_token')
    
    # Si no se proporciona token, intentar obtenerlo de la sesión
    if not spotify_token:
        spotify_token = session.get('spotify_token')
    
    if not spotify_token:
        return {"message": "Spotify access token is required"}, 400
    
    try:
        playlists = get_user_playlists(spotify_token)
        return {
            "message": "Playlists retrieved successfully",
            "playlists": playlists,
            "count": len(playlists)
        }, 200
    except Exception as e:
        return {"message": str(e)}, 500


@app.route('/playlist-tracks/<playlist_id>', methods=['GET'])
def get_playlist_tracks(playlist_id):
    """
    Obtiene las canciones de una playlist específica de Spotify.
    """
    try:
        tracks = get_playlist_tracks_by_id(playlist_id)
        return {
            "message": "Tracks retrieved successfully",
            "tracks": tracks,
            "count": len(tracks)
        }, 200
    except Exception as e:
        return {"message": str(e)}, 500


@app.route('/transfer-all', methods=['POST'])
def transfer_all():
    """
    Transfiere todas las playlists de Spotify a YouTube Music.
    Requiere el token de Spotify y autenticación de YouTube Music (headers u OAuth).
    """
    data = request.get_json() if request.data else {}
    spotify_token = data.get('spotify_token')
    auth_headers = data.get('auth_headers')
    playlist_ids = data.get('playlist_ids')  # Lista opcional de IDs específicos
    
    # Si no se proporciona token, intentar obtenerlo de la sesión
    if not spotify_token:
        spotify_token = session.get('spotify_token')
    
    if not spotify_token:
        return {"message": "Spotify access token is required"}, 400
    
    # Si se proporcionan headers, guardarlos
    if auth_headers:
        save_youtube_headers(auth_headers)
    
    # Verificar si tenemos alguna forma de autenticación para YouTube
    if not auth_headers and not get_youtube_headers() and not get_youtube_oauth():
         return {"message": "YouTube Music authentication is required"}, 400
    
    try:
        # Obtener todas las playlists del usuario
        all_playlists = get_user_playlists(spotify_token)
        
        # Si se especifican IDs, filtrar solo esas playlists
        if playlist_ids and len(playlist_ids) > 0:
            playlists = [p for p in all_playlists if p["id"] in playlist_ids]
        else:
            playlists = all_playlists
        
        if len(playlists) == 0:
            return {"message": "No playlists found in Spotify account"}, 404
        
        # Generar ID único para esta transferencia
        transfer_id = secrets.token_urlsafe(16)
        
        # Inicializar progreso
        transfer_progress[transfer_id] = {
            "status": "in_progress",
            "total_playlists": len(playlists),
            "processed": 0,
            "successful": 0,
            "failed": 0,
            "skipped": 0,
            "playlists": [{"name": p["name"], "status": "pending", "id": p["id"], "image": p.get("image")} for p in playlists]
        }
        
        # Ejecutar transferencia en background
        def transfer_in_background():
            try:
                results = transfer_all_playlists(playlists, auth_headers, transfer_id, transfer_progress, cancelled_transfers)
                if transfer_id not in cancelled_transfers:
                    transfer_progress[transfer_id] = results
                    transfer_progress[transfer_id]["status"] = "completed"
            except Exception as e:
                if transfer_id not in cancelled_transfers:
                    transfer_progress[transfer_id]["status"] = "error"
                    transfer_progress[transfer_id]["error"] = str(e)
        
        thread = threading.Thread(target=transfer_in_background)
        thread.daemon = True
        thread.start()
        
        return {
            "message": "Transfer started",
            "transfer_id": transfer_id,
            "total_playlists": len(playlists)
        }, 202
    except Exception as e:
        return {"message": str(e)}, 500


@app.route('/transfer-status/<transfer_id>', methods=['GET'])
def get_transfer_status(transfer_id):
    """
    Obtiene el estado actual de una transferencia en progreso.
    """
    if transfer_id not in transfer_progress:
        return {"message": "Transfer not found"}, 404
    
    return transfer_progress[transfer_id], 200


@app.route('/transfer-cancel/<transfer_id>', methods=['POST'])
def cancel_transfer(transfer_id):
    """
    Cancela una transferencia en progreso.
    """
    if transfer_id not in transfer_progress:
        return {"message": "Transfer not found"}, 404
    
    # Marcar la transferencia como cancelada
    cancelled_transfers.add(transfer_id)
    transfer_progress[transfer_id]["status"] = "cancelled"
    
    return {"message": "Transfer cancelled", "transfer_id": transfer_id}, 200


@app.route('/transfer-selected', methods=['POST'])
def transfer_selected():
    """
    Transfiere playlists con canciones seleccionadas específicas a YouTube Music.
    """
    data = request.get_json() if request.data else {}
    auth_headers = data.get('auth_headers')
    playlists_data = data.get('playlists', [])
    
    # Si se proporcionan headers, guardarlos
    if auth_headers:
        save_youtube_headers(auth_headers)
        
    # Verificar si tenemos alguna forma de autenticación para YouTube
    if not auth_headers and not get_youtube_headers() and not get_youtube_oauth():
         return {"message": "YouTube Music authentication is required"}, 400
    
    if not playlists_data or len(playlists_data) == 0:
        return {"message": "No playlists with tracks provided"}, 400
    
    try:
        # Generar ID único para esta transferencia
        transfer_id = secrets.token_urlsafe(16)
        
        # Inicializar progreso
        transfer_progress[transfer_id] = {
            "status": "in_progress",
            "total_playlists": len(playlists_data),
            "processed": 0,
            "successful": 0,
            "failed": 0,
            "skipped": 0,
            "playlists": [{"name": p["name"], "status": "pending", "id": p.get("id", ""), "image": p.get("image")} for p in playlists_data]
        }
        
        # Ejecutar transferencia en background
        def transfer_in_background():
            try:
                results = transfer_selected_tracks(playlists_data, auth_headers, transfer_id, transfer_progress, cancelled_transfers)
                if transfer_id not in cancelled_transfers:
                    transfer_progress[transfer_id] = results
                    transfer_progress[transfer_id]["status"] = "completed"
            except Exception as e:
                if transfer_id not in cancelled_transfers:
                    transfer_progress[transfer_id]["status"] = "error"
                    transfer_progress[transfer_id]["error"] = str(e)
        
        thread = threading.Thread(target=transfer_in_background)
        thread.daemon = True
        thread.start()
        
        return {
            "message": "Transfer started",
            "transfer_id": transfer_id,
            "total_playlists": len(playlists_data)
        }, 202
    except Exception as e:
        return {"message": str(e)}, 500


@app.route('/delete-all-playlists', methods=['POST'])
def delete_all_playlists():
    """
    Elimina todas las playlists de YouTube Music del usuario.
    Usa headers guardados o los proporcionados.
    """
    global delete_progress
    
    data = request.get_json() if request.data else {}
    auth_headers = data.get('auth_headers')
    
    # Si se proporcionan headers, guardarlos
    if auth_headers:
        save_youtube_headers(auth_headers)
        
    # Verificar si tenemos alguna forma de autenticación para YouTube
    if not auth_headers and not get_youtube_headers() and not get_youtube_oauth():
         return {"message": "YouTube Music authentication is required"}, 400
    
    try:
        # Generar ID único para esta eliminación
        delete_id = secrets.token_urlsafe(16)
        
        # Inicializar progreso
        delete_progress[delete_id] = {
            "status": "in_progress",
            "total_playlists": 0,
            "deleted": 0,
            "failed": 0,
            "playlists": []
        }
        
        # Ejecutar eliminación en background
        def delete_in_background():
            try:
                results = delete_all_ytm_playlists(auth_headers, delete_progress, delete_id)
                delete_progress[delete_id] = results
                delete_progress[delete_id]["status"] = "completed"
            except Exception as e:
                delete_progress[delete_id]["status"] = "error"
                delete_progress[delete_id]["error"] = str(e)
        
        thread = threading.Thread(target=delete_in_background)
        thread.daemon = True
        thread.start()
        
        return {
            "message": "Deletion started",
            "delete_id": delete_id
        }, 202
    except Exception as e:
        return {"message": str(e)}, 500


@app.route('/delete-status/<delete_id>', methods=['GET'])
def get_delete_status(delete_id):
    """
    Obtiene el estado actual de una eliminación en progreso.
    """
    if delete_id not in delete_progress:
        return {"message": "Delete operation not found"}, 404
    
    return delete_progress[delete_id], 200


@app.route('/delete-cancel/<delete_id>', methods=['POST'])
def cancel_deletion(delete_id):
    """
    Cancela una eliminación en progreso.
    """
    if delete_id not in delete_progress:
        return {"message": "Delete operation not found"}, 404
    
    cancelled_deletions.add(delete_id)
    delete_progress[delete_id]["status"] = "cancelled"
    
    return {"message": "Deletion cancelled", "delete_id": delete_id}, 200


@app.route('/ytm-playlists', methods=['POST'])
def get_ytm_playlists_endpoint():
    """
    Obtiene todas las playlists de YouTube Music del usuario.
    """
    data = request.get_json() if request.data else {}
    auth_headers = data.get('auth_headers')
    
    # Si se proporcionan headers, guardarlos
    if auth_headers:
        save_youtube_headers(auth_headers)
        
    # Verificar si tenemos alguna forma de autenticación para YouTube
    if not auth_headers and not get_youtube_headers() and not get_youtube_oauth():
         return {"message": "YouTube Music authentication is required"}, 400
    
    try:
        playlists = get_ytm_playlists(auth_headers)
        return {
            "message": "Playlists retrieved successfully",
            "playlists": playlists,
            "count": len(playlists)
        }, 200
    except Exception as e:
        return {"message": str(e)}, 500


@app.route('/delete-selected-playlists', methods=['POST'])
def delete_selected_playlists():
    """
    Elimina playlists seleccionadas de YouTube Music.
    """
    global delete_progress
    
    data = request.get_json() if request.data else {}
    auth_headers = data.get('auth_headers')
    playlist_ids = data.get('playlist_ids', [])
    
    # Si se proporcionan headers, guardarlos
    if auth_headers:
        save_youtube_headers(auth_headers)
        
    # Verificar si tenemos alguna forma de autenticación para YouTube
    if not auth_headers and not get_youtube_headers() and not get_youtube_oauth():
         return {"message": "YouTube Music authentication is required"}, 400
    
    if not playlist_ids or len(playlist_ids) == 0:
        return {"message": "No playlists selected for deletion"}, 400
    
    try:
        # Generar ID único para esta eliminación
        delete_id = secrets.token_urlsafe(16)
        
        # Inicializar progreso
        delete_progress[delete_id] = {
            "status": "in_progress",
            "total_playlists": len(playlist_ids),
            "deleted": 0,
            "failed": 0,
            "playlists": []
        }
        
        # Ejecutar eliminación en background
        def delete_in_background():
            try:
                results = delete_selected_ytm_playlists(auth_headers, playlist_ids, delete_progress, delete_id, cancelled_deletions)
                if delete_id not in cancelled_deletions:
                    delete_progress[delete_id] = results
                    delete_progress[delete_id]["status"] = "completed"
            except Exception as e:
                if delete_id not in cancelled_deletions:
                    delete_progress[delete_id]["status"] = "error"
                    delete_progress[delete_id]["error"] = str(e)
        
        thread = threading.Thread(target=delete_in_background)
        thread.daemon = True
        thread.start()
        
        return {
            "message": "Deletion started",
            "delete_id": delete_id,
            "total_playlists": len(playlist_ids)
        }, 202
    except Exception as e:
        return {"message": str(e)}, 500


@app.route('/auth/mobile/google', methods=['GET'])
def google_auth_mobile():
    """
    Devuelve las credenciales necesarias para Google Sign-In en el cliente móvil.
    """
    client_id = os.getenv('GOOGLE_CLIENT_ID')
    return {
        "client_id": client_id
    }, 200


def _render_mobile_error(error_message):
    """Helper para mostrar página de error para móvil."""
    return f"""
    <html>
    <head>
        <title>Authentication Error</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; background: #121212; color: white; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #f44336;">❌ Authentication Failed</h1>
        <p>{error_message}</p>
        <p style="color: #b3b3b3; font-size: 14px; margin-top: 30px;">
            Please close this window and try again.
        </p>
    </body>
    </html>
    """, 400


def _render_mobile_success(access_token, expires_in=3600):
    """Helper para mostrar página de éxito para móvil con token para copiar."""
    return f"""
    <html>
    <head>
        <title>Authentication Successful</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; background: #121212; color: white; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #1DB954;">✅ Spotify Connected!</h1>
        <p>Your Spotify account has been successfully connected.</p>
        
        <div style="background: #282828; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <p style="margin: 0 0 10px 0; color: #b3b3b3; font-size: 14px;">Your Access Token:</p>
            <div style="background: #1e1e1e; padding: 10px; border-radius: 4px; word-break: break-all; font-family: monospace; font-size: 12px;" id="token">{access_token}</div>
            <button onclick="copyToken()" style="margin-top: 15px; background: #1DB954; color: white; border: none; padding: 12px 24px; border-radius: 20px; cursor: pointer; font-size: 16px; width: 100%;">
                📋 Copy Token
            </button>
            <p id="copied" style="color: #1DB954; text-align: center; margin-top: 10px; display: none;">Token copied to clipboard!</p>
        </div>
        
        <p style="color: #b3b3b3; font-size: 14px;">
            Paste this token in the app to continue.<br>
            This token expires in {expires_in // 60} minutes.
        </p>
        
        <p style="color: #b3b3b3; font-size: 12px; margin-top: 30px;">
            You can now close this window and return to the app.
        </p>
        
        <script>
            function copyToken() {{
                const token = document.getElementById('token').innerText;
                navigator.clipboard.writeText(token).then(() => {{
                    document.getElementById('copied').style.display = 'block';
                    setTimeout(() => {{
                        document.getElementById('copied').style.display = 'none';
                    }}, 3000);
                }});
            }}
        </script>
    </body>
    </html>
    """


@app.route('/auth/spotify', methods=['GET'])
def spotify_auth():
    """
    Inicia el flujo de autenticación OAuth con Spotify.
    Redirige al usuario a Spotify para autorizar la aplicación.
    """
    client_id = os.getenv('SPOTIPY_CLIENT_ID')
    redirect_uri = os.getenv('REDIRECT_URI', 'http://127.0.0.1:8080/auth/callback')
    scope = 'playlist-read-private playlist-read-collaborative'
    
    # Generar un state para prevenir CSRF
    state = secrets.token_urlsafe(16)
    session['oauth_state'] = state
    
    auth_url = 'https://accounts.spotify.com/authorize?' + urllib.parse.urlencode({
        'response_type': 'code',
        'client_id': client_id,
        'scope': scope,
        'redirect_uri': redirect_uri,
        'state': state
    })
    
    return redirect(auth_url)


@app.route('/auth/callback', methods=['GET'])
def spotify_callback():
    """
    Callback de Spotify después de la autorización.
    Intercambia el código de autorización por un access token.
    Detecta si viene de móvil usando el prefijo 'mobile_' en el state.
    """
    code = request.args.get('code')
    state = request.args.get('state')
    error = request.args.get('error')
    
    # Detectar si es una autenticación desde móvil
    is_mobile = state and state.startswith('mobile_')
    
    # Verificar state para prevenir CSRF
    if state != session.get('oauth_state'):
        if is_mobile:
            return _render_mobile_error("Invalid state. Please try again.")
        return redirect(f"{os.getenv('FRONTEND_URL')}/create-playlist?error=invalid_state")
    
    if error:
        if is_mobile:
            return _render_mobile_error(f"Authentication error: {error}")
        return redirect(f"{os.getenv('FRONTEND_URL')}/create-playlist?error={error}")
    
    if not code:
        if is_mobile:
            return _render_mobile_error("No authorization code received.")
        return redirect(f"{os.getenv('FRONTEND_URL')}/create-playlist?error=no_code")
    
    # Intercambiar código por access token
    import requests
    token_url = 'https://accounts.spotify.com/api/token'
    
    # Usar el redirect_uri correcto según el origen (móvil o web)
    if is_mobile and session.get('mobile_redirect_uri'):
        redirect_uri = session.get('mobile_redirect_uri')
    else:
        redirect_uri = os.getenv('REDIRECT_URI', 'http://127.0.0.1:8080/auth/callback')
    
    data = {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirect_uri,
        'client_id': os.getenv('SPOTIPY_CLIENT_ID'),
        'client_secret': os.getenv('SPOTIPY_CLIENT_SECRET')
    }
    
    response = requests.post(token_url, data=data)
    
    if response.status_code != 200:
        if is_mobile:
            return _render_mobile_error("Failed to exchange code for token.")
        return redirect(f"{os.getenv('FRONTEND_URL')}/create-playlist?error=token_error")
    
    token_data = response.json()
    access_token = token_data.get('access_token')
    refresh_token = token_data.get('refresh_token')
    expires_in = token_data.get('expires_in', 3600)
    
    # Guardar el token en la sesión
    session['spotify_token'] = access_token
    
    # Guardar tokens en archivo JSON (incluido refresh_token)
    if refresh_token:
        save_spotify_tokens(access_token, refresh_token, expires_in)
    
    # Si es móvil, mostrar página con token para copiar
    if is_mobile:
        return _render_mobile_success(access_token, expires_in)
    
    # Redirigir al frontend con éxito
    return redirect(f"{os.getenv('FRONTEND_URL')}/create-playlist?auth=success")


@app.route('/auth/token', methods=['GET'])
def get_token():
    """
    Obtiene el token de Spotify guardado en la sesión.
    """
    token = session.get('spotify_token')
    
    if not token:
        return {"message": "Not authenticated", "authenticated": False}, 401
    
    return {"token": token, "authenticated": True}, 200


@app.route('/auth/logout', methods=['POST'])
def logout():
    """
    Cierra la sesión del usuario.
    """
    session.pop('spotify_token', None)
    session.pop('oauth_state', None)
    return {"message": "Logged out successfully"}, 200


@app.route('/auth/mobile/spotify', methods=['GET'])
def spotify_auth_mobile():
    """
    Inicia el flujo de autenticación OAuth con Spotify para apps móviles.
    Usa el host desde donde viene la petición para el redirect_uri.
    El usuario debe registrar su IP local en Spotify Developer Dashboard.
    """
    client_id = os.getenv('SPOTIPY_CLIENT_ID')
    
    # Obtener el host desde donde viene la petición (la IP que configuró el usuario)
    # Esto permite que funcione con cualquier IP (local, VPS, ngrok, etc.)
    request_host = request.host  # ej: "192.168.1.100:8080"
    scheme = request.scheme  # http o https
    
    # Construir redirect_uri dinámicamente basado en el host de la petición
    redirect_uri = f"{scheme}://{request_host}/auth/callback"
    
    # Guardar el redirect_uri usado para poder usarlo en el callback
    session['mobile_redirect_uri'] = redirect_uri
    
    scope = 'playlist-read-private playlist-read-collaborative'
    
    # Generar un state que incluya un prefijo para identificar que es móvil
    state = 'mobile_' + secrets.token_urlsafe(16)
    session['oauth_state'] = state
    
    auth_url = 'https://accounts.spotify.com/authorize?' + urllib.parse.urlencode({
        'response_type': 'code',
        'client_id': client_id,
        'scope': scope,
        'redirect_uri': redirect_uri,
        'state': state
    })
    
    return redirect(auth_url)


@app.route('/auth/mobile/spotify-code', methods=['GET', 'POST'])
def spotify_auth_code_mobile():
    """
    GET: Devuelve el client_id de Spotify.
    POST: Intercambia el authorization_code obtenido via deep linking por tokens.
    """
    if request.method == 'GET':
        client_id = os.getenv('SPOTIPY_CLIENT_ID')
        print(f"[DEBUG] SPOTIPY_CLIENT_ID = {client_id}")
        if not client_id:
            return {"message": "SPOTIPY_CLIENT_ID not configured in .env"}, 500
        return {
            "client_id": client_id
        }, 200
        
    if request.method == 'POST':
        data = request.get_json()
        code = data.get('code')
        redirect_uri = data.get('redirect_uri')
        
        if not code or not redirect_uri:
            return {"message": "Code and redirect_uri are required"}, 400
            
        try:
             # Intercambiar código por tokens
            import requests
            token_url = 'https://accounts.spotify.com/api/token'
            
            payload = {
                'grant_type': 'authorization_code',
                'code': code,
                'redirect_uri': redirect_uri,
                'client_id': os.getenv('SPOTIPY_CLIENT_ID'),
                'client_secret': os.getenv('SPOTIPY_CLIENT_SECRET')
            }
            
            response = requests.post(token_url, data=payload)
            
            if response.status_code != 200:
                return {"message": f"Failed to exchange code: {response.text}"}, 400
                
            token_data = response.json()
            access_token = token_data.get('access_token')
            refresh_token = token_data.get('refresh_token')
            expires_in = token_data.get('expires_in', 3600)
            
            # Guardar tokens
            if refresh_token:
                save_spotify_tokens(access_token, refresh_token, expires_in)
                
            return {
                "message": "Spotify authentication successful",
                "token": access_token,
                "authenticated": True
            }, 200
            
        except Exception as e:
            return {"message": f"Error authenticating with Spotify: {str(e)}"}, 500

@app.route('/auth/mobile/token', methods=['GET'])
def get_mobile_token():
    """
    Obtiene el token de Spotify guardado (para polling desde la app móvil).
    """
    token = get_spotify_access_token()
    
    if not token:
        return {"message": "Not authenticated", "authenticated": False}, 401
    
    return {"token": token, "authenticated": True}, 200


def auto_sync_playlists():
    """
    Función que se ejecuta automáticamente cada 2 minutos para sincronizar playlists.
    """
    global transfer_progress
    
    print("=== Iniciando sincronización automática ===")
    
    try:
        # Obtener credenciales guardadas
        spotify_token = get_spotify_access_token()
        youtube_headers = get_youtube_headers()
        
        if not spotify_token:
            print("No hay token de Spotify válido. Se necesita autenticación.")
            return
        
        if not youtube_headers:
            print("No hay headers de YouTube Music guardados.")
            return
        
        # Obtener playlists de Spotify
        playlists = get_user_playlists(spotify_token)
        
        if len(playlists) == 0:
            print("No se encontraron playlists en Spotify")
            return
        
        print(f"Encontradas {len(playlists)} playlists en Spotify")
        
        # Generar ID único para esta transferencia
        transfer_id = f"auto_sync_{secrets.token_urlsafe(8)}"
        
        # Inicializar progreso
        transfer_progress[transfer_id] = {
            "status": "in_progress",
            "total_playlists": len(playlists),
            "processed": 0,
            "successful": 0,
            "failed": 0,
            "skipped": 0,
            "playlists": [{"name": p["name"], "status": "pending", "id": p["id"], "image": p.get("image")} for p in playlists]
        }
        
        # Ejecutar transferencia
        results = transfer_all_playlists(playlists, youtube_headers, transfer_id, transfer_progress)
        
        # Actualizar estado final
        transfer_progress[transfer_id]["status"] = "completed"
        
        print(f"Sincronización completada: {results['successful']} exitosas, {results['failed']} fallidas, {results['skipped']} omitidas")
        
    except Exception as e:
        print(f"Error en sincronización automática: {e}")


@app.route('/auto-sync/start', methods=['POST'])
def start_auto_sync():
    """
    Inicia la sincronización automática cada 2 minutos.
    """
    global auto_sync_enabled
    
    if not has_valid_credentials():
        return {"message": "Se necesitan credenciales válidas de Spotify y YouTube Music"}, 400
    
    if auto_sync_enabled:
        return {"message": "La sincronización automática ya está activa"}, 200
    
    # Programar el job para ejecutarse cada 2 minutos
    scheduler.add_job(
        func=auto_sync_playlists,
        trigger="interval",
        minutes=2,
        id='auto_sync_job',
        replace_existing=True
    )
    
    if not scheduler.running:
        scheduler.start()
    
    auto_sync_enabled = True
    
    return {"message": "Sincronización automática iniciada (cada 2 minutos)"}, 200


@app.route('/auto-sync/stop', methods=['POST'])
def stop_auto_sync():
    """
    Detiene la sincronización automática.
    """
    global auto_sync_enabled
    
    if not auto_sync_enabled:
        return {"message": "La sincronización automática no está activa"}, 200
    
    try:
        scheduler.remove_job('auto_sync_job')
        auto_sync_enabled = False
        return {"message": "Sincronización automática detenida"}, 200
    except Exception as e:
        return {"message": f"Error al detener sincronización: {str(e)}"}, 500


@app.route('/auto-sync/status', methods=['GET'])
def auto_sync_status():
    """
    Obtiene el estado de la sincronización automática.
    """
    return {
        "enabled": auto_sync_enabled,
        "has_credentials": has_valid_credentials()
    }, 200


@app.route('/auto-sync/run-now', methods=['POST'])
def run_sync_now():
    """
    Ejecuta la sincronización inmediatamente (sin esperar el intervalo).
    """
    if not has_valid_credentials():
        return {"message": "Se necesitan credenciales válidas de Spotify y YouTube Music"}, 400
    
    # Ejecutar en un thread separado para no bloquear la respuesta
    thread = threading.Thread(target=auto_sync_playlists)
    thread.start()
    
    return {"message": "Sincronización manual iniciada"}, 200


@app.route('/', methods=['GET'])
def home():
    # Render health check endpoint
    return {"message": "Server Online"}, 200

if __name__ == '__main__':
    # host="0.0.0.0" permite conexiones desde cualquier IP (necesario para móviles)
    app.run(host="0.0.0.0", port=8080)