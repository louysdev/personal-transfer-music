import { useState, useEffect, useRef } from "react";
import { Button } from "../ui/button";
import { Textarea } from "../ui/textarea";
import {
    AlertDialog,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogHeader,
    AlertDialogTitle,
    AlertDialogTrigger,
    AlertDialogFooter,
    AlertDialogAction,
} from "@/components/ui/alert-dialog";
import { Card, CardContent } from "@/components/ui/card";
import { FaExclamationCircle, FaGithub, FaSpotify, FaSpinner, FaCheck, FaTimes, FaClock, FaChevronDown, FaChevronUp, FaMusic } from "react-icons/fa";
import { CheckIcon } from "@/components/ui/check.tsx";

interface Track {
    index: number;
    name: string;
    artists: string[];
    album: string;
    image?: string;
    duration_ms?: number;
}

interface Playlist {
    id: string;
    name: string;
    total_tracks: number;
    link: string;
    image?: string;
}

interface PlaylistWithTracks extends Playlist {
    tracks: Track[];
    loadedTracks: boolean;
    loadingTracks: boolean;
    selectedTracks: Set<number>;
    expanded: boolean;
}

interface PlaylistStatus {
    name: string;
    status: string;
    id: string;
    image?: string;
    total_tracks?: number;
    found_tracks?: number;
    missed_tracks?: number;
    missed_tracks_list?: string[];
    reason?: string;
}

interface TransferProgress {
    status: string;
    total_playlists: number;
    processed: number;
    successful: number;
    failed: number;
    skipped: number;
    playlists: PlaylistStatus[];
    error?: string;
}

export default function TransferAll() {
    const [authHeaders, setAuthHeaders] = useState("");
    const [spotifyToken, setSpotifyToken] = useState("");
    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [serverOnline, setServerOnline] = useState(false);
    const [connectionDialogOpen, setConnectionDialogOpen] = useState(false);
    const [connectionError, setConnectionError] = useState(false);
    const [errorMessage, setErrorMessage] = useState<React.ReactNode>("");
    const [transferError, setTransferError] = useState(false);
    const [transferErrorMessage, setTransferErrorMessage] = useState<React.ReactNode>("");
    const [isTransferring, setIsTransferring] = useState(false);
    const [transferDialog, setTransferDialog] = useState(false);
    const [transferProgress, setTransferProgress] = useState<TransferProgress | null>(null);
    const [playlists, setPlaylists] = useState<PlaylistWithTracks[]>([]);
    const [selectedPlaylists, setSelectedPlaylists] = useState<Set<string>>(new Set());
    const [isLoadingPlaylists, setIsLoadingPlaylists] = useState(false);
    const [showPlaylistSelection, setShowPlaylistSelection] = useState(false);
    const [trackSelectionMode, setTrackSelectionMode] = useState(false);
    const [selectionDialogOpen, setSelectionDialogOpen] = useState(false);
    const [currentTransferId, setCurrentTransferId] = useState<string | null>(null);
    const abortControllerRef = useRef<AbortController | null>(null);
    const pollIntervalRef = useRef<NodeJS.Timeout | null>(null);

    // Verificar si el usuario ya está autenticado al cargar el componente
    useEffect(() => {
        checkAuthStatus();
        const urlParams = new URLSearchParams(window.location.search);
        if (urlParams.get('auth') === 'success') {
            checkAuthStatus();
            window.history.replaceState({}, '', '/create-playlist');
        }
    }, []);

    async function checkAuthStatus() {
        try {
            const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/token`, {
                method: "GET",
                credentials: "include",
            });
            
            if (res.ok) {
                const data = await res.json();
                if (data.authenticated) {
                    setIsAuthenticated(true);
                    setSpotifyToken(data.token);
                }
            }
        } catch (error) {
            console.error("Error checking auth status:", error);
        }
    }

    async function loginWithSpotify() {
        window.location.href = `${import.meta.env.VITE_API_URL}/auth/spotify`;
    }

    async function logout() {
        try {
            await fetch(`${import.meta.env.VITE_API_URL}/auth/logout`, {
                method: "POST",
                credentials: "include",
            });
            setIsAuthenticated(false);
            setSpotifyToken("");
            setPlaylists([]);
            setSelectedPlaylists(new Set());
            setShowPlaylistSelection(false);
            setTrackSelectionMode(false);
        } catch (error) {
            console.error("Error logging out:", error);
        }
    }

    const loadPlaylists = async () => {
        setIsLoadingPlaylists(true);
        setTransferError(false);
        
        try {
            const res = await fetch(`${import.meta.env.VITE_API_URL}/playlists`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                credentials: 'include',
                body: JSON.stringify({}),
            });

            const data = await res.json();

            if (res.ok) {
                const playlistsWithTracks: PlaylistWithTracks[] = data.playlists.map((p: Playlist) => ({
                    ...p,
                    tracks: [],
                    loadedTracks: false,
                    loadingTracks: false,
                    selectedTracks: new Set<number>(),
                    expanded: false
                }));
                setPlaylists(playlistsWithTracks);
                setSelectedPlaylists(new Set(data.playlists.map((p: Playlist) => p.id)));
                setShowPlaylistSelection(true);
                setSelectionDialogOpen(true);
            } else {
                setTransferError(true);
                setTransferErrorMessage(
                    <>
                        <FaExclamationCircle className="inline mr-2" />
                        {data.message || "Failed to load playlists"}
                    </>
                );
            }
        } catch (error) {
            setTransferError(true);
            setTransferErrorMessage(
                <>
                    <FaExclamationCircle className="inline mr-2" />
                    Network error. Could not connect to server.
                </>
            );
        } finally {
            setIsLoadingPlaylists(false);
        }
    };

    const loadPlaylistTracks = async (playlistId: string) => {
        const playlistIndex = playlists.findIndex(p => p.id === playlistId);
        if (playlistIndex === -1) return;

        // Si ya tiene las canciones cargadas, solo expandir/colapsar
        if (playlists[playlistIndex].loadedTracks) {
            togglePlaylistExpanded(playlistId);
            return;
        }

        // Marcar como cargando
        setPlaylists(prev => prev.map(p => 
            p.id === playlistId ? { ...p, loadingTracks: true } : p
        ));

        try {
            const res = await fetch(`${import.meta.env.VITE_API_URL}/playlist-tracks/${playlistId}`, {
                method: "GET",
                credentials: 'include',
            });

            const data = await res.json();

            if (res.ok) {
                setPlaylists(prev => prev.map(p => 
                    p.id === playlistId 
                        ? { 
                            ...p, 
                            tracks: data.tracks, 
                            loadedTracks: true, 
                            loadingTracks: false,
                            selectedTracks: new Set(data.tracks.map((t: Track) => t.index)),
                            expanded: true
                        } 
                        : p
                ));
            } else {
                setPlaylists(prev => prev.map(p => 
                    p.id === playlistId ? { ...p, loadingTracks: false } : p
                ));
            }
        } catch (error) {
            setPlaylists(prev => prev.map(p => 
                p.id === playlistId ? { ...p, loadingTracks: false } : p
            ));
        }
    };

    const togglePlaylistExpanded = (playlistId: string) => {
        setPlaylists(prev => prev.map(p => 
            p.id === playlistId ? { ...p, expanded: !p.expanded } : p
        ));
    };

    const togglePlaylistSelection = (playlistId: string) => {
        const newSelected = new Set(selectedPlaylists);
        if (newSelected.has(playlistId)) {
            newSelected.delete(playlistId);
        } else {
            newSelected.add(playlistId);
        }
        setSelectedPlaylists(newSelected);
    };

    const toggleSelectAllPlaylists = () => {
        if (selectedPlaylists.size === playlists.length) {
            setSelectedPlaylists(new Set());
        } else {
            setSelectedPlaylists(new Set(playlists.map(p => p.id)));
        }
    };

    const toggleTrackSelection = (playlistId: string, trackIndex: number) => {
        setPlaylists(prev => prev.map(p => {
            if (p.id !== playlistId) return p;
            const newSelectedTracks = new Set(p.selectedTracks);
            if (newSelectedTracks.has(trackIndex)) {
                newSelectedTracks.delete(trackIndex);
            } else {
                newSelectedTracks.add(trackIndex);
            }
            return { ...p, selectedTracks: newSelectedTracks };
        }));
        setTrackSelectionMode(true);
    };

    const toggleSelectAllTracks = (playlistId: string) => {
        setPlaylists(prev => prev.map(p => {
            if (p.id !== playlistId) return p;
            const allSelected = p.selectedTracks.size === p.tracks.length;
            return {
                ...p,
                selectedTracks: allSelected ? new Set() : new Set(p.tracks.map(t => t.index))
            };
        }));
        setTrackSelectionMode(true);
    };

    const formatDuration = (ms: number) => {
        const minutes = Math.floor(ms / 60000);
        const seconds = Math.floor((ms % 60000) / 1000);
        return `${minutes}:${seconds.toString().padStart(2, '0')}`;
    };

    async function testConnection() {
        setConnectionDialogOpen(true);
        setConnectionError(false);
        setServerOnline(false);

        try {
            const res = await fetch(`${import.meta.env.VITE_API_URL}/`, {
                method: "GET",
                headers: {
                    "Content-Type": "application/json",
                },
            });
            const data = await res.json();
            if (res.ok) {
                setServerOnline(true);
                console.log(data);
            } else if (res.status === 500) {
                setConnectionError(true);
                setErrorMessage(
                    <>
                        Server Error (500). The server likely hit a timeout.
                        Please try again later or{" "}
                        <a
                            href="https://github.com/Pushan2005/SpotTransfer/issues/new/choose"
                            className="text-blue-500 hover:underline"
                        >
                            report this issue on GitHub
                        </a>
                        .
                    </>
                );
            }
        } catch {
            setConnectionError(true);
            setErrorMessage(
                <>
                    Unable to connect to server. If this issue persists, please
                    contact me or{" "}
                    <a
                        href="https://github.com/Pushan2005/SpotTransfer/issues/new/choose"
                        className="text-blue-500 hover:underline"
                    >
                        open an issue on GitHub
                    </a>
                </>
            );
        } finally {
            setConnectionDialogOpen(false);
        }
    }

    async function cancelTransfer() {
        // Cancelar la petición fetch si está en curso
        if (abortControllerRef.current) {
            abortControllerRef.current.abort();
            abortControllerRef.current = null;
        }
        // Cancelar el polling
        if (pollIntervalRef.current) {
            clearInterval(pollIntervalRef.current);
            pollIntervalRef.current = null;
        }
        
        // Notificar al backend para cancelar la transferencia
        if (currentTransferId) {
            try {
                await fetch(`${import.meta.env.VITE_API_URL}/transfer-cancel/${currentTransferId}`, {
                    method: "POST",
                    credentials: "include",
                });
            } catch (error) {
                console.error("Error cancelling transfer on backend:", error);
            }
        }
        
        setIsTransferring(false);
        setTransferDialog(false);
        setTransferProgress(null);
        setCurrentTransferId(null);
    }

    async function transferAllPlaylists() {
        // Determinar si estamos transfiriendo con selección de canciones
        const hasTrackSelection = trackSelectionMode && playlists.some(p => p.loadedTracks);
        
        let endpoint = `${import.meta.env.VITE_API_URL}/transfer-all`;
        let body: { 
            playlist_ids?: string[], 
            spotify_token?: string, 
            auth_headers?: string,
            playlists?: Array<{
                id: string,
                name: string,
                image?: string,
                tracks: Array<{ name: string, artists: string[], album: string }>
            }>
        } = {};
        
        if (hasTrackSelection) {
            // Usar el endpoint de transferencia con canciones seleccionadas
            endpoint = `${import.meta.env.VITE_API_URL}/transfer-selected`;
            
            // Construir el array de playlists con las canciones seleccionadas
            const playlistsToTransfer = playlists
                .filter(p => selectedPlaylists.has(p.id))
                .map(p => {
                    // Si la playlist tiene canciones cargadas, filtrar las seleccionadas
                    if (p.loadedTracks && p.tracks.length > 0) {
                        const selectedTracksList = p.tracks.filter(t => p.selectedTracks.has(t.index));
                        return {
                            id: p.id,
                            name: p.name,
                            image: p.image,
                            tracks: selectedTracksList.map(t => ({
                                name: t.name,
                                artists: t.artists,
                                album: t.album
                            }))
                        };
                    }
                    return null;
                })
                .filter((p): p is NonNullable<typeof p> => p !== null && p.tracks.length > 0);
            
            if (playlistsToTransfer.length === 0) {
                setTransferError(true);
                setTransferErrorMessage("No tracks selected for transfer");
                return;
            }
            
            body.playlists = playlistsToTransfer;
        } else {
            // Si hay playlists seleccionadas, solo enviar esas
            if (showPlaylistSelection && selectedPlaylists.size > 0) {
                body.playlist_ids = Array.from(selectedPlaylists);
            }
        }
        
        // Siempre enviar los auth_headers si están disponibles
        if (authHeaders && authHeaders.trim() !== '') {
            body.auth_headers = authHeaders;
        }
        
        // Agregar spotify token si está disponible
        if (spotifyToken) {
            body.spotify_token = spotifyToken;
        }

        abortControllerRef.current = new AbortController();

        try {
            setTransferDialog(true);
            setIsTransferring(true);
            setTransferProgress(null);
            
            const res = await fetch(endpoint, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                credentials: "include",
                body: JSON.stringify(body),
                signal: abortControllerRef.current.signal,
            });
            const data = await res.json();

            if (res.ok && res.status === 202) {
                // Transfer iniciado, guardar el ID y comenzar polling
                setCurrentTransferId(data.transfer_id);
                startPolling(data.transfer_id);
            } else if (res.status === 500) {
                setTransferError(true);
                setTransferErrorMessage(
                    <>
                        Server timeout while transferring playlists. Please try again
                        or{" "}
                        <a
                            href="https://github.com/Pushan2005/SpotTransfer/issues/new/choose"
                            className="text-blue-500 hover:underline"
                        >
                            report this issue
                        </a>
                    </>
                );
                setIsTransferring(false);
                setTransferDialog(false);
            } else {
                setTransferError(true);
                setTransferErrorMessage(
                    data.message || "Failed to transfer playlists"
                );
                setIsTransferring(false);
                setTransferDialog(false);
            }
        } catch (error: unknown) {
            if (error instanceof Error && error.name === 'AbortError') {
                // Transferencia cancelada por el usuario
                console.log('Transfer cancelled by user');
            } else {
                setTransferError(true);
                setTransferErrorMessage("Network error while transferring playlists");
                setIsTransferring(false);
                setTransferDialog(false);
            }
        } finally {
            abortControllerRef.current = null;
        }
    }

    async function startPolling(id: string) {
        pollIntervalRef.current = setInterval(async () => {
            try {
                const res = await fetch(`${import.meta.env.VITE_API_URL}/transfer-status/${id}`, {
                    method: "GET",
                    credentials: "include",
                });
                
                if (res.ok) {
                    const data: TransferProgress = await res.json();
                    setTransferProgress(data);
                    
                    // Detener polling si la transferencia terminó
                    if (data.status === "completed" || data.status === "error") {
                        if (pollIntervalRef.current) {
                            clearInterval(pollIntervalRef.current);
                            pollIntervalRef.current = null;
                        }
                        setIsTransferring(false);
                    }
                }
            } catch (error) {
                console.error("Error polling status:", error);
            }
        }, 1000);
    }

    function getStatusIcon(status: string) {
        switch (status) {
            case "pending":
                return <FaClock className="w-4 h-4 text-muted-foreground" />;
            case "processing":
            case "fetching_details":
            case "searching_songs":
            case "checking_existing":
            case "creating":
            case "updating":
                return <FaSpinner className="w-4 h-4 text-primary animate-spin" />;
            case "created":
            case "updated":
            case "up_to_date":
                return <FaCheck className="w-4 h-4 text-green-500" />;
            case "failed":
            case "error":
                return <FaTimes className="w-4 h-4 text-destructive" />;
            case "skipped":
                return <FaClock className="w-4 h-4 text-yellow-500" />;
            default:
                return <FaClock className="w-4 h-4 text-muted-foreground" />;
        }
    }

    function getStatusText(status: string) {
        const statusMap: {[key: string]: string} = {
            "pending": "Pendiente",
            "processing": "Procesando...",
            "fetching_details": "Obteniendo detalles...",
            "searching_songs": "Buscando canciones...",
            "checking_existing": "Verificando existencia...",
            "creating": "Creando playlist...",
            "updating": "Actualizando playlist...",
            "created": "Creada",
            "updated": "Actualizada",
            "up_to_date": "Sin cambios",
            "failed": "Error",
            "skipped": "Omitida"
        };
        return statusMap[status] || status;
    }

    return (
        <>
            <div className="w-full flex items-center justify-around">
                <div className="flex flex-col gap-3 items-center justify-center">
                    <div className="space-y-1">
                        <h1 className="text-lg font-semibold">
                            Paste YouTube Music headers here
                        </h1>
                    </div>
                    <Textarea
                        placeholder="Paste your YouTube Music headers here"
                        value={authHeaders}
                        onChange={(e) => setAuthHeaders(e.target.value)}
                        id="auth-headers"
                        className="w-[40vw] h-[40vh]"
                    />
                </div>

                <div className="flex flex-col gap-8 items-start justify-center">
                    <div className="flex flex-col w-full gap-3 items-center justify-center">
                        <div className="space-y-1 w-full">
                            <h1 className="text-lg font-semibold w-full">
                                You need to be connected to the server
                            </h1>
                            {serverOnline && (
                                <p className="text-green-500 text-sm">
                                    Connection Successful
                                </p>
                            )}
                        </div>
                        <AlertDialog
                            open={connectionDialogOpen}
                            onOpenChange={setConnectionDialogOpen}
                        >
                            <AlertDialogTrigger asChild>
                                <Button
                                    className="w-full"
                                    onClick={testConnection}
                                >
                                    Connect
                                </Button>
                            </AlertDialogTrigger>
                            <AlertDialogContent>
                                <AlertDialogHeader>
                                    <AlertDialogTitle>
                                        Requesting connection...
                                    </AlertDialogTitle>
                                    <AlertDialogDescription>
                                        Please wait till the server comes
                                        online. This may take upto a minute.
                                    </AlertDialogDescription>
                                </AlertDialogHeader>
                            </AlertDialogContent>
                        </AlertDialog>
                    </div>

                    <div className="flex flex-col gap-3 items-start justify-center w-full">
                        <div className="space-y-1">
                            <h1 className="text-lg font-semibold">
                                Connect your Spotify Account
                            </h1>
                            <div className="flex items-center gap-2">
                                <FaExclamationCircle className="text-blue-500" />
                                <p className="text-sm text-gray-500">
                                    You need to authenticate with Spotify to access your playlists
                                </p>
                            </div>
                            {isAuthenticated && (
                                <div className="flex items-center gap-2 mt-2">
                                    <CheckIcon />
                                    <p className="text-sm text-green-400">
                                        Authenticated with Spotify
                                    </p>
                                </div>
                            )}
                        </div>
                        
                        {!isAuthenticated ? (
                            <Button
                                className="w-full flex items-center gap-2"
                                onClick={loginWithSpotify}
                            >
                                <FaSpotify className="w-5 h-5" />
                                Login with Spotify
                            </Button>
                        ) : (
                            <div className="w-full flex gap-2">
                                <Button
                                    className="flex-1"
                                    variant="outline"
                                    onClick={logout}
                                >
                                    Logout
                                </Button>
                            </div>
                        )}
                        
                        {/* Cargar playlists para selección */}
                        {isAuthenticated && !isTransferring && (
                            <Button
                                onClick={() => {
                                    if (showPlaylistSelection && playlists.length > 0) {
                                        setSelectionDialogOpen(true);
                                    } else {
                                        loadPlaylists();
                                    }
                                }}
                                disabled={isLoadingPlaylists}
                                className="w-full"
                                variant="outline"
                            >
                                {isLoadingPlaylists ? (
                                    <>
                                        <FaSpinner className="animate-spin mr-2" />
                                        Loading Playlists...
                                    </>
                                ) : showPlaylistSelection ? (
                                    <>
                                        <FaSpotify className="mr-2" />
                                        Edit Selection ({selectedPlaylists.size} playlists)
                                    </>
                                ) : (
                                    <>
                                        <FaSpotify className="mr-2" />
                                        Select Playlists to Transfer
                                    </>
                                )}
                            </Button>
                        )}

                        {/* Modal de selección de playlists y canciones */}
                        <AlertDialog open={selectionDialogOpen} onOpenChange={setSelectionDialogOpen}>
                            <AlertDialogContent className="max-w-5xl max-h-[90vh] overflow-hidden flex flex-col">
                                <AlertDialogHeader>
                                    <AlertDialogTitle>
                                        <div className="flex items-center gap-2">
                                            <FaSpotify className="text-green-500" />
                                            Select Playlists and Tracks
                                        </div>
                                    </AlertDialogTitle>
                                    <AlertDialogDescription>
                                        Select the playlists you want to transfer. Click on a playlist to expand and select individual tracks.
                                    </AlertDialogDescription>
                                </AlertDialogHeader>

                                <div className="flex-1 overflow-hidden flex flex-col">
                                    {/* Controles superiores */}
                                    <div className="flex items-center justify-between py-3 border-b">
                                        <div className="text-sm">
                                            <span className="font-semibold">{selectedPlaylists.size}</span> of{' '}
                                            <span className="font-semibold">{playlists.length}</span> playlists selected
                                            {trackSelectionMode && (
                                                <span className="ml-2 text-gray-500">
                                                    ({playlists.filter(p => p.loadedTracks && selectedPlaylists.has(p.id)).reduce((acc, p) => acc + p.selectedTracks.size, 0)} tracks)
                                                </span>
                                            )}
                                        </div>
                                        <label className="flex items-center gap-2 cursor-pointer">
                                            <input
                                                type="checkbox"
                                                checked={selectedPlaylists.size === playlists.length}
                                                onChange={toggleSelectAllPlaylists}
                                                className="w-4 h-4 cursor-pointer"
                                            />
                                            <span className="text-sm">Select All Playlists</span>
                                        </label>
                                    </div>

                                    {/* Lista de playlists con scroll */}
                                    <div className="flex-1 overflow-y-auto py-3 space-y-2">
                                        {playlists.map((playlist) => (
                                            <div key={playlist.id} className="space-y-1">
                                                <div
                                                    className={`flex items-center gap-3 p-3 rounded-lg cursor-pointer transition-all ${
                                                        selectedPlaylists.has(playlist.id)
                                                            ? 'bg-green-50 dark:bg-green-900/20 border-2 border-green-500'
                                                            : 'bg-gray-50 dark:bg-gray-800/50 border-2 border-transparent hover:bg-gray-100 dark:hover:bg-gray-700'
                                                    }`}
                                                >
                                                    <input
                                                        type="checkbox"
                                                        checked={selectedPlaylists.has(playlist.id)}
                                                        onChange={() => togglePlaylistSelection(playlist.id)}
                                                        className="w-5 h-5 cursor-pointer accent-green-500"
                                                        onClick={(e) => e.stopPropagation()}
                                                    />
                                                    {playlist.image ? (
                                                        <img 
                                                            src={playlist.image} 
                                                            alt={playlist.name}
                                                            className="w-14 h-14 rounded-lg object-cover shadow-sm"
                                                        />
                                                    ) : (
                                                        <div className="w-14 h-14 bg-gray-300 dark:bg-gray-600 rounded-lg flex items-center justify-center">
                                                            <FaMusic className="text-gray-500 w-6 h-6" />
                                                        </div>
                                                    )}
                                                    <div 
                                                        className="flex-1 min-w-0"
                                                        onClick={() => loadPlaylistTracks(playlist.id)}
                                                    >
                                                        <p className="font-semibold truncate text-base">{playlist.name}</p>
                                                        <p className="text-sm text-gray-500">
                                                            {playlist.loadedTracks 
                                                                ? <span className={playlist.selectedTracks.size < playlist.tracks.length ? 'text-orange-500' : 'text-green-500'}>
                                                                    {playlist.selectedTracks.size}/{playlist.tracks.length} tracks selected
                                                                  </span>
                                                                : `${playlist.total_tracks} tracks`
                                                            }
                                                        </p>
                                                    </div>
                                                    <button 
                                                        onClick={() => loadPlaylistTracks(playlist.id)}
                                                        className="p-3 hover:bg-gray-200 dark:hover:bg-gray-600 rounded-lg transition-colors"
                                                    >
                                                        {playlist.loadingTracks ? (
                                                            <FaSpinner className="w-5 h-5 animate-spin" />
                                                        ) : playlist.expanded ? (
                                                            <FaChevronUp className="w-5 h-5" />
                                                        ) : (
                                                            <FaChevronDown className="w-5 h-5" />
                                                        )}
                                                    </button>
                                                </div>
                                                
                                                {/* Lista de canciones expandida */}
                                                {playlist.expanded && playlist.loadedTracks && (
                                                    <div className="ml-6 border-l-3 border-green-400 pl-4 py-2 space-y-1 bg-gray-50/50 dark:bg-gray-800/30 rounded-r-lg">
                                                        <div className="flex items-center justify-between py-2 px-2">
                                                            <span className="text-sm text-gray-600 dark:text-gray-400">
                                                                {playlist.selectedTracks.size} of {playlist.tracks.length} tracks selected
                                                            </span>
                                                            <button
                                                                onClick={() => toggleSelectAllTracks(playlist.id)}
                                                                className="text-sm text-green-600 hover:text-green-700 font-medium"
                                                            >
                                                                {playlist.selectedTracks.size === playlist.tracks.length ? 'Deselect All' : 'Select All'}
                                                            </button>
                                                        </div>
                                                        <div className="max-h-64 overflow-y-auto space-y-1 pr-2">
                                                            {playlist.tracks.map((track) => (
                                                                <div
                                                                    key={track.index}
                                                                    onClick={() => toggleTrackSelection(playlist.id, track.index)}
                                                                    className={`flex items-center gap-3 p-2 rounded-lg cursor-pointer transition-all ${
                                                                        playlist.selectedTracks.has(track.index)
                                                                            ? 'bg-green-100 dark:bg-green-900/30'
                                                                            : 'hover:bg-gray-100 dark:hover:bg-gray-700/50'
                                                                    }`}
                                                                >
                                                                    <input
                                                                        type="checkbox"
                                                                        checked={playlist.selectedTracks.has(track.index)}
                                                                        onChange={() => toggleTrackSelection(playlist.id, track.index)}
                                                                        className="w-4 h-4 cursor-pointer accent-green-500"
                                                                        onClick={(e) => e.stopPropagation()}
                                                                    />
                                                                    {track.image ? (
                                                                        <img 
                                                                            src={track.image} 
                                                                            alt={track.name}
                                                                            className="w-10 h-10 rounded object-cover"
                                                                        />
                                                                    ) : (
                                                                        <div className="w-10 h-10 bg-gray-200 dark:bg-gray-700 rounded flex items-center justify-center">
                                                                            <FaMusic className="text-gray-400 w-4 h-4" />
                                                                        </div>
                                                                    )}
                                                                    <div className="flex-1 min-w-0">
                                                                        <p className="text-sm font-medium truncate">{track.name}</p>
                                                                        <p className="text-xs text-gray-500 truncate">
                                                                            {track.artists.join(", ")} • {track.album}
                                                                        </p>
                                                                    </div>
                                                                    {track.duration_ms && (
                                                                        <span className="text-xs text-gray-400 font-mono">
                                                                            {formatDuration(track.duration_ms)}
                                                                        </span>
                                                                    )}
                                                                </div>
                                                            ))}
                                                        </div>
                                                    </div>
                                                )}
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                <AlertDialogFooter className="border-t pt-4">
                                    <Button
                                        variant="outline"
                                        onClick={() => {
                                            setSelectionDialogOpen(false);
                                            setShowPlaylistSelection(false);
                                            setSelectedPlaylists(new Set());
                                            setPlaylists([]);
                                            setTrackSelectionMode(false);
                                        }}
                                    >
                                        Cancel
                                    </Button>
                                    <Button
                                        onClick={() => setSelectionDialogOpen(false)}
                                        disabled={selectedPlaylists.size === 0}
                                        className="bg-green-600 hover:bg-green-700"
                                    >
                                        Confirm Selection ({selectedPlaylists.size} playlists)
                                    </Button>
                                </AlertDialogFooter>
                            </AlertDialogContent>
                        </AlertDialog>
                        
                        <AlertDialog
                            open={transferDialog}
                            onOpenChange={(open) => {
                                // Solo permitir cerrar si no está transfiriendo
                                if (!isTransferring) {
                                    setTransferDialog(open);
                                }
                            }}
                        >
                            <AlertDialogTrigger asChild>
                                <Button
                                    disabled={
                                        !authHeaders ||
                                        !isAuthenticated ||
                                        authHeaders.trim() === "" ||
                                        !serverOnline ||
                                        !showPlaylistSelection ||
                                        selectedPlaylists.size === 0 ||
                                        (trackSelectionMode && playlists.filter(p => p.loadedTracks && selectedPlaylists.has(p.id)).every(p => p.selectedTracks.size === 0))
                                    }
                                    className="w-full bg-green-600 hover:bg-green-700"
                                    onClick={transferAllPlaylists}
                                >
                                    {(() => {
                                        if (trackSelectionMode) {
                                            const playlistsWithSelection = playlists.filter(p => 
                                                selectedPlaylists.has(p.id) && p.loadedTracks && p.selectedTracks.size > 0
                                            );
                                            const totalTracks = playlistsWithSelection.reduce((acc, p) => acc + p.selectedTracks.size, 0);
                                            if (totalTracks > 0) {
                                                return `Transfer ${totalTracks} Track${totalTracks !== 1 ? 's' : ''} from ${playlistsWithSelection.length} Playlist${playlistsWithSelection.length !== 1 ? 's' : ''}`;
                                            }
                                        }
                                        
                                        return `Transfer ${selectedPlaylists.size} Selected Playlist${selectedPlaylists.size !== 1 ? 's' : ''}`;
                                    })()}
                                </Button>
                            </AlertDialogTrigger>
                            <AlertDialogContent className="max-w-4xl max-h-[85vh]">
                                <AlertDialogHeader>
                                    <AlertDialogTitle>
                                        <div className="flex items-center gap-2">
                                            {isTransferring ? (
                                                <>
                                                    <FaSpinner className="animate-spin" />
                                                    Transferring playlists...
                                                </>
                                            ) : transferProgress?.status === "completed" ? (
                                                <>
                                                    <CheckIcon />
                                                    Transfer Complete!
                                                </>
                                            ) : (
                                                "Transfer Status"
                                            )}
                                        </div>
                                    </AlertDialogTitle>
                                    <AlertDialogDescription>
                                        {isTransferring ? (
                                            <span>This may take several minutes. Please do not close this window.</span>
                                        ) : transferProgress?.status === "completed" ? (
                                            <span>All playlists have been processed successfully.</span>
                                        ) : (
                                            <span>Transfer details below.</span>
                                        )}
                                    </AlertDialogDescription>
                                </AlertDialogHeader>

                                {transferProgress && (
                                    <div className="mt-4">
                                        {/* Estadísticas generales */}
                                        <div className="grid grid-cols-4 gap-3 mb-4">
                                            <Card className="border-border/50">
                                                <CardContent className="p-4 text-center">
                                                    <p className="text-xs text-muted-foreground mb-1">Processed</p>
                                                    <p className="text-xl font-bold">{transferProgress.processed}/{transferProgress.total_playlists}</p>
                                                </CardContent>
                                            </Card>
                                            <Card className="border-green-500/20 bg-green-500/5">
                                                <CardContent className="p-4 text-center">
                                                    <p className="text-xs text-muted-foreground mb-1">Successful</p>
                                                    <p className="text-xl font-bold text-green-500">{transferProgress.successful}</p>
                                                </CardContent>
                                            </Card>
                                            <Card className="border-yellow-500/20 bg-yellow-500/5">
                                                <CardContent className="p-4 text-center">
                                                    <p className="text-xs text-muted-foreground mb-1">Skipped</p>
                                                    <p className="text-xl font-bold text-yellow-500">{transferProgress.skipped}</p>
                                                </CardContent>
                                            </Card>
                                            <Card className="border-red-500/20 bg-red-500/5">
                                                <CardContent className="p-4 text-center">
                                                    <p className="text-xs text-muted-foreground mb-1">Failed</p>
                                                    <p className="text-xl font-bold text-red-500">{transferProgress.failed}</p>
                                                </CardContent>
                                            </Card>
                                        </div>

                                        {/* Lista de playlists con scroll */}
                                        <div className="space-y-2 max-h-[45vh] overflow-y-auto pr-2 scrollbar-custom">
                                            {transferProgress.playlists.map((playlist, index) => (
                                                <Card
                                                    key={index}
                                                    className="border-border/50"
                                                >
                                                    <CardContent className="flex items-center gap-3 p-3">
                                                        {/* Carátula de la playlist */}
                                                        {playlist.image ? (
                                                            <img 
                                                                src={playlist.image} 
                                                                alt={playlist.name}
                                                                className="w-12 h-12 rounded object-cover flex-shrink-0"
                                                            />
                                                        ) : (
                                                            <div className="w-12 h-12 bg-muted rounded flex items-center justify-center flex-shrink-0">
                                                                <FaSpotify className="w-6 h-6 text-muted-foreground" />
                                                            </div>
                                                        )}
                                                        
                                                        {/* Información de la playlist */}
                                                        <div className="flex-1 min-w-0">
                                                            <p className="font-medium truncate">{playlist.name}</p>
                                                            <p className="text-sm text-muted-foreground">
                                                                {getStatusText(playlist.status)}
                                                                {playlist.total_tracks && (
                                                                    <span className="ml-2">
                                                                        ({playlist.found_tracks}/{playlist.total_tracks} canciones)
                                                                    </span>
                                                                )}
                                                            </p>
                                                            {playlist.reason && (
                                                                <p className="text-xs text-destructive truncate">{playlist.reason}</p>
                                                            )}
                                                        </div>
                                                        
                                                        {/* Icono de estado */}
                                                        <div className="flex-shrink-0">
                                                            {getStatusIcon(playlist.status)}
                                                        </div>
                                                    </CardContent>
                                                </Card>
                                            ))}
                                        </div>

                                        {/* Mensaje de error */}
                                        {transferProgress.status === "error" && (
                                            <Card className="mt-4 border-destructive/50 bg-destructive/10">
                                                <CardContent className="p-4">
                                                    <div className="flex items-center gap-2 mb-1">
                                                        <FaTimes className="text-destructive" />
                                                        <p className="text-destructive font-semibold">Error during transfer</p>
                                                    </div>
                                                    {transferProgress.error && (
                                                        <p className="text-sm text-muted-foreground">{transferProgress.error}</p>
                                                    )}
                                                </CardContent>
                                            </Card>
                                        )}

                                        {/* Mensaje de completado */}
                                        {transferProgress.status === "completed" && (
                                            <Card className="mt-4 border-green-500/50 bg-green-500/10">
                                                <CardContent className="p-4">
                                                    <p className="text-sm text-foreground">
                                                        Please consider starring the project on GitHub. It's free and helps a lot!
                                                    </p>
                                                </CardContent>
                                            </Card>
                                        )}
                                    </div>
                                )}
                                
                                <AlertDialogFooter>
                                    {transferProgress?.status === "completed" && (
                                        <Button variant="outline" asChild>
                                            <a
                                                className="flex items-center gap-2"
                                                href="https://github.com/Pushan2005/SpotTransfer"
                                                target="_blank"
                                                rel="noopener noreferrer"
                                            >
                                                <FaGithub className="w-4 h-4" />
                                                Star on GitHub
                                            </a>
                                        </Button>
                                    )}
                                    {isTransferring ? (
                                        <Button
                                            variant="destructive"
                                            onClick={cancelTransfer}
                                        >
                                            Cancel Transfer
                                        </Button>
                                    ) : (
                                        <AlertDialogAction>
                                            Close
                                        </AlertDialogAction>
                                    )}
                                </AlertDialogFooter>
                            </AlertDialogContent>
                        </AlertDialog>
                    </div>
                </div>
            </div>

            {/* Connection Error Dialog */}
            <AlertDialog
                open={connectionError}
                onOpenChange={setConnectionError}
            >
                <AlertDialogContent>
                    <AlertDialogHeader>
                        <AlertDialogTitle>Connection Error</AlertDialogTitle>
                        <AlertDialogDescription>
                            {errorMessage}
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogAction
                            onClick={() => setConnectionError(false)}
                        >
                            Try Again
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>

            {/* Transfer Error Dialog */}
            <AlertDialog open={transferError} onOpenChange={setTransferError}>
                <AlertDialogContent>
                    <AlertDialogHeader>
                        <AlertDialogTitle>Transfer Error</AlertDialogTitle>
                        <AlertDialogDescription>
                            {transferErrorMessage}
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogAction onClick={() => setTransferError(false)}>
                            Try Again
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>
        </>
    );
}
