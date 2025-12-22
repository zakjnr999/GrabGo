export default function Loading() {
    return (
        <div className="min-h-screen bg-background flex items-center justify-center p-4">
            <div className="w-full max-w-md space-y-8 animate-fade-in">
                {/* Logo */}
                <div className="text-center">
                    <div className="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 shadow-lg shadow-orange-200/50 animate-pulse-slow">
                        <svg
                            className="w-10 h-10 text-white"
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                        >
                            <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"
                            />
                        </svg>
                    </div>
                </div>

                {/* Progress Bar */}
                <div className="relative h-2 bg-accent/30 rounded-full overflow-hidden">
                    <div className="absolute inset-0 bg-gradient-to-r from-[#FE6132] to-[#FE6132]/70 animate-loading-bar" />
                </div>

                {/* Skeleton Preview */}
                <div className="space-y-3 pt-4">
                    <div className="grid grid-cols-3 gap-3">
                        {[...Array(3)].map((_, i) => (
                            <div
                                key={i}
                                className="h-20 rounded-xl bg-accent/30 animate-pulse"
                                style={{ animationDelay: `${i * 100}ms` }}
                            />
                        ))}
                    </div>
                    <div className="space-y-2">
                        {[...Array(3)].map((_, i) => (
                            <div
                                key={i}
                                className="h-12 rounded-lg bg-accent/20 animate-pulse"
                                style={{ animationDelay: `${300 + i * 100}ms` }}
                            />
                        ))}
                    </div>
                </div>
            </div>
        </div>
    );
}
