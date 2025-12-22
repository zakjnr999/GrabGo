"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@grabgo/ui";
import { Button, Input, Label } from "@grabgo/ui";

const editFoodItemSchema = z.object({
    name: z.string().min(3, "Name must be at least 3 characters"),
    description: z.string().min(10, "Description must be at least 10 characters"),
    price: z.number().min(0, "Price must be 0 or greater"),
    category: z.string().min(1, "Category is required"),
    preparationTime: z.number().min(5, "Preparation time must be at least 5 minutes"),
    calories: z.number().min(0, "Calories must be 0 or greater").optional(),
    ingredients: z.string().optional(),
    allergens: z.string().optional(),
});

type EditFoodItemFormData = z.infer<typeof editFoodItemSchema>;

interface EditFoodItemDialogProps {
    foodItem: {
        id: string;
        name: string;
        description: string;
        price: number;
        category: string;
        preparationTime: number;
        calories?: number;
        ingredients?: string[];
        allergens?: string[];
    };
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function EditFoodItemDialog({
    foodItem,
    open,
    onOpenChange,
}: EditFoodItemDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);

    const {
        register,
        handleSubmit,
        formState: { errors },
        reset,
    } = useForm<EditFoodItemFormData>({
        resolver: zodResolver(editFoodItemSchema),
        defaultValues: {
            name: foodItem.name,
            description: foodItem.description,
            price: foodItem.price,
            category: foodItem.category,
            preparationTime: foodItem.preparationTime,
            calories: foodItem.calories || 0,
            ingredients: foodItem.ingredients?.join(", ") || "",
            allergens: foodItem.allergens?.join(", ") || "",
        },
    });

    const onSubmit = async (data: EditFoodItemFormData) => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // TODO: Implement actual API call to update food item
        console.log("Food item updated:", data);

        setIsSubmitting(false);
        onOpenChange(false);

        // Show success message
        alert("Food item updated successfully!");
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto">
                <DialogHeader>
                    <DialogTitle>Edit Food Item</DialogTitle>
                    <DialogDescription>
                        Update food item details, pricing, and information.
                    </DialogDescription>
                </DialogHeader>

                <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        {/* Food Name */}
                        <div className="space-y-2 md:col-span-2">
                            <Label htmlFor="name">Food Name *</Label>
                            <Input
                                id="name"
                                {...register("name")}
                                placeholder="Enter food name"
                                className={errors.name ? "border-destructive" : ""}
                            />
                            {errors.name && (
                                <p className="text-sm text-destructive">{errors.name.message}</p>
                            )}
                        </div>

                        {/* Price */}
                        <div className="space-y-2">
                            <Label htmlFor="price">Price (GH₵) *</Label>
                            <Input
                                id="price"
                                type="number"
                                step="0.01"
                                {...register("price", { valueAsNumber: true })}
                                placeholder="0.00"
                                className={errors.price ? "border-destructive" : ""}
                            />
                            {errors.price && (
                                <p className="text-sm text-destructive">{errors.price.message}</p>
                            )}
                        </div>

                        {/* Category */}
                        <div className="space-y-2">
                            <Label htmlFor="category">Category *</Label>
                            <select
                                id="category"
                                {...register("category")}
                                className={`flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ${errors.category ? "border-destructive" : ""}`}
                            >
                                <option value="">Select category</option>
                                <option value="Main Course">Main Course</option>
                                <option value="Appetizer">Appetizer</option>
                                <option value="Dessert">Dessert</option>
                                <option value="Beverage">Beverage</option>
                                <option value="Side Dish">Side Dish</option>
                            </select>
                            {errors.category && (
                                <p className="text-sm text-destructive">{errors.category.message}</p>
                            )}
                        </div>

                        {/* Preparation Time */}
                        <div className="space-y-2">
                            <Label htmlFor="preparationTime">Preparation Time (min) *</Label>
                            <Input
                                id="preparationTime"
                                type="number"
                                {...register("preparationTime", { valueAsNumber: true })}
                                placeholder="30"
                                className={errors.preparationTime ? "border-destructive" : ""}
                            />
                            {errors.preparationTime && (
                                <p className="text-sm text-destructive">{errors.preparationTime.message}</p>
                            )}
                        </div>

                        {/* Calories */}
                        <div className="space-y-2">
                            <Label htmlFor="calories">Calories (kcal)</Label>
                            <Input
                                id="calories"
                                type="number"
                                {...register("calories", { valueAsNumber: true })}
                                placeholder="0"
                                className={errors.calories ? "border-destructive" : ""}
                            />
                            {errors.calories && (
                                <p className="text-sm text-destructive">{errors.calories.message}</p>
                            )}
                        </div>
                    </div>

                    {/* Description */}
                    <div className="space-y-2">
                        <Label htmlFor="description">Description *</Label>
                        <textarea
                            id="description"
                            {...register("description")}
                            placeholder="Brief description of the food item"
                            rows={3}
                            className={`flex w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 ${errors.description ? "border-destructive" : ""}`}
                        />
                        {errors.description && (
                            <p className="text-sm text-destructive">{errors.description.message}</p>
                        )}
                    </div>

                    {/* Ingredients */}
                    <div className="space-y-2">
                        <Label htmlFor="ingredients">Ingredients</Label>
                        <Input
                            id="ingredients"
                            {...register("ingredients")}
                            placeholder="Rice, Chicken, Tomatoes (comma separated)"
                        />
                        <p className="text-xs text-muted-foreground">Separate ingredients with commas</p>
                    </div>

                    {/* Allergens */}
                    <div className="space-y-2">
                        <Label htmlFor="allergens">Allergens</Label>
                        <Input
                            id="allergens"
                            {...register("allergens")}
                            placeholder="Nuts, Dairy, Gluten (comma separated)"
                        />
                        <p className="text-xs text-muted-foreground">Separate allergens with commas, or enter "None"</p>
                    </div>

                    <DialogFooter>
                        <Button
                            type="button"
                            variant="outline"
                            onClick={() => {
                                onOpenChange(false);
                                reset();
                            }}
                            disabled={isSubmitting}
                        >
                            Cancel
                        </Button>
                        <Button
                            type="submit"
                            disabled={isSubmitting}
                            className="bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:opacity-90"
                        >
                            {isSubmitting ? "Saving..." : "Save Changes"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    );
}
