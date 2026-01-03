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
import { type Vendor } from "../../../../lib/mockData";

const deliverySettingsSchema = z.object({
    deliveryFee: z.number().min(0, "Delivery fee must be 0 or greater"),
    minOrderValue: z.number().min(0, "Minimum order must be 0 or greater"),
    deliveryRadius: z.number().min(1, "Delivery radius must be at least 1 km").max(50, "Maximum radius is 50 km"),
    preparationTime: z.number().min(5, "Preparation time must be at least 5 minutes"),
});

type DeliverySettingsFormData = z.infer<typeof deliverySettingsSchema>;

interface DeliverySettingsDialogProps {
    vendor: Vendor;
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function DeliverySettingsDialog({
    vendor,
    open,
    onOpenChange,
}: DeliverySettingsDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);

    const {
        register,
        handleSubmit,
        formState: { errors },
        reset,
        watch,
    } = useForm<DeliverySettingsFormData>({
        resolver: zodResolver(deliverySettingsSchema),
        defaultValues: {
            deliveryFee: 5,
            minOrderValue: 20,
            deliveryRadius: vendor.deliveryRadius || 5,
            preparationTime: vendor.preparationTime || 30,
        },
    });

    const deliveryFee = watch("deliveryFee") || 0;
    const minOrderValue = watch("minOrderValue") || 0;

    const onSubmit = async (data: DeliverySettingsFormData) => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // TODO: Implement actual API call to update delivery settings
        console.log("Delivery settings updated:", data);

        setIsSubmitting(false);
        onOpenChange(false);

        // Show success message
        alert("Delivery settings updated successfully!");
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[500px]">
                <DialogHeader>
                    <DialogTitle>Delivery Settings</DialogTitle>
                    <DialogDescription>
                        Update delivery fees, minimum order amounts, and delivery coverage.
                    </DialogDescription>
                </DialogHeader>

                <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                        {/* Delivery Fee */}
                        <div className="space-y-2">
                            <Label htmlFor="deliveryFee">Delivery Fee (GH₵)</Label>
                            <Input
                                id="deliveryFee"
                                type="number"
                                step="0.01"
                                {...register("deliveryFee", { valueAsNumber: true })}
                                className={errors.deliveryFee ? "border-destructive" : ""}
                            />
                            {errors.deliveryFee && (
                                <p className="text-sm text-destructive">{errors.deliveryFee.message}</p>
                            )}
                        </div>

                        {/* Minimum Order Value */}
                        <div className="space-y-2">
                            <Label htmlFor="minOrderValue">Min Order (GH₵)</Label>
                            <Input
                                id="minOrderValue"
                                type="number"
                                step="0.01"
                                {...register("minOrderValue", { valueAsNumber: true })}
                                className={errors.minOrderValue ? "border-destructive" : ""}
                            />
                            {errors.minOrderValue && (
                                <p className="text-sm text-destructive">{errors.minOrderValue.message}</p>
                            )}
                        </div>

                        {/* Delivery Radius */}
                        <div className="space-y-2">
                            <Label htmlFor="deliveryRadius">Delivery Radius (km)</Label>
                            <Input
                                id="deliveryRadius"
                                type="number"
                                {...register("deliveryRadius", { valueAsNumber: true })}
                                className={errors.deliveryRadius ? "border-destructive" : ""}
                            />
                            {errors.deliveryRadius && (
                                <p className="text-sm text-destructive">{errors.deliveryRadius.message}</p>
                            )}
                        </div>

                        {/* Preparation Time */}
                        <div className="space-y-2">
                            <Label htmlFor="preparationTime">Prep Time (min)</Label>
                            <Input
                                id="preparationTime"
                                type="number"
                                {...register("preparationTime", { valueAsNumber: true })}
                                className={errors.preparationTime ? "border-destructive" : ""}
                            />
                            {errors.preparationTime && (
                                <p className="text-sm text-destructive">{errors.preparationTime.message}</p>
                            )}
                        </div>
                    </div>

                    {/* Preview */}
                    <div className="rounded-lg border border-border/50 p-4 bg-muted/30">
                        <p className="text-sm font-medium mb-2">Preview</p>
                        <div className="space-y-1 text-sm text-muted-foreground">
                            <p>• Delivery fee: <span className="font-medium text-foreground">GH₵{deliveryFee.toFixed(2)}</span></p>
                            <p>• Minimum order: <span className="font-medium text-foreground">GH₵{minOrderValue.toFixed(2)}</span></p>
                            <p>• Coverage: <span className="font-medium text-foreground">{watch("deliveryRadius") || 0} km radius</span></p>
                            <p>• Prep time: <span className="font-medium text-foreground">{watch("preparationTime") || 0} minutes</span></p>
                        </div>
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
                            {isSubmitting ? "Saving..." : "Save Settings"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    );
}
