"use client";

import { notFound } from "next/navigation";
import Link from "next/link";
import { use, useState } from "react";
import { Card, Badge, Button } from "@grabgo/ui";
import {
    ArrowLeft,
    Edit,
    Database,
    Star,
    Clock,
    Shop,
    CheckCircle,
    Xmark,
    ShieldCheck,
    StatsUpSquare,
} from "iconoir-react";
import { EditFoodItemDialog } from "./EditFoodItemDialog";
import { ModerateFoodItemDialog } from "./ModerateFoodItemDialog";

// Mock data - will be replaced with API calls
const mockFoodItems = [
    {
        id: "1",
        name: "Jollof Rice with Chicken",
        description: "Spicy Ghanaian jollof rice served with grilled chicken, garnished with fresh vegetables",
        price: 45.00,
        category: "Main Course",
        restaurant: { id: "r1", name: "Mama's Kitchen", address: "Osu, Accra" },
        image: null,
        inStock: true,
        preparationTime: 25,
        rating: 4.8,
        totalReviews: 156,
        ingredients: ["Rice", "Chicken", "Tomatoes", "Onions", "Peppers", "Spices"],
        allergens: ["None"],
        calories: 650,
        createdAt: "2024-01-15T10:30:00Z",
        updatedAt: "2024-01-20T14:45:00Z",
        moderationStatus: "pending" as "approved" | "pending" | "rejected",
        moderationReason: "",
    },
];

interface FoodItemPageProps {
    params: Promise<{
        id: string;
    }>;
}

export default function FoodItemPage({ params }: FoodItemPageProps) {
    const { id } = use(params);
    const foodItem = mockFoodItems.find(item => item.id === id);
    const [editDialogOpen, setEditDialogOpen] = useState(false);
    const [moderateDialogOpen, setModerateDialogOpen] = useState(false);

    if (!foodItem) {
        notFound();
    }

    return (
        <div className="space-y-6 animate-fade-in">
            {/* Header */}
            <div className="flex items-center gap-4">
                <Link href="/food-items">
                    <Button variant="outline" size="sm" className="gap-2">
                        <ArrowLeft className="w-4 h-4" />
                        Back to Food Items
                    </Button>
                </Link>
            </div>

            {/* Food Item Header Card */}
            <Card className="p-6 border-border/50 animate-fade-in-up">
                <div className="flex flex-col md:flex-row gap-6">
                    {/* Image */}
                    <div className="w-full md:w-48 h-48 rounded-xl bg-muted flex items-center justify-center text-muted-foreground overflow-hidden flex-shrink-0">
                        {foodItem.image ? (
                            <img src={foodItem.image} alt={foodItem.name} className="w-full h-full object-cover" />
                        ) : (
                            <Database className="w-16 h-16 opacity-40" />
                        )}
                    </div>

                    {/* Details */}
                    <div className="flex-1 space-y-4">
                        <div>
                            <div className="flex items-start justify-between gap-4 mb-2">
                                <h1 className="text-3xl font-bold">{foodItem.name}</h1>
                                <span className="text-2xl font-black text-[#FE6132]">
                                    GH₵ {foodItem.price.toFixed(2)}
                                </span>
                            </div>
                            <p className="text-muted-foreground">{foodItem.description}</p>
                        </div>

                        <div className="flex flex-wrap gap-4">
                            <div className="flex items-center gap-2">
                                <Shop className="w-4 h-4 text-muted-foreground" />
                                <span className="text-sm font-medium">{foodItem.restaurant.name}</span>
                            </div>
                            <div className="flex items-center gap-2">
                                <Star className="w-4 h-4 text-yellow-500" />
                                <span className="text-sm font-medium">{foodItem.rating} ({foodItem.totalReviews} reviews)</span>
                            </div>
                            <div className="flex items-center gap-2">
                                <Clock className="w-4 h-4 text-muted-foreground" />
                                <span className="text-sm font-medium">{foodItem.preparationTime} mins</span>
                            </div>
                        </div>

                        <div className="flex items-center gap-2">
                            <Badge className="text-xs px-3 py-1 font-medium bg-accent/50 text-foreground border-0">
                                {foodItem.category}
                            </Badge>
                            <Badge className={`text-xs px-3 py-1 font-semibold ${foodItem.inStock ? 'bg-green-600 text-white' : 'bg-red-600 text-white'} shadow-sm`}>
                                {foodItem.inStock ? (
                                    <span className="flex items-center gap-1">
                                        <CheckCircle className="w-3 h-3" />
                                        In Stock
                                    </span>
                                ) : (
                                    <span className="flex items-center gap-1">
                                        <Xmark className="w-3 h-3" />
                                        Out of Stock
                                    </span>
                                )}
                            </Badge>
                            <Badge className={`text-xs px-3 py-1 font-semibold ${foodItem.moderationStatus === 'approved' ? 'bg-blue-600 text-white' :
                                foodItem.moderationStatus === 'rejected' ? 'bg-amber-600 text-white' :
                                    'bg-slate-500 text-white'
                                } shadow-sm`}>
                                <span className="flex items-center gap-1 capitalize">
                                    <ShieldCheck className="w-3 h-3" />
                                    {foodItem.moderationStatus}
                                </span>
                            </Badge>
                        </div>

                        <div className="flex gap-2 pt-2">
                            <Button
                                className="gap-2 bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:opacity-90"
                                onClick={() => setEditDialogOpen(true)}
                            >
                                <Edit className="w-4 h-4" />
                                Edit Details
                            </Button>
                            <Button
                                variant="outline"
                                className="gap-2"
                                onClick={() => setModerateDialogOpen(true)}
                            >
                                Moderate Item
                            </Button>
                            <Button variant="outline" className="gap-2">
                                {foodItem.inStock ? 'Mark as Out of Stock' : 'Mark as In Stock'}
                            </Button>
                        </div>
                    </div>
                </div>
            </Card>

            {/* Edit Dialog */}
            <EditFoodItemDialog
                foodItem={foodItem}
                open={editDialogOpen}
                onOpenChange={setEditDialogOpen}
            />

            {/* Moderate Dialog */}
            <ModerateFoodItemDialog
                foodItem={foodItem}
                open={moderateDialogOpen}
                onOpenChange={setModerateDialogOpen}
            />

            {/* Stats Cards */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <Card className="p-6 border-border/50">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-muted-foreground uppercase tracking-wider">Monthly Revenue</p>
                            <h3 className="text-2xl font-black mt-1">GH₵ 12,450.00</h3>
                            <p className="text-xs text-green-600 font-bold mt-1 flex items-center gap-1">
                                <StatsUpSquare className="w-3 h-3" /> +12.5% from last month
                            </p>
                        </div>
                        <div className="w-12 h-12 rounded-2xl bg-green-50/80 dark:bg-green-500/10 flex items-center justify-center border border-green-100 dark:border-green-500/20">
                            <Database className="w-6 h-6 text-green-600 dark:text-green-500" />
                        </div>
                    </div>
                </Card>
                <Card className="p-6 border-border/50">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-muted-foreground uppercase tracking-wider">Order Volume</p>
                            <h3 className="text-2xl font-black mt-1">458 Orders</h3>
                            <p className="text-xs text-blue-600 font-bold mt-1 flex items-center gap-1">
                                <StatsUpSquare className="w-3 h-3" /> +5.2% from last month
                            </p>
                        </div>
                        <div className="w-12 h-12 rounded-2xl bg-blue-50/80 dark:bg-blue-500/10 flex items-center justify-center border border-blue-100 dark:border-blue-500/20">
                            <Shop className="w-6 h-6 text-blue-600 dark:text-blue-500" />
                        </div>
                    </div>
                </Card>
                <Card className="p-6 border-border/50">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-muted-foreground uppercase tracking-wider">Customer Rating</p>
                            <h3 className="text-2xl font-black mt-1">{foodItem.rating} / 5.0</h3>
                            <p className="text-xs text-purple-600 font-bold mt-1 flex items-center gap-1">
                                Based on {foodItem.totalReviews} reviews
                            </p>
                        </div>
                        <div className="w-12 h-12 rounded-2xl bg-purple-50/80 dark:bg-purple-500/10 flex items-center justify-center border border-purple-100 dark:border-purple-500/20">
                            <Star className="w-6 h-6 text-purple-600 dark:text-purple-500" />
                        </div>
                    </div>
                </Card>
            </div>

            {/* Details Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Ingredients & Nutrition */}
                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "100ms" }}>
                    <h3 className="font-semibold text-lg mb-4">Ingredients & Nutrition</h3>
                    <div className="space-y-4">
                        <div>
                            <label className="text-sm font-medium text-muted-foreground">Ingredients</label>
                            <div className="flex flex-wrap gap-2 mt-2">
                                {foodItem.ingredients.map((ingredient, idx) => (
                                    <Badge key={idx} variant="outline" className="text-xs">
                                        {ingredient}
                                    </Badge>
                                ))}
                            </div>
                        </div>
                        <div>
                            <label className="text-sm font-medium text-muted-foreground">Allergens</label>
                            <div className="flex flex-wrap gap-2 mt-2">
                                {foodItem.allergens.map((allergen, idx) => (
                                    <Badge key={idx} className="text-xs bg-orange-600 text-white font-semibold shadow-sm">
                                        {allergen}
                                    </Badge>
                                ))}
                            </div>
                        </div>
                        <div>
                            <label className="text-sm font-medium text-muted-foreground">Calories</label>
                            <p className="text-lg font-semibold mt-1">{foodItem.calories} kcal</p>
                        </div>
                    </div>
                </Card>

                {/* Restaurant Info */}
                <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "200ms" }}>
                    <h3 className="font-semibold text-lg mb-4">Restaurant Information</h3>
                    <div className="space-y-3">
                        <div>
                            <label className="text-sm font-medium text-muted-foreground">Restaurant Name</label>
                            <p className="font-medium mt-1">{foodItem.restaurant.name}</p>
                        </div>
                        <div>
                            <label className="text-sm font-medium text-muted-foreground">Location</label>
                            <p className="font-medium mt-1">{foodItem.restaurant.address}</p>
                        </div>
                        <div>
                            <label className="text-sm font-medium text-muted-foreground">Preparation Time</label>
                            <p className="font-medium mt-1">{foodItem.preparationTime} minutes</p>
                        </div>
                        <Link href={`/vendors/${foodItem.restaurant.id}`}>
                            <Button variant="outline" size="sm" className="w-full mt-2">
                                View Restaurant Details
                            </Button>
                        </Link>
                    </div>
                </Card>
            </div>

            {/* Metadata */}
            <Card className="p-6 border-border/50 animate-fade-in-up" style={{ animationDelay: "300ms" }}>
                <h3 className="font-semibold text-lg mb-4">Metadata</h3>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label className="text-sm font-medium text-muted-foreground">Food Item ID</label>
                        <p className="font-mono text-sm mt-1">{foodItem.id}</p>
                    </div>
                    <div>
                        <label className="text-sm font-medium text-muted-foreground">Created At</label>
                        <p className="text-sm mt-1">{new Date(foodItem.createdAt).toLocaleString()}</p>
                    </div>
                    <div>
                        <label className="text-sm font-medium text-muted-foreground">Last Updated</label>
                        <p className="text-sm mt-1">{new Date(foodItem.updatedAt).toLocaleString()}</p>
                    </div>
                </div>
            </Card>
        </div>
    );
}
