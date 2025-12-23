from ytmusicapi import YTMusic
import ytmusicapi
from spotify import get_all_tracks, get_playlist_name
import time


#### SETUP
playlist_name = "Replace this with the playlist name you wish to create"

spotify_playlist_link = "Replace this with the spotify playlist link"

headers = '''
delete this line and paste the headers here
'''

####

def check_playlist_exists(ytmusic, playlist_name):
    """
    Verifica si una playlist con el nombre dado ya existe en YouTube Music.
    Retorna el ID de la playlist si existe, None si no existe.
    """
    try:
        # Obtener todas las playlists del usuario
        playlists = ytmusic.get_library_playlists(limit=None)
        
        # Buscar playlist con el mismo nombre
        for playlist in playlists:
            if playlist.get('title', '').strip() == playlist_name.strip():
                print(f"Found existing playlist: '{playlist_name}' with ID: {playlist.get('playlistId')}")
                return playlist.get('playlistId')
        
        return None
    except Exception as e:
        print(f"Error checking existing playlists: {e}")
        return None


def get_existing_playlist_tracks(ytmusic, playlist_id):
    """
    Obtiene las canciones de una playlist existente en YouTube Music.
    Retorna una lista de video IDs.
    """
    try:
        playlist_data = ytmusic.get_playlist(playlist_id, limit=None)
        existing_video_ids = []
        
        if 'tracks' in playlist_data and playlist_data['tracks']:
            for track in playlist_data['tracks']:
                if track and 'videoId' in track:
                    existing_video_ids.append(track['videoId'])
        
        print(f"Found {len(existing_video_ids)} tracks in existing playlist")
        return existing_video_ids
    except Exception as e:
        print(f"Error getting existing playlist tracks: {e}")
        return []


def playlists_are_different(existing_video_ids, new_video_ids):
    """
    Compara dos listas de video IDs para determinar si son diferentes.
    Retorna True si hay diferencias (número diferente o IDs diferentes).
    """
    # Si tienen diferente cantidad de canciones
    if len(existing_video_ids) != len(new_video_ids):
        print(f"Playlist size changed: {len(existing_video_ids)} -> {len(new_video_ids)}")
        return True
    
    # Comparar los sets de IDs (ignora el orden)
    existing_set = set(existing_video_ids)
    new_set = set(new_video_ids)
    
    if existing_set != new_set:
        added = new_set - existing_set
        removed = existing_set - new_set
        print(f"Playlist content changed: {len(added)} added, {len(removed)} removed")
        return True
    
    print("Playlist content is identical")
    return False


def get_video_ids(ytmusic,tracks):
    video_ids = []
    missed_tracks = []
    index = 1
    start_time = time.time()
    print(f"Searching for {len(tracks)} songs on YouTube Music")
    
    for track in tracks:
        try :
            print(f"Searching for song {index}/{len(tracks)}")
            index += 1
            search_string = f"{track['name']} {track['artists'][0]}"
            video_id = ytmusic.search(search_string, filter="songs")[0]["videoId"]
            video_ids.append(video_id)
        except :
            print(f"{track['name']} {track['artists'][0]} not found on YouTube Music")
            missed_tracks.append(f"{track['name']} {track['artists'][0]}")
    
    total_time = time.time() - start_time
    print(f"Found {len(video_ids)}/{len(tracks)} songs on YouTube Music in {total_time:.2f} seconds. {len(tracks) - len(video_ids)} songs not found.")
    
    if len(video_ids) == 0:
        raise Exception("No songs found on YouTube Music")
    return video_ids


def create_ytm_playlist(playlist_link, headers):
    ytmusicapi.setup(filepath="header_auth.json", headers_raw=headers)
    ytmusic = YTMusic("header_auth.json")
    tracks = get_all_tracks(playlist_link, "IN")
    name = get_playlist_name(playlist_link)
    
    # Obtener los video IDs de las canciones de Spotify
    print(f"Searching for songs on YouTube Music...")
    new_video_ids = get_video_ids(ytmusic, tracks)
    
    # Verificar si la playlist ya existe
    print(f"Checking if playlist '{name}' already exists...")
    existing_playlist_id = check_playlist_exists(ytmusic, name)
    
    if existing_playlist_id:
        # La playlist existe, verificar si hay cambios
        print(f"Playlist '{name}' already exists. Checking for updates...")
        existing_video_ids = get_existing_playlist_tracks(ytmusic, existing_playlist_id)
        
        # Comparar las playlists
        if playlists_are_different(existing_video_ids, new_video_ids):
            # Hay diferencias, eliminar la playlist vieja y crear una nueva
            print(f"Playlist has changes. Deleting old playlist and creating updated version...")
            try:
                ytmusic.delete_playlist(existing_playlist_id)
                print(f"Old playlist deleted successfully")
            except Exception as e:
                print(f"Error deleting old playlist: {e}")
            
            # Crear la nueva playlist con las canciones actualizadas
            ytmusic.create_playlist(name, "", "PRIVATE", new_video_ids)
            print(f"Playlist '{name}' updated successfully!")
        else:
            # No hay cambios, playlist está actualizada
            print(f"Playlist '{name}' is already up to date. No changes needed.")
        return
    
    print(f"Playlist '{name}' does not exist. Creating new playlist...")
    ytmusic.create_playlist(name, "", "PRIVATE", new_video_ids)
    print(f"Playlist '{name}' created successfully!")

def selfhost_make_playlist():
    ytmusicapi.setup(filepath="browser.json", headers_raw=headers)
    ytmusic = YTMusic("browser.json")
    # tracks = get_all_tracks(spotify_playlist_link, "IN")
    name = playlist_name
    
    # Leer los video IDs del archivo
    with open('video_ids.txt', 'r') as f:
        new_video_ids = [line.strip() for line in f.readlines()]
    
    # Verificar si la playlist ya existe
    print(f"Checking if playlist '{name}' already exists...")
    existing_playlist_id = check_playlist_exists(ytmusic, name)
    
    if existing_playlist_id:
        # La playlist existe, verificar si hay cambios
        print(f"Playlist '{name}' already exists. Checking for updates...")
        existing_video_ids = get_existing_playlist_tracks(ytmusic, existing_playlist_id)
        
        # Comparar las playlists
        if playlists_are_different(existing_video_ids, new_video_ids):
            # Hay diferencias, eliminar la playlist vieja y crear una nueva
            print(f"Playlist has changes. Deleting old playlist and creating updated version...")
            try:
                ytmusic.delete_playlist(existing_playlist_id)
                print(f"Old playlist deleted successfully")
            except Exception as e:
                print(f"Error deleting old playlist: {e}")
            
            # Crear la nueva playlist con las canciones actualizadas
            ytmusic.create_playlist(name, "", "PRIVATE", new_video_ids)
            print(f"Playlist '{name}' updated successfully!")
        else:
            # No hay cambios, playlist está actualizada
            print(f"Playlist '{name}' is already up to date. No changes needed.")
        return
    
    print(f"Playlist '{name}' does not exist. Creating new playlist...")
    ytmusic.create_playlist(name, "", "PRIVATE", new_video_ids)
    print(f"Playlist '{name}' created successfully!")

    
def selfhost_get_vids():
    ytmusic = YTMusic()
    tracks = get_all_tracks(spotify_playlist_link, "IN")
    video_ids = get_video_ids(ytmusic, tracks)
    with open('video_ids.txt', 'w') as f:
        for video_id in video_ids:
            f.write(video_id + '\n')
    
    
selfhost_get_vids() # comment this out after running once
# selfhost_make_playlist() # uncomment this when running the second time