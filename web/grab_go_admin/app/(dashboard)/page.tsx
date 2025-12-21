export default function DashboardPage() {
    return (
        <div className="min-h-screen bg-background p-8">
            <div className="max-w-7xl mx-auto">
                <h1 className="text-4xl font-bold mb-8" style={{ color: '#FE6132' }}>
                    GrabGo Admin Dashboard
                </h1>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
                    {[
                        { label: "Total Orders", value: "2,345", icon: "📦" },
                        { label: "Active Users", value: "1,234", icon: "👥" },
                        { label: "Revenue", value: "$45.2K", icon: "💰" },
                        { label: "Pending Orders", value: "89", icon: "⏳" },
                    ].map((stat, i) => (
                        <div
                            key={i}
                            className="p-6 rounded-lg border border-primary/20 bg-card/60 backdrop-blur-sm hover:border-primary/40 transition-all duration-300 hover:shadow-xl hover:shadow-primary/10"
                        >
                            <div className="text-3xl mb-2">{stat.icon}</div>
                            <div className="text-3xl font-bold mb-1" style={{ color: '#FE6132' }}>
                                {stat.value}
                            </div>
                            <div className="text-sm text-muted-foreground">{stat.label}</div>
                        </div>
                    ))}
                </div>

                <div className="bg-card/60 backdrop-blur-sm rounded-lg border border-primary/20 p-6">
                    <h2 className="text-2xl font-bold mb-4">Welcome to GrabGo Admin</h2>
                    <p className="text-muted-foreground">
                        This is a placeholder dashboard. More features coming soon!
                    </p>
                </div>
            </div>
        </div>
    );
}
