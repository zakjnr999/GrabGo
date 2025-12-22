import { Card, Button } from "@grabgo/ui";
import { ArrowLeft } from "iconoir-react";

export default function Loading() {
    return (
        <div className="p-6 space-y-6">
            {/* Back Button Skeleton */}
            <Button variant="ghost" className="gap-2 -ml-2 text-muted-foreground" disabled>
                <ArrowLeft className="w-4 h-4" />
                Back to Customers
            </Button>

            {/* Profile Header Skeleton */}
            <Card className="p-6 border-border/50">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 animate-pulse">
                    <div className="flex items-center gap-6">
                        <div className="w-24 h-24 rounded-md bg-muted" />
                        <div className="space-y-3">
                            <div className="h-8 w-48 bg-muted rounded" />
                            <div className="flex gap-2">
                                <div className="h-5 w-24 bg-muted rounded-full" />
                                <div className="h-5 w-20 bg-muted rounded-full" />
                            </div>
                        </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        <div className="h-10 w-24 bg-muted rounded-md" />
                        <div className="h-10 w-24 bg-muted rounded-md" />
                        <div className="h-10 w-24 bg-muted rounded-md" />
                        <div className="h-10 w-24 bg-muted rounded-md" />
                    </div>
                </div>
            </Card>

            {/* Stat Cards Skeleton */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {[...Array(4)].map((_, i) => (
                    <Card key={i} className="p-6 border-border/50 animate-pulse">
                        <div className="flex items-center gap-4">
                            <div className="w-12 h-12 rounded-md bg-muted" />
                            <div className="space-y-2 text-left flex-1">
                                <div className="h-6 w-16 bg-muted rounded" />
                                <div className="h-4 w-24 bg-muted rounded" />
                            </div>
                        </div>
                    </Card>
                ))}
            </div>

            {/* Tabs Section Skeleton */}
            <Card className="border-border/50 animate-pulse">
                <div className="border-b border-border/50 h-14 flex items-center px-6 gap-6">
                    <div className="h-4 w-24 bg-muted rounded" />
                    <div className="h-4 w-32 bg-muted rounded" />
                    <div className="h-4 w-36 bg-muted rounded" />
                </div>
                <div className="p-6 space-y-8">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                        {[...Array(6)].map((_, i) => (
                            <div key={i} className="space-y-2">
                                <div className="h-4 w-24 bg-muted rounded" />
                                <div className="h-6 w-48 bg-muted rounded" />
                            </div>
                        ))}
                    </div>
                </div>
            </Card>
        </div>
    );
}
