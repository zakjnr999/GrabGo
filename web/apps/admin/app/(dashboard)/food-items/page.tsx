"use client";

import { useState } from "react";
import Link from "next/link";
import {
    Card,
    Badge,
    Button,
    Input,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@grabgo/ui";
import {
    Search,
    Filter,
    Plus,
    Database,
    NavArrowRight,
} from "iconoir-react";

// Mock data - will be replaced with API calls
const mockFoodItems = [
    {
        id: "1",
        name: "Jollof Rice with Chicken",
        description: "Spicy Ghanaian jollof rice served with grilled chicken",
        price: 45.00,
        category: "Main Course",
        restaurant: { id: "r1", name: "Mama's Kitchen" },
        image: null,
        inStock: true,
        preparationTime: 25,
        rating: 4.8,
        totalReviews: 156,
    },
    {
        id: "2",
        name: "Waakye with Fish",
        description: "Traditional rice and beans with fried fish and sides",
        price: 35.00,
        category: "Main Course",
        restaurant: { id: "r1", name: "Mama's Kitchen" },
        image: null,
        inStock: true,
        preparationTime: 20,
        rating: 4.6,
        totalReviews: 89,
    },
    {
        id: "3",
        name: "Banku and Tilapia",
        description: "Fresh tilapia with banku and pepper sauce",
        price: 55.00,
        category: "Main Course",
        restaurant: { id: "r2", name: "Coastal Delights" },
        image: null,
        inStock: false,
        preparationTime: 30,
        rating: 4.9,
        totalReviews: 234,
    },
    {
        id: "4",
        name: "Kelewele",
        description: "Spicy fried plantain cubes",
        price: 15.00,
        category: "Appetizer",
        restaurant: { id: "r1", name: "Mama's Kitchen" },
        image: null,
        inStock: true,
        preparationTime: 10,
        rating: 4.7,
        totalReviews: 67,
    },
    {
        id: "5",
        name: "Fufu with Light Soup",
        description: "Pounded cassava with goat meat light soup",
        price: 50.00,
        category: "Main Course",
        restaurant: { id: "r3", name: "Ashanti Cuisine" },
        image: null,
        inStock: true,
        preparationTime: 35,
        rating: 4.5,
        totalReviews: 112,
    },
];

const categories = ["All", "Main Course", "Appetizer", "Dessert", "Beverage", "Side Dish"];
const restaurants = ["All Restaurants", "Mama's Kitchen", "Coastal Delights", "Ashanti Cuisine"];

export default function FoodItemsPage() {
    const [searchQuery, setSearchQuery] = useState("");
    const [selectedCategory, setSelectedCategory] = useState("All");
    const [selectedRestaurant, setSelectedRestaurant] = useState("All Restaurants");
    const [availabilityFilter, setAvailabilityFilter] = useState<"all" | "in-stock" | "out-of-stock">("all");
    const [priceRange, setPriceRange] = useState({ min: 0, max: 100 });
    const [isLoading, setIsLoading] = useState(true);
    const [selectedItems, setSelectedItems] = useState<string[]>([]);

    // Simulate loading
    useState(() => {
        setTimeout(() => setIsLoading(false), 800);
    });

    // Filter food items
    const filteredItems = mockFoodItems.filter(item => {
        const matchesSearch = item.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
            item.description.toLowerCase().includes(searchQuery.toLowerCase());
        const matchesCategory = selectedCategory === "All" || item.category === selectedCategory;
        const matchesRestaurant = selectedRestaurant === "All Restaurants" || item.restaurant.name === selectedRestaurant;
        const matchesAvailability = availabilityFilter === "all" ||
            (availabilityFilter === "in-stock" && item.inStock) ||
            (availabilityFilter === "out-of-stock" && !item.inStock);
        const matchesPrice = item.price >= priceRange.min && item.price <= priceRange.max;

        return matchesSearch && matchesCategory && matchesRestaurant && matchesAvailability && matchesPrice;
    });

    return (
        <div className="space-y-6 animate-fade-in">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-4xl font-extrabold tracking-tight">Food Items</h1>
                    <p className="text-muted-foreground mt-2 text-lg font-medium">
                        Manage food items across all restaurants
                    </p>
                </div>
                <div className="flex gap-2">
                    <Link href="/food-items/categories">
                        <Button
                            variant="outline"
                            className="gap-2"
                        >
                            <Database className="w-4 h-4" />
                            Manage Categories
                        </Button>
                    </Link>
                    <Button className="gap-2 bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:opacity-90">
                        <Plus className="w-4 h-4" />
                        Add Food Item
                    </Button>
                </div>
            </div>

            {/* Bulk Actions */}
            {selectedItems.length > 0 && (
                <Card className="p-4 border-border/50 bg-[#FE6132]/5 animate-fade-in">
                    <div className="flex items-center justify-between">
                        <p className="text-sm font-medium">
                            {selectedItems.length} item{selectedItems.length > 1 ? 's' : ''} selected
                        </p>
                        <div className="flex gap-2">
                            <button
                                onClick={() => {
                                    alert(`Marked ${selectedItems.length} items as In Stock`);
                                    setSelectedItems([]);
                                }}
                                className="inline-flex items-center justify-center gap-2 h-8 rounded-full px-4 text-sm font-semibold transition-all bg-green-100 text-green-700 border border-green-200 hover:bg-green-200 active:scale-95"
                            >
                                Mark as In Stock
                            </button>
                            <button
                                onClick={() => {
                                    alert(`Marked ${selectedItems.length} items as Out of Stock`);
                                    setSelectedItems([]);
                                }}
                                className="inline-flex items-center justify-center gap-2 h-8 rounded-full px-4 text-sm font-semibold transition-all bg-red-100 text-red-700 border border-red-200 hover:bg-red-200 active:scale-95"
                            >
                                Mark as Out of Stock
                            </button>
                            <button
                                onClick={() => setSelectedItems([])}
                                className="inline-flex items-center justify-center gap-2 h-8 rounded-full px-4 text-sm font-medium transition-all bg-gray-100 text-gray-700 border border-gray-200 hover:bg-gray-200 active:scale-95"
                            >
                                Clear Selection
                            </button>
                        </div>
                    </div>
                </Card>
            )}

            {/* Filters */}
            <Card className="p-6 border-border/50">
                <div className="space-y-4">
                    {/* Search */}
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
                        <Input
                            placeholder="Search food items by name or description..."
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="pl-10"
                        />
                    </div>

                    {/* Filter Row */}
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                        {/* Category Filter */}
                        <div>
                            <label className="text-sm font-medium mb-2 block">Category</label>
                            <Select value={selectedCategory} onValueChange={setSelectedCategory}>
                                <SelectTrigger className="w-full h-10 border-input bg-background px-3 text-sm">
                                    <SelectValue placeholder="All" />
                                </SelectTrigger>
                                <SelectContent className="bg-card text-foreground">
                                    {categories.map(cat => (
                                        <SelectItem key={cat} value={cat}>{cat}</SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        </div>

                        {/* Restaurant Filter */}
                        <div>
                            <label className="text-sm font-medium mb-2 block">Restaurant</label>
                            <Select value={selectedRestaurant} onValueChange={setSelectedRestaurant}>
                                <SelectTrigger className="w-full h-10 border-input bg-background px-3 text-sm">
                                    <SelectValue placeholder="All Restaurants" />
                                </SelectTrigger>
                                <SelectContent className="bg-card text-foreground">
                                    {restaurants.map(rest => (
                                        <SelectItem key={rest} value={rest}>{rest}</SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        </div>

                        {/* Availability Filter */}
                        <div>
                            <label className="text-sm font-medium mb-2 block">Availability</label>
                            <Select
                                value={availabilityFilter}
                                onValueChange={(v) => setAvailabilityFilter(v as any)}
                            >
                                <SelectTrigger className="w-full h-10 border-input bg-background px-3 text-sm">
                                    <SelectValue placeholder="All Items" />
                                </SelectTrigger>
                                <SelectContent className="bg-card text-foreground">
                                    <SelectItem value="all">All Items</SelectItem>
                                    <SelectItem value="in-stock">In Stock</SelectItem>
                                    <SelectItem value="out-of-stock">Out of Stock</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>

                        {/* Price Range */}
                        <div>
                            <label className="text-sm font-medium mb-2 block">
                                Price Range (GH₵{priceRange.min} - GH₵{priceRange.max})
                            </label>
                            <div className="flex gap-2">
                                <input
                                    type="number"
                                    value={priceRange.min}
                                    onChange={(e) => setPriceRange({ ...priceRange, min: Number(e.target.value) })}
                                    className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
                                    placeholder="Min"
                                />
                                <input
                                    type="number"
                                    value={priceRange.max}
                                    onChange={(e) => setPriceRange({ ...priceRange, max: Number(e.target.value) })}
                                    className="w-full h-10 rounded-md border border-input bg-background px-3 text-sm"
                                    placeholder="Max"
                                />
                            </div>
                        </div>
                    </div>

                    {/* Active Filters Summary */}
                    <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-sm text-muted-foreground">Active filters:</span>
                        {selectedCategory !== "All" && (
                            <Badge variant="outline" className="gap-1">
                                Category: {selectedCategory}
                            </Badge>
                        )}
                        {selectedRestaurant !== "All Restaurants" && (
                            <Badge variant="outline" className="gap-1">
                                Restaurant: {selectedRestaurant}
                            </Badge>
                        )}
                        {availabilityFilter !== "all" && (
                            <Badge variant="outline" className="gap-1">
                                {availabilityFilter === "in-stock" ? "In Stock" : "Out of Stock"}
                            </Badge>
                        )}
                        {(priceRange.min > 0 || priceRange.max < 100) && (
                            <Badge variant="outline" className="gap-1">
                                GH₵{priceRange.min} - GH₵{priceRange.max}
                            </Badge>
                        )}
                    </div>
                </div>
            </Card>

            {/* Results Count */}
            <div className="flex items-center justify-between">
                <p className="text-sm text-muted-foreground">
                    Showing <span className="font-medium text-foreground">{filteredItems.length}</span> of{" "}
                    <span className="font-medium text-foreground">{mockFoodItems.length}</span> food items
                </p>
            </div>

            {/* Food Items Grid */}
            {isLoading ? (
                // Skeleton Loaders
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {Array.from({ length: 6 }).map((_, i) => (
                        <Card key={`skeleton-${i}`} className="p-4 border-border/50 animate-pulse">
                            <div className="flex gap-4">
                                {/* Image Skeleton */}
                                <div className="w-20 h-20 rounded-xl bg-muted flex-shrink-0" />

                                {/* Details Skeleton */}
                                <div className="flex-1 space-y-2 min-w-0">
                                    <div className="flex items-start justify-between gap-2">
                                        <div className="h-4 w-32 bg-muted rounded" />
                                        <div className="h-4 w-16 bg-muted rounded" />
                                    </div>
                                    <div className="h-3 w-full bg-muted rounded" />
                                    <div className="h-3 w-3/4 bg-muted rounded" />
                                    <div className="flex items-center justify-between mt-2">
                                        <div className="h-5 w-20 bg-muted rounded-full" />
                                        <div className="h-3 w-16 bg-muted rounded" />
                                    </div>
                                    <div className="h-3 w-24 bg-muted rounded" />
                                </div>
                            </div>
                        </Card>
                    ))}
                </div>
            ) : filteredItems.length > 0 ? (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {filteredItems.map((item, idx) => (
                        <div key={item.id} className="relative">
                            <input
                                type="checkbox"
                                checked={selectedItems.includes(item.id)}
                                onChange={(e) => {
                                    e.stopPropagation();
                                    if (selectedItems.includes(item.id)) {
                                        setSelectedItems(selectedItems.filter(id => id !== item.id));
                                    } else {
                                        setSelectedItems([...selectedItems, item.id]);
                                    }
                                }}
                                className="absolute top-6 left-6 z-10 w-4 h-4 rounded border-2 border-border cursor-pointer"
                                onClick={(e) => e.stopPropagation()}
                            />
                            <Link href={`/food-items/${item.id}`}>
                                <Card className="p-4 border-border/50 hover:shadow-lg transition-all hover:-translate-y-1 group animate-fade-in-up cursor-pointer" style={{ animationDelay: `${idx * 50}ms` }}>
                                    <div className="flex gap-4">
                                        {/* Image */}
                                        <div className="w-20 h-20 rounded-xl bg-muted flex items-center justify-center text-muted-foreground flex-shrink-0 group-hover:scale-105 transition-transform overflow-hidden">
                                            {item.image ? (
                                                <img src={item.image} alt={item.name} className="w-full h-full object-cover" />
                                            ) : (
                                                <Database className="w-8 h-8 opacity-40" />
                                            )}
                                        </div>

                                        {/* Details */}
                                        <div className="flex-1 space-y-1 min-w-0">
                                            <div className="flex items-start justify-between gap-2">
                                                <h4 className="font-bold text-sm group-hover:text-[#FE6132] transition-colors line-clamp-1">
                                                    {item.name}
                                                </h4>
                                                <span className="text-sm font-black text-[#FE6132] whitespace-nowrap">
                                                    GH₵ {item.price.toFixed(2)}
                                                </span>
                                            </div>
                                            <p className="text-xs text-muted-foreground line-clamp-1">
                                                {item.description}
                                            </p>
                                            <div className="flex items-center justify-between mt-2">
                                                <Badge className="text-[10px] px-2 py-0.5 font-medium uppercase tracking-wider bg-accent/50 text-foreground border-0">
                                                    {item.category}
                                                </Badge>
                                                <div className="flex items-center gap-1.5">
                                                    <div className={`w-2 h-2 rounded-full ${item.inStock ? "bg-green-500" : "bg-red-500"} shadow-sm`} />
                                                    <span className="text-[10px] uppercase text-muted-foreground font-medium">
                                                        {item.inStock ? "In Stock" : "Out of Stock"}
                                                    </span>
                                                </div>
                                            </div>
                                            <p className="text-xs text-muted-foreground mt-1">
                                                {item.restaurant.name}
                                            </p>
                                        </div>
                                    </div>
                                </Card>
                            </Link>
                        </div>
                    ))}
                </div>
            ) : (
                <Card className="p-12 border-border/50 text-center">
                    <Database className="w-12 h-12 text-muted-foreground opacity-20 mx-auto mb-4" />
                    <h3 className="text-lg font-semibold">No Food Items Found</h3>
                    <p className="text-muted-foreground max-w-sm mx-auto text-sm mt-2">
                        No food items match your current filters. Try adjusting your search criteria.
                    </p>
                </Card>
            )}
        </div>
    );
}
