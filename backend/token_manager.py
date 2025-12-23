import json
import os
import requests
from datetime import datetime, timedelta
from dotenv import load_dotenv

load_dotenv()

TOKENS_FILE = "tokens.json"


def get_tokens():
    """
    Lee los tokens del archivo JSON.
    Retorna un diccionario con la estructura:
    {
        "spotify": {
            "access_token": "...",
            "refresh_token": "...",
            "expires_at": "2024-12-22T10:30:00"
        },
        "youtube_music": {
            "headers": "..."
        }
    }
    """
    if not os.path.exists(TOKENS_FILE):
        return {
            "spotify": {},
            "youtube_music": {}
        }
    
    try:
        with open(TOKENS_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading tokens file: {e}")
        return {
            "spotify": {},
            "youtube_music": {}
        }


def save_tokens(tokens):
    """
    Guarda los tokens en el archivo JSON.
    """
    try:
        with open(TOKENS_FILE, 'w') as f:
            json.dump(tokens, f, indent=2)
        print("Tokens saved successfully")
    except Exception as e:
        print(f"Error saving tokens: {e}")


def save_spotify_tokens(access_token, refresh_token, expires_in=3600):
    """
    Guarda los tokens de Spotify.
    expires_in: segundos hasta que expira el access token (por defecto 3600 = 1 hora)
    """
    tokens = get_tokens()
    
    expires_at = datetime.now() + timedelta(seconds=expires_in)
    
    tokens["spotify"] = {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "expires_at": expires_at.isoformat()
    }
    
    save_tokens(tokens)


def save_youtube_headers(headers):
    """
    Guarda los headers de autenticación de YouTube Music.
    """
    tokens = get_tokens()
    
    tokens["youtube_music"] = {
        "headers": headers,
        "saved_at": datetime.now().isoformat()
    }
    
    save_tokens(tokens)


def get_spotify_access_token():
    """
    Obtiene un access token válido de Spotify.
    Si el token actual ha expirado, usa el refresh token para obtener uno nuevo.
    """
    tokens = get_tokens()
    spotify = tokens.get("spotify", {})
    
    if not spotify.get("access_token"):
        return None
    
    # Verificar si el token ha expirado
    expires_at = spotify.get("expires_at")
    if expires_at:
        expires_datetime = datetime.fromisoformat(expires_at)
        # Renovar si expira en menos de 5 minutos
        if datetime.now() >= expires_datetime - timedelta(minutes=5):
            print("Access token expired or about to expire, refreshing...")
            return refresh_spotify_token()
    
    return spotify.get("access_token")


def refresh_spotify_token():
    """
    Usa el refresh token para obtener un nuevo access token de Spotify.
    """
    tokens = get_tokens()
    spotify = tokens.get("spotify", {})
    
    refresh_token = spotify.get("refresh_token")
    if not refresh_token:
        print("No refresh token available")
        return None
    
    client_id = os.getenv('SPOTIPY_CLIENT_ID')
    client_secret = os.getenv('SPOTIPY_CLIENT_SECRET')
    
    token_url = 'https://accounts.spotify.com/api/token'
    
    data = {
        'grant_type': 'refresh_token',
        'refresh_token': refresh_token,
        'client_id': client_id,
        'client_secret': client_secret
    }
    
    try:
        response = requests.post(token_url, data=data)
        
        if response.status_code != 200:
            print(f"Error refreshing token: {response.json()}")
            return None
        
        token_data = response.json()
        new_access_token = token_data.get('access_token')
        new_refresh_token = token_data.get('refresh_token', refresh_token)  # A veces no devuelve uno nuevo
        expires_in = token_data.get('expires_in', 3600)
        
        # Guardar los nuevos tokens
        save_spotify_tokens(new_access_token, new_refresh_token, expires_in)
        
        print("Spotify token refreshed successfully")
        return new_access_token
        
    except Exception as e:
        print(f"Error refreshing Spotify token: {e}")
        return None


def get_youtube_headers():
    """
    Obtiene los headers de YouTube Music guardados.
    """
    tokens = get_tokens()
    youtube = tokens.get("youtube_music", {})
    return youtube.get("headers")


def has_valid_credentials():
    """
    Verifica si hay credenciales válidas guardadas para ambos servicios.
    """
    tokens = get_tokens()
    
    has_spotify = bool(tokens.get("spotify", {}).get("refresh_token"))
    has_youtube = bool(tokens.get("youtube_music", {}).get("headers"))
    
    return has_spotify and has_youtube
