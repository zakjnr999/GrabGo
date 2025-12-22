"use client";

import { useState } from "react";
import Link from "next/link";
import { Card, Badge, Button, Input } from "@grabgo/ui";

import {
    Plus,
    Edit,
    Trash,
    Database,
    ArrowLeft,
} from "iconoir-react";

// Mock data - will be replaced with API calls
const mockCategories = [
    { id: "1", name: "Main Course", itemCount: 15, createdAt: "2024-01-10T10:00:00Z" },
    { id: "2", name: "Appetizer", itemCount: 8, createdAt: "2024-01-12T10:00:00Z" },
    { id: "3", name: "Dessert", itemCount: 6, createdAt: "2024-01-15T10:00:00Z" },
    { id: "4", name: "Beverage", itemCount: 12, createdAt: "2024-01-18T10:00:00Z" },
    { id: "5", name: "Side Dish", itemCount: 5, createdAt: "2024-01-20T10:00:00Z" },
];

export default function CategoriesPage() {
    const [categories, setCategories] = useState(mockCategories);
    const [searchQuery, setSearchQuery] = useState("");
    const [editingCategory, setEditingCategory] = useState<string | null>(null);
    const [editName, setEditName] = useState("");

    const filteredCategories = categories.filter(cat =>
        cat.name.toLowerCase().includes(searchQuery.toLowerCase())
    );

    const handleAddCategory = () => {
        const newName = prompt("Enter category name:");
        if (newName && newName.trim()) {
            const newCategory = {
                id: String(categories.length + 1),
                name: newName.trim(),
                itemCount: 0,
                createdAt: new Date().toISOString(),
            };
            setCategories([...categories, newCategory]);
        }
    };

    const handleEditCategory = (id: string, currentName: string) => {
        setEditingCategory(id);
        setEditName(currentName);
    };

    const handleSaveEdit = (id: string) => {
        if (editName.trim()) {
            setCategories(categories.map(cat =>
                cat.id === id ? { ...cat, name: editName.trim() } : cat
            ));
            setEditingCategory(null);
            setEditName("");
        }
    };

    const handleDeleteCategory = (id: string, name: string) => {
        if (confirm(`Are you sure you want to delete the category "${name}"?`)) {
            setCategories(categories.filter(cat => cat.id !== id));
        }
    };

    return (
        <div className="space-y-6 animate-fade-in">
            {/* Header */}
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                <div>
                    <h1 className="text-4xl font-extrabold tracking-tight">Food Categories</h1>
                    <p className="text-muted-foreground mt-2 text-lg font-medium">
                        Manage food item categories across all restaurants
                    </p>
                </div>
                <Button
                    onClick={handleAddCategory}
                    className="gap-2 bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:opacity-90"
                >
                    <Plus className="w-4 h-4" />
                    Add Category
                </Button>
            </div>

            {/* Navigation */}
            <div className="flex items-center gap-4">
                <Link href="/food-items">
                    <Button variant="outline" size="sm" className="gap-2">
                        <ArrowLeft className="w-4 h-4" />
                        Back to Food Items
                    </Button>
                </Link>
            </div>

            {/* Search */}
            <Card className="p-4 border-border/50">
                <Input
                    placeholder="Search categories..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                />
            </Card>

            {/* Stats */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <Card className="p-6 border-border/50">
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-2xl bg-orange-50/80 dark:bg-[#FE6132]/10 flex items-center justify-center border border-orange-100 dark:border-[#FE6132]/20">
                            <Database className="w-6 h-6 text-[#FE6132]" />
                        </div>
                        <div>
                            <p className="text-sm text-muted-foreground">Total Categories</p>
                            <p className="text-2xl font-bold">{categories.length}</p>
                        </div>
                    </div>
                </Card>
                <Card className="p-6 border-border/50">
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-2xl bg-green-50/80 dark:bg-green-500/10 flex items-center justify-center border border-green-100 dark:border-green-500/20">
                            <Database className="w-6 h-6 text-green-600 dark:text-green-500" />
                        </div>
                        <div>
                            <p className="text-sm text-muted-foreground">Total Items</p>
                            <p className="text-2xl font-bold">
                                {categories.reduce((sum, cat) => sum + cat.itemCount, 0)}
                            </p>
                        </div>
                    </div>
                </Card>
                <Card className="p-6 border-border/50">
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-2xl bg-blue-50/80 dark:bg-blue-500/10 flex items-center justify-center border border-blue-100 dark:border-blue-500/20">
                            <Database className="w-6 h-6 text-blue-600 dark:text-blue-500" />
                        </div>
                        <div>
                            <p className="text-sm text-muted-foreground">Avg Items/Category</p>
                            <p className="text-2xl font-bold">
                                {Math.round(categories.reduce((sum, cat) => sum + cat.itemCount, 0) / categories.length)}
                            </p>
                        </div>
                    </div>
                </Card>
            </div>

            {/* Categories List */}
            {filteredCategories.length > 0 ? (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {filteredCategories.map((category, idx) => (
                        <Card
                            key={category.id}
                            className="p-6 border-border/50 hover:shadow-lg transition-all animate-fade-in-up"
                            style={{ animationDelay: `${idx * 50}ms` }}
                        >
                            {editingCategory === category.id ? (
                                <div className="space-y-3">
                                    <Input
                                        value={editName}
                                        onChange={(e) => setEditName(e.target.value)}
                                        placeholder="Category name"
                                        autoFocus
                                    />
                                    <div className="flex gap-2">
                                        <Button
                                            size="sm"
                                            onClick={() => handleSaveEdit(category.id)}
                                            className="flex-1 bg-green-600 text-white hover:bg-green-700"
                                        >
                                            Save
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => {
                                                setEditingCategory(null);
                                                setEditName("");
                                            }}
                                            className="flex-1"
                                        >
                                            Cancel
                                        </Button>
                                    </div>
                                </div>
                            ) : (
                                <>
                                    <div className="flex items-start justify-between mb-4">
                                        <div>
                                            <h3 className="text-lg font-bold">{category.name}</h3>
                                            <p className="text-sm text-muted-foreground mt-1">
                                                {category.itemCount} items
                                            </p>
                                        </div>
                                        <Badge className="bg-[#FE6132]/10 text-[#FE6132] border-0">
                                            Active
                                        </Badge>
                                    </div>
                                    <div className="flex gap-2">
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => handleEditCategory(category.id, category.name)}
                                            className="flex-1 gap-2"
                                        >
                                            <Edit className="w-4 h-4" />
                                            Edit
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => handleDeleteCategory(category.id, category.name)}
                                            className="gap-2 text-red-600 hover:text-red-700 hover:bg-red-50 dark:hover:bg-red-500/10 dark:hover:text-red-400 border-red-200 dark:border-red-900/30"
                                        >
                                            <Trash className="w-4 h-4" />
                                            Delete
                                        </Button>
                                    </div>
                                </>
                            )}
                        </Card>
                    ))}
                </div>
            ) : (
                <Card className="p-12 border-border/50 text-center">
                    <Database className="w-12 h-12 text-muted-foreground opacity-20 mx-auto mb-4" />
                    <h3 className="text-lg font-semibold">No Categories Found</h3>
                    <p className="text-muted-foreground max-w-sm mx-auto text-sm mt-2">
                        {searchQuery ? "No categories match your search." : "Get started by creating your first category."}
                    </p>
                </Card>
            )}
        </div>
    );
}
