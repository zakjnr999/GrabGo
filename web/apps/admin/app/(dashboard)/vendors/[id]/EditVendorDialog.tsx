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

const editVendorSchema = z.object({
    name: z.string().min(3, "Name must be at least 3 characters"),
    email: z.string().email("Invalid email address"),
    phone: z.string().min(10, "Phone number must be at least 10 digits"),
    address: z.string().min(5, "Address must be at least 5 characters"),
    description: z.string().optional(),
    openingHours: z.string().optional(),
});

type EditVendorFormData = z.infer<typeof editVendorSchema>;

interface EditVendorDialogProps {
    vendor: Vendor;
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function EditVendorDialog({
    vendor,
    open,
    onOpenChange,
}: EditVendorDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);

    const {
        register,
        handleSubmit,
        formState: { errors },
        reset,
    } = useForm<EditVendorFormData>({
        resolver: zodResolver(editVendorSchema),
        defaultValues: {
            name: vendor.name,
            email: vendor.email,
            phone: vendor.phone,
            address: vendor.address,
            description: "Delicious food and great service",
            openingHours: "9:00 AM - 10:00 PM (Daily)",
        },
    });

    const onSubmit = async (data: EditVendorFormData) => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // TODO: Implement actual API call to update vendor
        console.log("Vendor updated:", data);

        setIsSubmitting(false);
        onOpenChange(false);

        // Show success message
        alert("Vendor details updated successfully!");
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto">
                <DialogHeader>
                    <DialogTitle>Edit Vendor Details</DialogTitle>
                    <DialogDescription>
                        Update vendor information and business details.
                    </DialogDescription>
                </DialogHeader>

                <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        {/* Vendor Name */}
                        <div className="space-y-2">
                            <Label htmlFor="name">Vendor Name *</Label>
                            <Input
                                id="name"
                                {...register("name")}
                                placeholder="Enter vendor name"
                                className={errors.name ? "border-destructive" : ""}
                            />
                            {errors.name && (
                                <p className="text-sm text-destructive">{errors.name.message}</p>
                            )}
                        </div>

                        {/* Email */}
                        <div className="space-y-2">
                            <Label htmlFor="email">Email *</Label>
                            <Input
                                id="email"
                                type="email"
                                {...register("email")}
                                placeholder="vendor@example.com"
                                className={errors.email ? "border-destructive" : ""}
                            />
                            {errors.email && (
                                <p className="text-sm text-destructive">{errors.email.message}</p>
                            )}
                        </div>

                        {/* Phone */}
                        <div className="space-y-2">
                            <Label htmlFor="phone">Phone Number *</Label>
                            <Input
                                id="phone"
                                {...register("phone")}
                                placeholder="+233 XX XXX XXXX"
                                className={errors.phone ? "border-destructive" : ""}
                            />
                            {errors.phone && (
                                <p className="text-sm text-destructive">{errors.phone.message}</p>
                            )}
                        </div>

                        {/* Opening Hours */}
                        <div className="space-y-2">
                            <Label htmlFor="openingHours">Opening Hours</Label>
                            <Input
                                id="openingHours"
                                {...register("openingHours")}
                                placeholder="9:00 AM - 10:00 PM"
                            />
                        </div>
                    </div>

                    {/* Address */}
                    <div className="space-y-2">
                        <Label htmlFor="address">Address *</Label>
                        <Input
                            id="address"
                            {...register("address")}
                            placeholder="Enter full address"
                            className={errors.address ? "border-destructive" : ""}
                        />
                        {errors.address && (
                            <p className="text-sm text-destructive">{errors.address.message}</p>
                        )}
                    </div>

                    {/* Description */}
                    <div className="space-y-2">
                        <Label htmlFor="description">Description</Label>
                        <textarea
                            id="description"
                            {...register("description")}
                            placeholder="Brief description of the vendor"
                            rows={3}
                            className={`flex w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50`}
                        />
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
