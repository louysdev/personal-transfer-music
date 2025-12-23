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
    AlertDialogCancel,
} from "@/components/ui/alert-dialog";
import { Card, CardContent } from "@/components/ui/card";
import { FaExclamationCircle, FaSpinner, FaCheck, FaTimes, FaTrash, FaYoutube, FaMusic } from "react-icons/fa";

interface YTMPlaylist {
    id: string;
    name: string;
    count: number;
    image?: string;
}

interface PlaylistStatus {
    name: string;
    status: string;
    playlistId?: string;
    reason?: string;
    image?: string;
}

interface DeleteProgress {
    status: string;
    total_playlists: number;
    deleted: number;
    failed: number;
    playlists: PlaylistStatus[];
    error?: string;
}

export default function DeleteAllPlaylists() {
    const [authHeaders, setAuthHeaders] = useState("");
    const [serverOnline, setServerOnline] = useState(false);
    const [hasCredentials, setHasCredentials] = useState(false);
    const [connectionError, setConnectionError] = useState(false);
    const [errorMessage, setErrorMessage] = useState<React.ReactNode>("");
    const [deleteError, setDeleteError] = useState(false);
    const [deleteErrorMessage, setDeleteErrorMessage] = useState<React.ReactNode>("");
    const [deleteProgress, setDeleteProgress] = useState<DeleteProgress | null>(null);
    const [deleteId, setDeleteId] = useState<string | null>(null);
    const [isDeleting, setIsDeleting] = useState(false);
    const [showConfirmDialog, setShowConfirmDialog] = useState(false);
    
    // Estados para selección de playlists
    const [playlists, setPlaylists] = useState<YTMPlaylist[]>([]);
    const [selectedPlaylists, setSelectedPlaylists] = useState<Set<string>>(new Set());
    const [isLoadingPlaylists, setIsLoadingPlaylists] = useState(false);
    const [showPlaylistSelection, setShowPlaylistSelection] = useState(false);
    const [selectionDialogOpen, setSelectionDialogOpen] = useState(false);
    
    const pollingIntervalRef = useRef<NodeJS.Timeout | null>(null);

    // Verificar estado del servidor y credenciales
    useEffect(() => {
        checkServerStatus();
        checkCredentials();
    }, []);

    const checkServerStatus = async () => {
        try {
            const res = await fetch(`${import.meta.env.VITE_API_URL}/`, {
                credentials: 'include',
            });
            if (res.ok) {
                setServerOnline(true);
                setConnectionError(false);
            }
        } catch (error) {
            setServerOnline(false);
            setConnectionError(true);
            setErrorMessage(
                <>
                    <FaExclamationCircle className="inline mr-2" />
                    Could not connect to server. Make sure the backend is running.
                </>
            );
        }
    };

    const checkCredentials = async () => {
        try {
            const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/credentials`, {
                credentials: 'include',
            });
            if (res.ok) {
                const data = await res.json();
                setHasCredentials(data.has_youtube);
            }
        } catch (error) {
            console.error("Error checking credentials:", error);
        }
    };

    const loadPlaylists = async () => {
        setIsLoadingPlaylists(true);
        setDeleteError(false);
        
        try {
            const body: { auth_headers?: string } = {};
            if (authHeaders.trim()) {
                body.auth_headers = authHeaders;
            }

            const res = await fetch(`${import.meta.env.VITE_API_URL}/ytm-playlists`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                credentials: 'include',
                body: JSON.stringify(body),
            });

            const data = await res.json();

            if (res.ok) {
                setPlaylists(data.playlists);
                setSelectedPlaylists(new Set(data.playlists.map((p: YTMPlaylist) => p.id)));
                setShowPlaylistSelection(true);
                setSelectionDialogOpen(true);
            } else {
                setDeleteError(true);
                setDeleteErrorMessage(
                    <>
                        <FaExclamationCircle className="inline mr-2" />
                        {data.message || "Failed to load playlists"}
                    </>
                );
            }
        } catch (error) {
            setDeleteError(true);
            setDeleteErrorMessage(
                <>
                    <FaExclamationCircle className="inline mr-2" />
                    Network error. Could not connect to server.
                </>
            );
        } finally {
            setIsLoadingPlaylists(false);
        }
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

    const startPolling = (id: string) => {
        if (pollingIntervalRef.current) {
            clearInterval(pollingIntervalRef.current);
        }

        pollingIntervalRef.current = setInterval(async () => {
            try {
                const res = await fetch(
                    `${import.meta.env.VITE_API_URL}/delete-status/${id}`,
                    {
                        credentials: 'include',
                    }
                );
                
                if (res.ok) {
                    const data: DeleteProgress = await res.json();
                    setDeleteProgress(data);

                    if (data.status === "completed" || data.status === "error" || data.status === "cancelled") {
                        if (pollingIntervalRef.current) {
                            clearInterval(pollingIntervalRef.current);
                            pollingIntervalRef.current = null;
                        }
                        setIsDeleting(false);
                        
                        if (data.status === "error") {
                            setDeleteError(true);
                            setDeleteErrorMessage(
                                <>
                                    <FaExclamationCircle className="inline mr-2" />
                                    {data.error || "An error occurred during deletion"}
                                </>
                            );
                        }
                    }
                }
            } catch (error) {
                console.error("Polling error:", error);
            }
        }, 1000);
    };

    const cancelDeletion = async () => {
        if (pollingIntervalRef.current) {
            clearInterval(pollingIntervalRef.current);
            pollingIntervalRef.current = null;
        }
        
        if (deleteId) {
            try {
                await fetch(`${import.meta.env.VITE_API_URL}/delete-cancel/${deleteId}`, {
                    method: "POST",
                    credentials: "include",
                });
            } catch (error) {
                console.error("Error cancelling deletion:", error);
            }
        }
        
        setIsDeleting(false);
        setDeleteId(null);
    };

    const handleDeleteSelected = async () => {
        setShowConfirmDialog(false);
        setIsDeleting(true);
        setDeleteError(false);
        setDeleteProgress(null);

        try {
            const body: { auth_headers?: string; playlist_ids: string[] } = {
                playlist_ids: Array.from(selectedPlaylists)
            };
            
            if (authHeaders.trim()) {
                body.auth_headers = authHeaders;
            }

            const res = await fetch(`${import.meta.env.VITE_API_URL}/delete-selected-playlists`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                credentials: 'include',
                body: JSON.stringify(body),
            });

            const data = await res.json();

            if (res.ok) {
                setDeleteId(data.delete_id);
                startPolling(data.delete_id);
            } else {
                setDeleteError(true);
                setDeleteErrorMessage(
                    <>
                        <FaExclamationCircle className="inline mr-2" />
                        {data.message || "Failed to start deletion"}
                    </>
                );
                setIsDeleting(false);
            }
        } catch (error) {
            setDeleteError(true);
            setDeleteErrorMessage(
                <>
                    <FaExclamationCircle className="inline mr-2" />
                    Network error. Could not connect to server.
                </>
            );
            setIsDeleting(false);
        }
    };

    useEffect(() => {
        return () => {
            if (pollingIntervalRef.current) {
                clearInterval(pollingIntervalRef.current);
            }
        };
    }, []);

    const getStatusIcon = (status: string) => {
        switch (status) {
            case "deleted":
                return <FaCheck className="text-green-500" />;
            case "failed":
                return <FaTimes className="text-red-500" />;
            case "deleting":
                return <FaSpinner className="animate-spin text-red-500" />;
            default:
                return <FaSpinner className="animate-spin text-gray-400" />;
        }
    };

    return (
        <div className="flex flex-col items-center justify-center w-full max-w-5xl mx-auto p-6">
            <Card className="w-full">
                <CardContent className="p-6">
                    <h3 className="text-xl font-bold mb-4 text-red-600 dark:text-red-400">
                        <FaTrash className="inline mr-2" />
                        Delete YouTube Music Playlists
                    </h3>
                    
                    <div className="mb-4 p-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded">
                        <p className="text-sm text-yellow-800 dark:text-yellow-200">
                            <strong>⚠️ Warning:</strong> This action will permanently delete the selected playlists from YouTube Music. This cannot be undone!
                        </p>
                    </div>

                    {!hasCredentials && (
                        <div className="mb-4">
                            <label className="block text-sm font-medium mb-2">
                                YouTube Music Authentication Headers
                            </label>
                            <Textarea
                                placeholder="Paste your YouTube Music authentication headers here..."
                                value={authHeaders}
                                onChange={(e) => setAuthHeaders(e.target.value)}
                                className="min-h-[100px] font-mono text-xs"
                            />
                            <p className="text-xs text-gray-500 mt-1">
                                Required only if you haven't authenticated before
                            </p>
                        </div>
                    )}

                    {hasCredentials && (
                        <div className="mb-4 p-3 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded">
                            <p className="text-sm text-green-800 dark:text-green-200">
                                ✓ Using saved YouTube Music credentials
                            </p>
                        </div>
                    )}

                    {connectionError && (
                        <div className="mb-4 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded">
                            <p className="text-sm text-red-800 dark:text-red-200">
                                {errorMessage}
                            </p>
                        </div>
                    )}

                    {deleteError && (
                        <div className="mb-4 p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded">
                            <p className="text-sm text-red-800 dark:text-red-200">
                                {deleteErrorMessage}
                            </p>
                        </div>
                    )}

                    {/* Botón para cargar y seleccionar playlists */}
                    {!isDeleting && (
                        <Button
                            onClick={() => {
                                if (showPlaylistSelection && playlists.length > 0) {
                                    setSelectionDialogOpen(true);
                                } else {
                                    loadPlaylists();
                                }
                            }}
                            disabled={isLoadingPlaylists || (!hasCredentials && !authHeaders.trim())}
                            className="w-full mb-4"
                            variant="outline"
                        >
                            {isLoadingPlaylists ? (
                                <>
                                    <FaSpinner className="animate-spin mr-2" />
                                    Loading Playlists...
                                </>
                            ) : showPlaylistSelection ? (
                                <>
                                    <FaYoutube className="mr-2 text-red-500" />
                                    Edit Selection ({selectedPlaylists.size} playlists)
                                </>
                            ) : (
                                <>
                                    <FaYoutube className="mr-2 text-red-500" />
                                    Select Playlists to Delete
                                </>
                            )}
                        </Button>
                    )}

                    {/* Modal de selección de playlists */}
                    <AlertDialog open={selectionDialogOpen} onOpenChange={setSelectionDialogOpen}>
                        <AlertDialogContent className="max-w-4xl max-h-[90vh] overflow-hidden flex flex-col">
                            <AlertDialogHeader>
                                <AlertDialogTitle>
                                    <div className="flex items-center gap-2">
                                        <FaYoutube className="text-red-500" />
                                        Select Playlists to Delete
                                    </div>
                                </AlertDialogTitle>
                                <AlertDialogDescription>
                                    Select the playlists you want to delete from YouTube Music. This action cannot be undone.
                                </AlertDialogDescription>
                            </AlertDialogHeader>

                            <div className="flex-1 overflow-hidden flex flex-col">
                                {/* Controles superiores */}
                                <div className="flex items-center justify-between py-3 border-b">
                                    <div className="text-sm">
                                        <span className="font-semibold text-red-600">{selectedPlaylists.size}</span> of{' '}
                                        <span className="font-semibold">{playlists.length}</span> playlists selected
                                    </div>
                                    <label className="flex items-center gap-2 cursor-pointer">
                                        <input
                                            type="checkbox"
                                            checked={selectedPlaylists.size === playlists.length}
                                            onChange={toggleSelectAllPlaylists}
                                            className="w-4 h-4 cursor-pointer accent-red-500"
                                        />
                                        <span className="text-sm">Select All Playlists</span>
                                    </label>
                                </div>

                                {/* Lista de playlists con scroll */}
                                <div className="flex-1 overflow-y-auto py-3 space-y-2">
                                    {playlists.map((playlist) => (
                                        <div
                                            key={playlist.id}
                                            onClick={() => togglePlaylistSelection(playlist.id)}
                                            className={`flex items-center gap-3 p-3 rounded-lg cursor-pointer transition-all ${
                                                selectedPlaylists.has(playlist.id)
                                                    ? 'bg-red-50 dark:bg-red-900/20 border-2 border-red-500'
                                                    : 'bg-gray-50 dark:bg-gray-800/50 border-2 border-transparent hover:bg-gray-100 dark:hover:bg-gray-700'
                                            }`}
                                        >
                                            <input
                                                type="checkbox"
                                                checked={selectedPlaylists.has(playlist.id)}
                                                onChange={() => togglePlaylistSelection(playlist.id)}
                                                className="w-5 h-5 cursor-pointer accent-red-500"
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
                                            <div className="flex-1 min-w-0">
                                                <p className="font-semibold truncate text-base">{playlist.name}</p>
                                                <p className="text-sm text-gray-500">
                                                    {playlist.count} tracks
                                                </p>
                                            </div>
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
                                    }}
                                >
                                    Cancel
                                </Button>
                                <Button
                                    onClick={() => setSelectionDialogOpen(false)}
                                    disabled={selectedPlaylists.size === 0}
                                    className="bg-red-600 hover:bg-red-700"
                                >
                                    Confirm Selection ({selectedPlaylists.size} playlists)
                                </Button>
                            </AlertDialogFooter>
                        </AlertDialogContent>
                    </AlertDialog>

                    {/* Botón de eliminar (solo visible después de seleccionar) */}
                    <AlertDialog open={showConfirmDialog} onOpenChange={setShowConfirmDialog}>
                        <AlertDialogTrigger asChild>
                            <Button
                                variant="destructive"
                                disabled={!serverOnline || isDeleting || !showPlaylistSelection || selectedPlaylists.size === 0}
                                className="w-full"
                            >
                                {isDeleting ? (
                                    <>
                                        <FaSpinner className="animate-spin mr-2" />
                                        Deleting...
                                    </>
                                ) : (
                                    <>
                                        <FaTrash className="mr-2" />
                                        Delete {selectedPlaylists.size} Selected Playlist{selectedPlaylists.size !== 1 ? 's' : ''}
                                    </>
                                )}
                            </Button>
                        </AlertDialogTrigger>
                        <AlertDialogContent>
                            <AlertDialogHeader>
                                <AlertDialogTitle className="text-red-600">Are you absolutely sure?</AlertDialogTitle>
                                <AlertDialogDescription>
                                    This will permanently delete <strong>{selectedPlaylists.size} playlist{selectedPlaylists.size !== 1 ? 's' : ''}</strong> from your YouTube Music account.
                                    This action cannot be undone.
                                </AlertDialogDescription>
                            </AlertDialogHeader>
                            <AlertDialogFooter>
                                <AlertDialogCancel>Cancel</AlertDialogCancel>
                                <AlertDialogAction
                                    onClick={handleDeleteSelected}
                                    className="bg-red-600 hover:bg-red-700"
                                >
                                    Yes, Delete {selectedPlaylists.size} Playlist{selectedPlaylists.size !== 1 ? 's' : ''}
                                </AlertDialogAction>
                            </AlertDialogFooter>
                        </AlertDialogContent>
                    </AlertDialog>

                    {deleteProgress && (
                        <div className="mt-6">
                            <div className="mb-4 p-4 bg-gray-50 dark:bg-gray-800 rounded">
                                <div className="flex items-center justify-between mb-2">
                                    <h4 className="font-semibold">Progress</h4>
                                    {isDeleting && (
                                        <Button
                                            variant="outline"
                                            size="sm"
                                            onClick={cancelDeletion}
                                            className="text-red-600 border-red-600 hover:bg-red-50"
                                        >
                                            Cancel
                                        </Button>
                                    )}
                                </div>
                                <div className="space-y-1 text-sm">
                                    <p>Total Playlists: {deleteProgress.total_playlists}</p>
                                    <p className="text-green-600">Deleted: {deleteProgress.deleted}</p>
                                    <p className="text-red-600">Failed: {deleteProgress.failed}</p>
                                </div>
                                {deleteProgress.total_playlists > 0 && (
                                    <div className="mt-2">
                                        <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                                            <div
                                                className="bg-red-600 h-2 rounded-full transition-all"
                                                style={{
                                                    width: `${((deleteProgress.deleted + deleteProgress.failed) / deleteProgress.total_playlists) * 100}%`
                                                }}
                                            />
                                        </div>
                                    </div>
                                )}
                            </div>

                            <div className="space-y-2 max-h-96 overflow-y-auto">
                                {deleteProgress.playlists.map((playlist, index) => (
                                    <div
                                        key={index}
                                        className="flex items-center gap-3 p-3 bg-white dark:bg-gray-800 rounded border"
                                    >
                                        {playlist.image ? (
                                            <img 
                                                src={playlist.image} 
                                                alt={playlist.name}
                                                className="w-10 h-10 rounded object-cover"
                                            />
                                        ) : (
                                            <div className="w-10 h-10 bg-gray-200 dark:bg-gray-700 rounded flex items-center justify-center">
                                                <FaMusic className="text-gray-400 w-4 h-4" />
                                            </div>
                                        )}
                                        <div className="flex-1 min-w-0">
                                            <p className="font-medium truncate">{playlist.name}</p>
                                            {playlist.reason && (
                                                <p className="text-xs text-red-500">{playlist.reason}</p>
                                            )}
                                        </div>
                                        <div className="flex items-center gap-2">
                                            <span className="text-xs text-gray-500 capitalize">
                                                {playlist.status}
                                            </span>
                                            {getStatusIcon(playlist.status)}
                                        </div>
                                    </div>
                                ))}
                            </div>

                            {deleteProgress.status === "completed" && (
                                <div className="mt-4 p-3 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded">
                                    <p className="text-sm text-green-800 dark:text-green-200">
                                        ✓ Deletion completed! {deleteProgress.deleted} playlist{deleteProgress.deleted !== 1 ? 's' : ''} deleted.
                                    </p>
                                </div>
                            )}

                            {deleteProgress.status === "cancelled" && (
                                <div className="mt-4 p-3 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded">
                                    <p className="text-sm text-yellow-800 dark:text-yellow-200">
                                        ⚠️ Deletion cancelled. {deleteProgress.deleted} playlist{deleteProgress.deleted !== 1 ? 's were' : ' was'} already deleted.
                                    </p>
                                </div>
                            )}
                        </div>
                    )}
                </CardContent>
            </Card>
        </div>
    );
}
