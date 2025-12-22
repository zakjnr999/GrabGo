"use client";

export function LoadingScreen() {
    return (
        <div className="fixed inset-0 bg-background flex items-center justify-center z-50">
            <style>{`
                @keyframes pulse-grid {
                    0%, 100% {
                        opacity: 0;
                        transform: scale(0.95);
                    }
                    50% {
                        opacity: 1;
                        transform: scale(1);
                    }
                }

                @keyframes scan {
                    0% {
                        top: 0;
                        opacity: 0;
                    }
                    50% {
                        opacity: 1;
                    }
                    100% {
                        top: 100%;
                        opacity: 0;
                    }
                }

                .animate-pulse-grid {
                    animation: pulse-grid 1.4s ease-in-out infinite;
                }

                .animate-scan {
                    animation: scan 2s ease-in-out infinite;
                }
            `}</style>

            <div className="flex flex-col items-center gap-8 md:gap-12">
                {/* Logo/Brand */}
                <div className="text-center space-y-2 animate-fade-in">
                    <h1 className="text-4xl md:text-5xl font-bold bg-gradient-to-r from-[#FE6132] to-[#FE6132]/80 bg-clip-text text-transparent">
                        GrabGo
                    </h1>
                    <p className="text-sm text-muted-foreground font-medium tracking-wide">Admin Panel</p>
                </div>

                {/* Data Grid Animation */}
                <div className="relative w-56 h-40 md:w-72 md:h-48">
                    {/* Background Grid */}
                    <div className="grid grid-cols-4 gap-2 opacity-10">
                        {Array.from({ length: 16 }).map((_, i) => (
                            <div
                                key={`bg-${i}`}
                                className="h-8 md:h-10 bg-muted rounded border border-border/50"
                            />
                        ))}
                    </div>

                    {/* Animated Overlay Grid */}
                    <div className="absolute inset-0 grid grid-cols-4 gap-2">
                        {Array.from({ length: 16 }).map((_, i) => (
                            <div
                                key={`anim-${i}`}
                                className="h-8 md:h-10 bg-gradient-to-br from-[#FE6132]/20 via-[#FE6132]/10 to-transparent rounded border border-[#FE6132]/30 shadow-[0_0_10px_rgba(254,97,50,0.1)] animate-pulse-grid"
                                style={{
                                    animationDelay: `${i * 0.08}s`,
                                    animationDuration: '1.4s',
                                }}
                            />
                        ))}
                    </div>

                    {/* Scanning Line Effect */}
                    <div className="absolute inset-0 overflow-hidden pointer-events-none">
                        <div className="absolute w-full h-0.5 bg-gradient-to-r from-transparent via-[#FE6132] to-transparent opacity-60 animate-scan shadow-[0_0_8px_rgba(254,97,50,0.6)]" />
                    </div>

                    {/* Corner Accents */}
                    <div className="absolute -top-1 -left-1 w-3 h-3 border-l-2 border-t-2 border-[#FE6132]/40 rounded-tl" />
                    <div className="absolute -top-1 -right-1 w-3 h-3 border-r-2 border-t-2 border-[#FE6132]/40 rounded-tr" />
                    <div className="absolute -bottom-1 -left-1 w-3 h-3 border-l-2 border-b-2 border-[#FE6132]/40 rounded-bl" />
                    <div className="absolute -bottom-1 -right-1 w-3 h-3 border-r-2 border-b-2 border-[#FE6132]/40 rounded-br" />
                </div>

                {/* Loading Text with Dots */}
                <div className="flex items-center gap-3">
                    <div className="flex gap-1.5">
                        <div className="w-2 h-2 bg-[#FE6132] rounded-full animate-bounce [animation-delay:0ms]" />
                        <div className="w-2 h-2 bg-[#FE6132] rounded-full animate-bounce [animation-delay:150ms]" />
                        <div className="w-2 h-2 bg-[#FE6132] rounded-full animate-bounce [animation-delay:300ms]" />
                    </div>
                    <span className="text-sm text-muted-foreground font-medium">Loading dashboard</span>
                </div>
            </div>
        </div>
    );
}
