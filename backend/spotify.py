import os
import requests
from dotenv import load_dotenv

load_dotenv()




def get_spotify_access_token(client_id, client_secret):
    url = "https://accounts.spotify.com/api/token"
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    data = {
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret
    }
    
    response = requests.post(url, headers=headers, data=data)
    if response.status_code != 200:
        raise Exception(f"Failed to get access token: {response.json()}")
    
    return response.json()["access_token"]


def extract_playlist_id(playlist_url):
    return playlist_url.split("/playlist/")[1].split("?")[0]

def get_all_tracks(link, market):

    playlist_id = extract_playlist_id(link)
    client_id = os.getenv('SPOTIPY_CLIENT_ID')
    client_secret = os.getenv('SPOTIPY_CLIENT_SECRET')
    access_token = get_spotify_access_token(client_id, client_secret)
    
    url = f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks?market={market}&limit=100"
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    
    all_tracks = []
    
    while url:
        response = requests.get(url, headers=headers)
        data = response.json()
        for item in data["items"]:
            track = item["track"]
            if not track or track.get("is_local") or track.get("restrictions"):
                continue
            all_tracks.append({
                "name": track["name"],
                "artists": [artist["name"] for artist in track["artists"]],
                "album": track["album"]["name"],
            })
        url = data.get("next")
        if url == 'null':
            break
    return all_tracks

def get_playlist_name(link):
    playlist_id = extract_playlist_id(link)
    client_id = os.getenv('SPOTIPY_CLIENT_ID')
    client_secret = os.getenv('SPOTIPY_CLIENT_SECRET')
    access_token = get_spotify_access_token(client_id, client_secret)
    
    url = f"https://api.spotify.com/v1/playlists/{playlist_id}"
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    
    response = requests.get(url, headers=headers)
    data = response.json()
    return data["name"]


def get_user_playlists(user_access_token):
    """
    Obtiene todas las playlists del usuario autenticado usando su token de OAuth.
    
    Args:
        user_access_token: Token de acceso OAuth del usuario de Spotify
        
    Returns:
        Lista de diccionarios con información de las playlists (id, nombre, enlace, total de canciones)
    """
    url = "https://api.spotify.com/v1/me/playlists?limit=50"
    headers = {
        "Authorization": f"Bearer {user_access_token}"
    }
    
    all_playlists = []
    
    while url:
        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            raise Exception(f"Failed to get user playlists: {response.json()}")
        
        data = response.json()
        for playlist in data["items"]:
            # Obtener la imagen de la playlist (primera imagen disponible)
            image_url = None
            if playlist.get("images") and len(playlist["images"]) > 0:
                image_url = playlist["images"][0]["url"]
            
            all_playlists.append({
                "id": playlist["id"],
                "name": playlist["name"],
                "link": playlist["external_urls"]["spotify"],
                "total_tracks": playlist["tracks"]["total"],
                "owner": playlist["owner"]["display_name"],
                "image": image_url
            })
        
        url = data.get("next")
    
    return all_playlists


def get_playlist_details_by_id(playlist_id, market="IN"):
    """
    Obtiene los detalles de una playlist específica por su ID.
    
    Args:
        playlist_id: ID de la playlist de Spotify
        market: Código de mercado (por defecto "IN")
        
    Returns:
        Diccionario con nombre y canciones de la playlist
    """
    client_id = os.getenv('SPOTIPY_CLIENT_ID')
    client_secret = os.getenv('SPOTIPY_CLIENT_SECRET')
    access_token = get_spotify_access_token(client_id, client_secret)
    
    # Obtener información de la playlist
    playlist_url = f"https://api.spotify.com/v1/playlists/{playlist_id}"
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    
    response = requests.get(playlist_url, headers=headers)
    if response.status_code != 200:
        raise Exception(f"Failed to get playlist details: {response.json()}")
    
    playlist_data = response.json()
    playlist_name = playlist_data["name"]
    
    # Obtener imagen de la playlist
    image_url = None
    if playlist_data.get("images") and len(playlist_data["images"]) > 0:
        image_url = playlist_data["images"][0]["url"]
    
    # Obtener todas las canciones
    tracks_url = f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks?market={market}&limit=100"
    all_tracks = []
    
    while tracks_url:
        response = requests.get(tracks_url, headers=headers)
        data = response.json()
        for item in data["items"]:
            track = item["track"]
            if not track or track.get("is_local") or track.get("restrictions"):
                continue
            all_tracks.append({
                "name": track["name"],
                "artists": [artist["name"] for artist in track["artists"]],
                "album": track["album"]["name"],
            })
        tracks_url = data.get("next")
        if tracks_url == 'null':
            break
    
    return {
        "name": playlist_name,
        "tracks": all_tracks,
        "image": image_url
    }


def get_playlist_tracks_by_id(playlist_id, market="IN"):
    """
    Obtiene solo las canciones de una playlist específica por su ID.
    Incluye un índice único para cada track.
    
    Args:
        playlist_id: ID de la playlist de Spotify
        market: Código de mercado (por defecto "IN")
        
    Returns:
        Lista de canciones con índice, nombre, artistas y álbum
    """
    client_id = os.getenv('SPOTIPY_CLIENT_ID')
    client_secret = os.getenv('SPOTIPY_CLIENT_SECRET')
    access_token = get_spotify_access_token(client_id, client_secret)
    
    headers = {
        "Authorization": f"Bearer {access_token}"
    }
    
    # Obtener todas las canciones
    tracks_url = f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks?market={market}&limit=100"
    all_tracks = []
    track_index = 0
    
    while tracks_url:
        response = requests.get(tracks_url, headers=headers)
        if response.status_code != 200:
            raise Exception(f"Failed to get playlist tracks: {response.json()}")
        
        data = response.json()
        for item in data["items"]:
            track = item["track"]
            if not track or track.get("is_local") or track.get("restrictions"):
                continue
            
            # Obtener imagen del álbum
            album_image = None
            if track["album"].get("images") and len(track["album"]["images"]) > 0:
                album_image = track["album"]["images"][-1]["url"]  # Imagen más pequeña
            
            all_tracks.append({
                "index": track_index,
                "name": track["name"],
                "artists": [artist["name"] for artist in track["artists"]],
                "album": track["album"]["name"],
                "image": album_image,
                "duration_ms": track.get("duration_ms", 0)
            })
            track_index += 1
        
        tracks_url = data.get("next")
        if tracks_url == 'null':
            break
    
    return all_tracks


