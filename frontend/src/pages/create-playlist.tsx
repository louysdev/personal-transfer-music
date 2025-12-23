import { Footer } from "@/components/landing/footer";
import GetHeaders from "@/components/create-playlist/get-headers";
import InputFields from "@/components/create-playlist/input-fields";
import TransferAll from "@/components/create-playlist/transfer-all";
import DeleteAllPlaylists from "@/components/create-playlist/delete-all-playlists";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { useState } from "react";

export default function CreatePlaylist() {
    const [activeTab, setActiveTab] = useState("single");

    return (
        <>
            {/* Mobile View */}
            <main className="lg:hidden flex w-screen h-screen flex-col items-center justify-center p-4">
                <h2 className="text-2xl font-bold text-center text-neutral-800 dark:text-white">
                    You need a laptop to use the tool
                    <p className="m-4 text-sm text-neutral-500 dark:text-neutral-400 font-normal">
                        {"(Enter full screen mode if you're on a laptop/PC)"}
                    </p>
                </h2>
            </main>

            {/* Desktop View */}
            <main className="hidden lg:flex w-screen flex-col items-center justify-center">
                <div className="mb-10">
                    <GetHeaders />
                </div>
                <h2 className="my-10 text-center mb-3 text-2xl font-bold mx-auto relative z-20 py-4 bg-clip-text text-transparent bg-gradient-to-b from-neutral-800 via-neutral-700 to-neutral-700 dark:from-neutral-800 dark:via-white dark:to-white w-full">
                    Transfer Playlists
                </h2>
                
                <Tabs className="w-[90%] max-w-[1200px]">
                    <div className="flex justify-center mb-6">
                        <TabsList>
                            <TabsTrigger 
                                active={activeTab === "single"}
                                onClick={() => setActiveTab("single")}
                            >
                                Single Playlist
                            </TabsTrigger>
                            <TabsTrigger 
                                active={activeTab === "all"}
                                onClick={() => setActiveTab("all")}
                            >
                                Transfer All Playlists
                            </TabsTrigger>
                            <TabsTrigger 
                                active={activeTab === "delete"}
                                onClick={() => setActiveTab("delete")}
                            >
                                Delete All Playlists
                            </TabsTrigger>
                        </TabsList>
                    </div>
                    
                    <TabsContent active={activeTab === "single"}>
                        <InputFields />
                    </TabsContent>
                    
                    <TabsContent active={activeTab === "all"}>
                        <TransferAll />
                    </TabsContent>
                    
                    <TabsContent active={activeTab === "delete"}>
                        <DeleteAllPlaylists />
                    </TabsContent>
                </Tabs>
                
                <Footer />
            </main>
        </>
    );
}
