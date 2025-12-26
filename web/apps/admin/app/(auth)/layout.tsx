export default function AuthLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    return (
        <div className="min-h-screen w-full relative overflow-hidden bg-linear-to-br from-background via-background to-secondary/20">
            {/* Premium Dot Matrix - Clean & Professional */}
            <div className="absolute inset-0 bg-[radial-gradient(#80808035_1.5px,transparent_1.5px)] bg-size-[2rem_2rem] mask-[radial-gradient(ellipse_80%_60%_at_50%_0%,#000_70%,transparent_100%)]" />

            {/* Grain Texture for Organic Depth */}
            <div
                className="absolute inset-0 opacity-[0.04] dark:opacity-[0.06] pointer-events-none mix-blend-overlay"
                style={{
                    backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 250 250' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`
                }}
            />

            {children}
        </div>
    );
}
