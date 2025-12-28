from ytmusicapi import YTMusic
import ytmusicapi
from spotify import get_all_tracks, get_playlist_name, get_playlist_details_by_id


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
    missed_tracks = {
        "count": 0,
        "tracks": []
    }
    for track in tracks:
        try :
            search_string = f"{track['name']} {track['artists'][0]}"
            video_id = ytmusic.search(search_string, filter="songs")[0]["videoId"]
            video_ids.append(video_id)
        except :
            print(f"{track['name']} {track['artists'][0]} not found on YouTube Music")
            missed_tracks["count"] += 1
            missed_tracks["tracks"].append(f"{track['name']} {track['artists'][0]}")
    print(f"Found {len(video_ids)} songs on YouTube Music")
    if len(video_ids) == 0:
        raise Exception("No songs found on YouTube Music")
    return video_ids, missed_tracks


def setup_ytmusic(headers=None):
    """
    Configura y retorna una instancia de YTMusic.
    Prioridad: 1) Headers si se proporcionan, 2) OAuth si tiene refresh_token, 3) Archivos existentes
    """
    import os
    
    # Si se proporcionan headers, usarlos primero (más confiable)
    if headers:
        print("Using Header credentials for YouTube Music")
        ytmusicapi.setup(filepath="header_auth.json", headers_raw=headers)
        return YTMusic("header_auth.json")
    
    # Intentar obtener credenciales OAuth
    try:
        from token_manager import get_youtube_oauth
        import json
        
        oauth_tokens = get_youtube_oauth()
        if oauth_tokens:
            # Validar que el token OAuth tenga el formato correcto para ytmusicapi
            # ytmusicapi requiere: access_token Y refresh_token (para poder renovar)
            # El token de Google Sign-In NO incluye refresh_token
            has_access_token = "access_token" in oauth_tokens
            has_refresh_token = "refresh_token" in oauth_tokens
            
            print(f"[DEBUG] OAuth tokens found: access_token={has_access_token}, refresh_token={has_refresh_token}")
            
            if has_access_token and has_refresh_token:
                print("Using OAuth credentials for YouTube Music (valid format)")
                # Guardar en oauth.json porque YTMusic lo necesita
                with open("oauth.json", "w") as f:
                    json.dump(oauth_tokens, f)
                return YTMusic("oauth.json")
            else:
                print("OAuth token from Google Sign-In is not compatible with ytmusicapi (missing refresh_token)")
                print("Please use header-based authentication or run 'ytmusicapi oauth' to set up proper OAuth")
    except Exception as e:
        print(f"Error checking OAuth: {e}")
        
    # Intentar cargar archivos existentes por defecto
    if os.path.exists("header_auth.json"):
        print("Using existing header_auth.json")
        return YTMusic("header_auth.json")
    
    # Solo usar oauth.json si fue creado por ytmusicapi (tiene refresh_token)
    if os.path.exists("oauth.json"):
        try:
            import json
            with open("oauth.json", "r") as f:
                existing_oauth = json.load(f)
            if existing_oauth.get("refresh_token"):
                print("Using existing oauth.json (valid format)")
                return YTMusic("oauth.json")
            else:
                print("Existing oauth.json is not valid (no refresh_token)")
        except Exception as e:
            print(f"Error reading oauth.json: {e}")
        
    raise Exception("No valid credentials found for YouTube Music. Please provide auth headers or run 'ytmusicapi oauth' to set up OAuth.")


def create_ytm_playlist(playlist_link, headers):
    ytmusic = setup_ytmusic(headers)
    tracks = get_all_tracks(playlist_link, "IN")
    name = get_playlist_name(playlist_link)
    
    # Obtener los video IDs de las canciones de Spotify
    print(f"Searching for songs on YouTube Music...")
    new_video_ids, missed_tracks = get_video_ids(ytmusic, tracks)
    
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
            playlist_id = ytmusic.create_playlist(name, "", "PRIVATE", new_video_ids)
            
            # Agregar información adicional a la respuesta
            missed_tracks["playlist_exists"] = False
            missed_tracks["playlist_updated"] = True
            missed_tracks["playlist_id"] = playlist_id
            missed_tracks["playlist_name"] = name
            
            print(f"Playlist '{name}' updated successfully with ID: {playlist_id}")
            return missed_tracks
        else:
            # No hay cambios, playlist está actualizada
            print(f"Playlist '{name}' is already up to date. No changes needed.")
            return {
                "count": 0,
                "tracks": [],
                "playlist_exists": True,
                "playlist_updated": False,
                "playlist_id": existing_playlist_id,
                "playlist_name": name
            }
    
    # Si no existe, crear la playlist normalmente
    print(f"Playlist '{name}' does not exist. Creating new playlist...")
    playlist_id = ytmusic.create_playlist(name, "", "PRIVATE", new_video_ids)
    
    # Agregar información adicional a la respuesta
    missed_tracks["playlist_exists"] = False
    missed_tracks["playlist_updated"] = False
    missed_tracks["playlist_id"] = playlist_id
    missed_tracks["playlist_name"] = name
    
    print(f"Playlist '{name}' created successfully with ID: {playlist_id}")
    return missed_tracks


def transfer_all_playlists(playlists_data, headers, transfer_id=None, progress_tracker=None, cancelled_transfers=None):
    """
    Transfiere múltiples playlists de Spotify a YouTube Music.
    
    Args:
        playlists_data: Lista de diccionarios con información de las playlists
                       Cada item debe tener: id, name, total_tracks
        headers: Headers de autenticación de YouTube Music
        transfer_id: ID único de la transferencia para tracking
        progress_tracker: Diccionario compartido para actualizar progreso en tiempo real
        cancelled_transfers: Set de IDs de transferencias canceladas
        
    Returns:
        Diccionario con resultados de la transferencia para cada playlist
    """
    ytmusic = setup_ytmusic(headers)
    
    results = {
        "total_playlists": len(playlists_data),
        "processed": 0,
        "successful": 0,
        "failed": 0,
        "skipped": 0,
        "playlists": []
    }
    
    def update_progress(playlist_index, status, **kwargs):
        """Actualiza el progreso en tiempo real"""
        if progress_tracker and transfer_id and transfer_id in progress_tracker:
            progress_tracker[transfer_id]["playlists"][playlist_index]["status"] = status
            for key, value in kwargs.items():
                progress_tracker[transfer_id]["playlists"][playlist_index][key] = value
            progress_tracker[transfer_id]["processed"] = results["processed"]
            progress_tracker[transfer_id]["successful"] = results["successful"]
            progress_tracker[transfer_id]["failed"] = results["failed"]
            progress_tracker[transfer_id]["skipped"] = results["skipped"]
    
    def is_cancelled():
        """Verifica si la transferencia fue cancelada"""
        return cancelled_transfers and transfer_id and transfer_id in cancelled_transfers
    
    for i, playlist_info in enumerate(playlists_data):
        # Verificar si la transferencia fue cancelada
        if is_cancelled():
            print(f"\n=== Transfer Cancelled by User ===")
            break
        
        playlist_id = playlist_info["id"]
        playlist_name = playlist_info["name"]
        playlist_image = playlist_info.get("image")
        
        print(f"\n[{i+1}/{len(playlists_data)}] Processing playlist: '{playlist_name}' (ID: {playlist_id})")
        update_progress(i, "processing", image=playlist_image)
        
        try:
            # Obtener detalles de la playlist (nombre y canciones)
            update_progress(i, "fetching_details", image=playlist_image)
            playlist_details = get_playlist_details_by_id(playlist_id)
            tracks = playlist_details["tracks"]
            name = playlist_details["name"]
            image = playlist_details.get("image") or playlist_image
            
            if len(tracks) == 0:
                print(f"Playlist '{name}' is empty, skipping...")
                results["skipped"] += 1
                playlist_result = {
                    "name": name,
                    "status": "skipped",
                    "reason": "Empty playlist",
                    "missed_tracks": 0,
                    "image": image
                }
                results["playlists"].append(playlist_result)
                results["processed"] += 1
                update_progress(i, "skipped", name=name, reason="Empty playlist", missed_tracks=0, image=image)
                continue
            
            # Buscar las canciones en YouTube Music
            print(f"Searching for {len(tracks)} songs on YouTube Music...")
            update_progress(i, "searching_songs", total_tracks=len(tracks), image=image)
            new_video_ids, missed_tracks = get_video_ids(ytmusic, tracks)
            
            # Check cancellation after search
            if is_cancelled():
                print(f"\n=== Transfer Cancelled by User ===")
                break
            
            if len(new_video_ids) == 0:
                print(f"No songs found on YouTube Music for playlist '{name}', skipping...")
                results["failed"] += 1
                playlist_result = {
                    "name": name,
                    "status": "failed",
                    "reason": "No songs found on YouTube Music",
                    "missed_tracks": len(tracks),
                    "image": image
                }
                results["playlists"].append(playlist_result)
                results["processed"] += 1
                update_progress(i, "failed", name=name, reason="No songs found on YouTube Music", missed_tracks=len(tracks), image=image)
                continue
            
            # Check cancellation before checking existing
            if is_cancelled():
                print(f"\n=== Transfer Cancelled by User ===")
                break
            
            # Verificar si la playlist ya existe
            print(f"Checking if playlist '{name}' already exists...")
            update_progress(i, "checking_existing", found_tracks=len(new_video_ids), image=image)
            existing_playlist_id = check_playlist_exists(ytmusic, name)
            
            playlist_result = {
                "name": name,
                "total_tracks": len(tracks),
                "found_tracks": len(new_video_ids),
                "missed_tracks": missed_tracks["count"],
                "missed_tracks_list": missed_tracks["tracks"],
                "image": image
            }
            
            if existing_playlist_id:
                # La playlist existe, verificar si hay cambios
                print(f"Playlist '{name}' already exists. Checking for updates...")
                existing_video_ids = get_existing_playlist_tracks(ytmusic, existing_playlist_id)
                
                if playlists_are_different(existing_video_ids, new_video_ids):
                    # Hay diferencias, actualizar la playlist
                    print(f"Playlist has changes. Updating...")
                    update_progress(i, "updating", image=image)
                    try:
                        ytmusic.delete_playlist(existing_playlist_id)
                        print(f"Old playlist deleted")
                    except Exception as e:
                        print(f"Error deleting old playlist: {e}")
                    
                    new_playlist_id = ytmusic.create_playlist(name, "", "PRIVATE", new_video_ids)
                    playlist_result["status"] = "updated"
                    playlist_result["playlist_id"] = new_playlist_id
                    results["successful"] += 1
                    print(f"Playlist '{name}' updated successfully")
                    update_progress(i, "updated", name=name, playlist_id=new_playlist_id, 
                                  total_tracks=playlist_result["total_tracks"],
                                  found_tracks=playlist_result["found_tracks"],
                                  missed_tracks=playlist_result["missed_tracks"],
                                  missed_tracks_list=playlist_result["missed_tracks_list"],
                                  image=image)
                else:
                    # No hay cambios
                    playlist_result["status"] = "up_to_date"
                    playlist_result["playlist_id"] = existing_playlist_id
                    results["skipped"] += 1
                    print(f"Playlist '{name}' is already up to date")
                    update_progress(i, "up_to_date", name=name, playlist_id=existing_playlist_id,
                                  total_tracks=playlist_result["total_tracks"],
                                  found_tracks=playlist_result["found_tracks"],
                                  missed_tracks=playlist_result["missed_tracks"],
                                  missed_tracks_list=playlist_result["missed_tracks_list"],
                                  image=image)
            else:
                # Crear nueva playlist
                print(f"Creating new playlist '{name}'...")
                update_progress(i, "creating")
                new_playlist_id = ytmusic.create_playlist(name, "", "PRIVATE", new_video_ids)
                
                # Check cancellation after creating playlist
                if is_cancelled():
                    print(f"\n=== Transfer Cancelled by User ===")
                    break
                
                playlist_result["status"] = "created"
                playlist_result["playlist_id"] = new_playlist_id
                results["successful"] += 1
                print(f"Playlist '{name}' created successfully")
                update_progress(i, "created", name=name, playlist_id=new_playlist_id,
                              total_tracks=playlist_result["total_tracks"],
                              found_tracks=playlist_result["found_tracks"],
                              missed_tracks=playlist_result["missed_tracks"],
                              missed_tracks_list=playlist_result["missed_tracks_list"],
                              image=image)
            
            results["playlists"].append(playlist_result)
            results["processed"] += 1
            
        except Exception as e:
            print(f"Error processing playlist '{playlist_name}': {str(e)}")
            results["failed"] += 1
            playlist_result = {
                "name": playlist_name,
                "status": "failed",
                "reason": str(e),
                "missed_tracks": 0,
                "image": playlist_image
            }
            results["playlists"].append(playlist_result)
            results["processed"] += 1
            update_progress(i, "failed", name=playlist_name, reason=str(e), missed_tracks=0, image=playlist_image)
    
    print(f"\n=== Transfer Complete ===")
    print(f"Total: {results['total_playlists']} | Successful: {results['successful']} | Failed: {results['failed']} | Skipped: {results['skipped']}")
    
    return results


def transfer_selected_tracks(playlists_data, headers, transfer_id=None, progress_tracker=None, cancelled_transfers=None):
    """
    Transfiere playlists con canciones seleccionadas específicas a YouTube Music.
    
    Args:
        playlists_data: Lista de diccionarios con información de las playlists y sus canciones
                       Cada item debe tener: name, tracks (lista de canciones)
        headers: Headers de autenticación de YouTube Music
        transfer_id: ID único de la transferencia para tracking
        progress_tracker: Diccionario compartido para actualizar progreso en tiempo real
        cancelled_transfers: Set de IDs de transferencias canceladas
        
    Returns:
        Diccionario con resultados de la transferencia para cada playlist
    """
    ytmusic = setup_ytmusic(headers)
    
    results = {
        "total_playlists": len(playlists_data),
        "processed": 0,
        "successful": 0,
        "failed": 0,
        "skipped": 0,
        "playlists": []
    }
    
    def update_progress(playlist_index, status, **kwargs):
        """Actualiza el progreso en tiempo real"""
        if progress_tracker and transfer_id and transfer_id in progress_tracker:
            progress_tracker[transfer_id]["playlists"][playlist_index]["status"] = status
            for key, value in kwargs.items():
                progress_tracker[transfer_id]["playlists"][playlist_index][key] = value
            progress_tracker[transfer_id]["processed"] = results["processed"]
            progress_tracker[transfer_id]["successful"] = results["successful"]
            progress_tracker[transfer_id]["failed"] = results["failed"]
            progress_tracker[transfer_id]["skipped"] = results["skipped"]
    
    def is_cancelled():
        """Verifica si la transferencia fue cancelada"""
        return cancelled_transfers and transfer_id and transfer_id in cancelled_transfers
    
    for i, playlist_info in enumerate(playlists_data):
        # Verificar si la transferencia fue cancelada
        if is_cancelled():
            print(f"\n=== Transfer Cancelled by User ===")
            break
        
        playlist_name = playlist_info["name"]
        playlist_image = playlist_info.get("image")
        tracks = playlist_info.get("tracks", [])
        
        print(f"\n[{i+1}/{len(playlists_data)}] Processing playlist: '{playlist_name}' ({len(tracks)} tracks)")
        update_progress(i, "processing", image=playlist_image)
        
        try:
            if len(tracks) == 0:
                print(f"Playlist '{playlist_name}' has no tracks, skipping...")
                results["skipped"] += 1
                playlist_result = {
                    "name": playlist_name,
                    "status": "skipped",
                    "reason": "No tracks selected",
                    "missed_tracks": 0,
                    "image": playlist_image
                }
                results["playlists"].append(playlist_result)
                results["processed"] += 1
                update_progress(i, "skipped", name=playlist_name, reason="No tracks selected", missed_tracks=0, image=playlist_image)
                continue
            
            # Buscar las canciones en YouTube Music
            print(f"Searching for {len(tracks)} songs on YouTube Music...")
            update_progress(i, "searching_songs", total_tracks=len(tracks), image=playlist_image)
            new_video_ids, missed_tracks = get_video_ids(ytmusic, tracks)
            
            if len(new_video_ids) == 0:
                print(f"No songs found on YouTube Music for playlist '{playlist_name}', skipping...")
                results["failed"] += 1
                playlist_result = {
                    "name": playlist_name,
                    "status": "failed",
                    "reason": "No songs found on YouTube Music",
                    "missed_tracks": len(tracks),
                    "image": playlist_image
                }
                results["playlists"].append(playlist_result)
                results["processed"] += 1
                update_progress(i, "failed", name=playlist_name, reason="No songs found on YouTube Music", missed_tracks=len(tracks), image=playlist_image)
                continue
            
            # Verificar si la playlist ya existe
            print(f"Checking if playlist '{playlist_name}' already exists...")
            update_progress(i, "checking_existing", found_tracks=len(new_video_ids), image=playlist_image)
            existing_playlist_id = check_playlist_exists(ytmusic, playlist_name)
            
            playlist_result = {
                "name": playlist_name,
                "total_tracks": len(tracks),
                "found_tracks": len(new_video_ids),
                "missed_tracks": missed_tracks["count"],
                "missed_tracks_list": missed_tracks["tracks"],
                "image": playlist_image
            }
            
            if existing_playlist_id:
                # La playlist existe, verificar si hay cambios
                print(f"Playlist '{playlist_name}' already exists. Checking for updates...")
                existing_video_ids = get_existing_playlist_tracks(ytmusic, existing_playlist_id)
                
                if playlists_are_different(existing_video_ids, new_video_ids):
                    # Hay diferencias, actualizar la playlist
                    print(f"Playlist has changes. Updating...")
                    update_progress(i, "updating", image=playlist_image)
                    try:
                        ytmusic.delete_playlist(existing_playlist_id)
                        print(f"Old playlist deleted")
                    except Exception as e:
                        print(f"Error deleting old playlist: {e}")
                    
                    new_playlist_id = ytmusic.create_playlist(playlist_name, "", "PRIVATE", new_video_ids)
                    playlist_result["status"] = "updated"
                    playlist_result["playlist_id"] = new_playlist_id
                    results["successful"] += 1
                    print(f"Playlist '{playlist_name}' updated successfully")
                    update_progress(i, "updated", name=playlist_name, playlist_id=new_playlist_id, 
                                  total_tracks=playlist_result["total_tracks"],
                                  found_tracks=playlist_result["found_tracks"],
                                  missed_tracks=playlist_result["missed_tracks"],
                                  missed_tracks_list=playlist_result["missed_tracks_list"],
                                  image=playlist_image)
                else:
                    # No hay cambios
                    playlist_result["status"] = "up_to_date"
                    playlist_result["playlist_id"] = existing_playlist_id
                    results["skipped"] += 1
                    print(f"Playlist '{playlist_name}' is already up to date")
                    update_progress(i, "up_to_date", name=playlist_name, playlist_id=existing_playlist_id,
                                  total_tracks=playlist_result["total_tracks"],
                                  found_tracks=playlist_result["found_tracks"],
                                  missed_tracks=playlist_result["missed_tracks"],
                                  missed_tracks_list=playlist_result["missed_tracks_list"],
                                  image=playlist_image)
            else:
                # Crear nueva playlist
                print(f"Creating new playlist '{playlist_name}'...")
                update_progress(i, "creating")
                new_playlist_id = ytmusic.create_playlist(playlist_name, "", "PRIVATE", new_video_ids)
                playlist_result["status"] = "created"
                playlist_result["playlist_id"] = new_playlist_id
                results["successful"] += 1
                print(f"Playlist '{playlist_name}' created successfully")
                update_progress(i, "created", name=playlist_name, playlist_id=new_playlist_id,
                              total_tracks=playlist_result["total_tracks"],
                              found_tracks=playlist_result["found_tracks"],
                              missed_tracks=playlist_result["missed_tracks"],
                              missed_tracks_list=playlist_result["missed_tracks_list"],
                              image=playlist_image)
            
            results["playlists"].append(playlist_result)
            results["processed"] += 1
            
        except Exception as e:
            print(f"Error processing playlist '{playlist_name}': {str(e)}")
            results["failed"] += 1
            playlist_result = {
                "name": playlist_name,
                "status": "failed",
                "reason": str(e),
                "missed_tracks": 0,
                "image": playlist_image
            }
            results["playlists"].append(playlist_result)
            results["processed"] += 1
            update_progress(i, "failed", name=playlist_name, reason=str(e), missed_tracks=0, image=playlist_image)
    
    print(f"\n=== Transfer Complete ===")
    print(f"Total: {results['total_playlists']} | Successful: {results['successful']} | Failed: {results['failed']} | Skipped: {results['skipped']}")
    
    return results


def delete_all_ytm_playlists(headers, delete_progress=None, delete_id=None):
    """
    Elimina todas las playlists de YouTube Music del usuario.
    
    Args:
        headers: Headers de autenticación de YouTube Music
        delete_progress: Diccionario compartido para tracking del progreso (opcional)
        delete_id: ID único para esta operación de eliminación (opcional)
        
    Returns:
        Diccionario con resultados de la eliminación
    """
    ytmusic = setup_ytmusic(headers)
    
    results = {
        "total_playlists": 0,
        "deleted": 0,
        "failed": 0,
        "playlists": []
    }
    
    def update_progress(index, status, **kwargs):
        """Helper para actualizar progreso en tiempo real"""
        if delete_progress and delete_id:
            delete_progress[delete_id]["playlists"][index]["status"] = status
            for key, value in kwargs.items():
                if key != "status":
                    delete_progress[delete_id]["playlists"][index][key] = value
            delete_progress[delete_id]["deleted"] = results["deleted"]
            delete_progress[delete_id]["failed"] = results["failed"]
    
    try:
        # Obtener todas las playlists del usuario
        print("Fetching all playlists from YouTube Music...")
        playlists = ytmusic.get_library_playlists(limit=None)
        
        if not playlists:
            print("No playlists found in YouTube Music")
            return results
        
        results["total_playlists"] = len(playlists)
        print(f"Found {len(playlists)} playlists to delete")
        
        # Inicializar lista de playlists en progreso
        if delete_progress and delete_id:
            delete_progress[delete_id]["playlists"] = [
                {
                    "name": playlist.get("title", "Unknown"),
                    "status": "pending",
                    "playlistId": playlist.get("playlistId")
                }
                for playlist in playlists
            ]
        
        # Eliminar cada playlist
        for i, playlist in enumerate(playlists):
            playlist_name = playlist.get("title", "Unknown")
            playlist_id = playlist.get("playlistId")
            
            print(f"\n[{i+1}/{len(playlists)}] Deleting playlist: '{playlist_name}'")
            
            if not playlist_id:
                print(f"⚠️  Skipping '{playlist_name}' - No playlist ID")
                results["failed"] += 1
                results["playlists"].append({
                    "name": playlist_name,
                    "status": "failed",
                    "reason": "No playlist ID found"
                })
                update_progress(i, "failed", reason="No playlist ID found")
                continue
            
            try:
                update_progress(i, "deleting")
                
                # Eliminar la playlist
                ytmusic.delete_playlist(playlist_id)
                
                results["deleted"] += 1
                results["playlists"].append({
                    "name": playlist_name,
                    "status": "deleted",
                    "playlistId": playlist_id
                })
                update_progress(i, "deleted", name=playlist_name)
                print(f"✅ Deleted: '{playlist_name}'")
                
            except Exception as e:
                print(f"❌ Error deleting '{playlist_name}': {str(e)}")
                results["failed"] += 1
                results["playlists"].append({
                    "name": playlist_name,
                    "status": "failed",
                    "reason": str(e)
                })
                update_progress(i, "failed", name=playlist_name, reason=str(e))
        
        print(f"\n=== Deletion Complete ===")
        print(f"Total: {results['total_playlists']} | Deleted: {results['deleted']} | Failed: {results['failed']}")
        
    except Exception as e:
        print(f"Error fetching playlists: {str(e)}")
        raise Exception(f"Failed to fetch playlists: {str(e)}")
    
    return results


def get_ytm_playlists(headers):
    """
    Obtiene todas las playlists de YouTube Music del usuario.
    
    Args:
        headers: Headers de autenticación de YouTube Music
        
    Returns:
        Lista de playlists con id, name, count, thumbnails
    """
    ytmusic = setup_ytmusic(headers)
    
    try:
        print("Fetching all playlists from YouTube Music...")
        playlists = ytmusic.get_library_playlists(limit=None)
        
        # Debug: print raw response type and content
        print(f"[DEBUG] get_library_playlists returned type: {type(playlists)}")
        print(f"[DEBUG] get_library_playlists returned: {playlists}")
        
        if playlists is None:
            print("get_library_playlists returned None")
            raise Exception("Failed to fetch playlists - API returned None. Authentication may have failed.")
        
        if not playlists:
            print("No playlists found in YouTube Music")
            return []
        
        result = []
        for i, playlist in enumerate(playlists):
            print(f"[DEBUG] Processing playlist {i}: {playlist}")
            
            if playlist is None:
                print(f"[DEBUG] Skipping None playlist at index {i}")
                continue
                
            if not isinstance(playlist, dict):
                print(f"[DEBUG] Skipping non-dict playlist at index {i}: {type(playlist)}")
                continue
            
            playlist_data = {
                "id": playlist.get("playlistId"),
                "name": playlist.get("title", "Unknown"),
                "count": playlist.get("count", 0),
                "image": None
            }
            
            # Obtener la imagen si está disponible
            thumbnails = playlist.get("thumbnails", [])
            if thumbnails and len(thumbnails) > 0:
                playlist_data["image"] = thumbnails[-1].get("url")
            
            result.append(playlist_data)
        
        print(f"Found {len(result)} playlists in YouTube Music")
        return result
        
    except Exception as e:
        print(f"Error fetching YTM playlists: {str(e)}")
        import traceback
        traceback.print_exc()
        raise Exception(f"Failed to fetch playlists: {str(e)}")


def delete_selected_ytm_playlists(headers, playlist_ids, delete_progress=None, delete_id=None, cancelled_deletions=None):
    """
    Elimina playlists seleccionadas de YouTube Music.
    
    Args:
        headers: Headers de autenticación de YouTube Music
        playlist_ids: Lista de IDs de playlists a eliminar
        delete_progress: Diccionario compartido para tracking del progreso
        delete_id: ID único para esta operación de eliminación
        cancelled_deletions: Set de IDs de eliminaciones canceladas
        
    Returns:
        Diccionario con resultados de la eliminación
    """
    ytmusic = setup_ytmusic(headers)
    
    results = {
        "total_playlists": len(playlist_ids),
        "deleted": 0,
        "failed": 0,
        "playlists": []
    }
    
    def update_progress(index, status, **kwargs):
        """Helper para actualizar progreso en tiempo real"""
        if delete_progress and delete_id and delete_id in delete_progress:
            if index < len(delete_progress[delete_id]["playlists"]):
                delete_progress[delete_id]["playlists"][index]["status"] = status
                for key, value in kwargs.items():
                    if key != "status":
                        delete_progress[delete_id]["playlists"][index][key] = value
            delete_progress[delete_id]["deleted"] = results["deleted"]
            delete_progress[delete_id]["failed"] = results["failed"]
    
    def is_cancelled():
        """Verifica si la eliminación fue cancelada"""
        return cancelled_deletions and delete_id and delete_id in cancelled_deletions
    
    try:
        # Obtener información de las playlists para mostrar nombres
        print("Fetching playlist details from YouTube Music...")
        all_playlists = ytmusic.get_library_playlists(limit=None)
        
        # Crear un mapa de ID a nombre
        playlist_map = {p.get("playlistId"): p for p in all_playlists if p.get("playlistId")}
        
        # Inicializar lista de playlists en progreso
        if delete_progress and delete_id:
            delete_progress[delete_id]["playlists"] = []
            for pid in playlist_ids:
                playlist_info = playlist_map.get(pid, {})
                thumbnails = playlist_info.get("thumbnails", [])
                image = thumbnails[-1].get("url") if thumbnails else None
                delete_progress[delete_id]["playlists"].append({
                    "name": playlist_info.get("title", "Unknown"),
                    "status": "pending",
                    "playlistId": pid,
                    "image": image
                })
        
        # Eliminar cada playlist
        for i, playlist_id in enumerate(playlist_ids):
            # Verificar si fue cancelada
            if is_cancelled():
                print(f"\n=== Deletion Cancelled by User ===")
                break
            
            playlist_info = playlist_map.get(playlist_id, {})
            playlist_name = playlist_info.get("title", "Unknown")
            
            print(f"\n[{i+1}/{len(playlist_ids)}] Deleting playlist: '{playlist_name}'")
            
            if not playlist_id:
                print(f"⚠️  Skipping - No playlist ID")
                results["failed"] += 1
                results["playlists"].append({
                    "name": playlist_name,
                    "status": "failed",
                    "reason": "No playlist ID"
                })
                update_progress(i, "failed", reason="No playlist ID")
                continue
            
            try:
                update_progress(i, "deleting")
                
                # Eliminar la playlist
                ytmusic.delete_playlist(playlist_id)
                
                results["deleted"] += 1
                results["playlists"].append({
                    "name": playlist_name,
                    "status": "deleted",
                    "playlistId": playlist_id
                })
                update_progress(i, "deleted", name=playlist_name)
                print(f"✅ Deleted: '{playlist_name}'")
                
            except Exception as e:
                print(f"❌ Error deleting '{playlist_name}': {str(e)}")
                results["failed"] += 1
                results["playlists"].append({
                    "name": playlist_name,
                    "status": "failed",
                    "reason": str(e)
                })
                update_progress(i, "failed", name=playlist_name, reason=str(e))
        
        print(f"\n=== Deletion Complete ===")
        print(f"Total: {results['total_playlists']} | Deleted: {results['deleted']} | Failed: {results['failed']}")
        
    except Exception as e:
        print(f"Error during deletion: {str(e)}")
        raise Exception(f"Failed during deletion: {str(e)}")
    
    return results

