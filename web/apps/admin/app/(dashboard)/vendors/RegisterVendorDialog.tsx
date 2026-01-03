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
    Button,
    Input,
    Label,
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@grabgo/ui";
import { type Vendor } from "../../../lib/mockData";

const registerVendorSchema = z.object({
    name: z.string().min(2, "Vendor name must be at least 2 characters"),
    type: z.enum(["food", "grocery", "pharmacy", "market"] as const),
    ownerName: z.string().min(2, "Owner name must be at least 2 characters"),
    email: z.string().email("Invalid email address"),
    phone: z.string().min(10, "Phone number must be at least 10 digits"),
    address: z.string().min(5, "Address must be at least 5 characters"),
});

type RegisterVendorFormData = z.infer<typeof registerVendorSchema>;

interface RegisterVendorDialogProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    onSuccess: (vendor: any) => void;
}

export function RegisterVendorDialog({
    open,
    onOpenChange,
    onSuccess,
}: RegisterVendorDialogProps) {
    const [isSubmitting, setIsSubmitting] = useState(false);

    const {
        register,
        handleSubmit,
        formState: { errors },
        setValue,
        watch,
        reset,
    } = useForm<RegisterVendorFormData>({
        resolver: zodResolver(registerVendorSchema),
        defaultValues: {
            name: "",
            type: "food",
            ownerName: "",
            email: "",
            phone: "",
            address: "",
        },
    });

    const onSubmit = async (data: RegisterVendorFormData) => {
        setIsSubmitting(true);

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        const newVendor = {
            id: `VEN-${Math.floor(Math.random() * 1000)}`,
            ...data,
            status: "open",
            rating: 0,
            totalRevenue: 0,
            orderCount: 0,
            isVerified: false,
            isFeatured: false,
            createdAt: new Date().toISOString(),
        };

        console.log("Registered new vendor:", newVendor);

        setIsSubmitting(false);
        onSuccess(newVendor);
        reset();
        onOpenChange(false);
    };

    return (
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-[600px]">
                <DialogHeader>
                    <DialogTitle>Register New Vendor</DialogTitle>
                    <DialogDescription>
                        Add a new vendor to the platform. They will start in 'Open' and 'Unverified' status.
                    </DialogDescription>
                </DialogHeader>

                <form onSubmit={handleSubmit(onSubmit)} className="space-y-6 py-4">
                    <div className="grid grid-cols-2 gap-4">
                        {/* Vendor Name */}
                        <div className="space-y-2">
                            <Label htmlFor="name">Business Name</Label>
                            <Input
                                id="name"
                                {...register("name")}
                                placeholder="e.g. Tasty Burgers"
                                className={errors.name ? "border-destructive" : ""}
                            />
                            {errors.name && (
                                <p className="text-sm text-destructive">{errors.name.message}</p>
                            )}
                        </div>

                        {/* Service Type */}
                        <div className="space-y-2">
                            <Label htmlFor="type">Service Type</Label>
                            <Select
                                onValueChange={(value: any) => setValue("type", value)}
                                defaultValue={watch("type")}
                            >
                                <SelectTrigger>
                                    <SelectValue placeholder="Select type" />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="food">Food</SelectItem>
                                    <SelectItem value="grocery">Grocery</SelectItem>
                                    <SelectItem value="pharmacy">Pharmacy</SelectItem>
                                    <SelectItem value="market">Market</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>
                    </div>

                    <div className="space-y-2">
                        <Label htmlFor="address">Business Address</Label>
                        <Input
                            id="address"
                            {...register("address")}
                            placeholder="Full physical address"
                            className={errors.address ? "border-destructive" : ""}
                        />
                        {errors.address && (
                            <p className="text-sm text-destructive">{errors.address.message}</p>
                        )}
                    </div>

                    <div className="border-t border-border/50 my-4" />
                    <h4 className="text-sm font-medium text-muted-foreground mb-3">Owner Information</h4>

                    <div className="space-y-2">
                        <Label htmlFor="ownerName">Owner Full Name</Label>
                        <Input
                            id="ownerName"
                            {...register("ownerName")}
                            placeholder="John Doe"
                            className={errors.ownerName ? "border-destructive" : ""}
                        />
                        {errors.ownerName && (
                            <p className="text-sm text-destructive">{errors.ownerName.message}</p>
                        )}
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-2">
                            <Label htmlFor="email">Email Address</Label>
                            <Input
                                id="email"
                                type="email"
                                {...register("email")}
                                placeholder="owner@example.com"
                                className={errors.email ? "border-destructive" : ""}
                            />
                            {errors.email && (
                                <p className="text-sm text-destructive">{errors.email.message}</p>
                            )}
                        </div>

                        <div className="space-y-2">
                            <Label htmlFor="phone">Phone Number</Label>
                            <Input
                                id="phone"
                                type="tel"
                                {...register("phone")}
                                placeholder="+233..."
                                className={errors.phone ? "border-destructive" : ""}
                            />
                            {errors.phone && (
                                <p className="text-sm text-destructive">{errors.phone.message}</p>
                            )}
                        </div>
                    </div>

                    <DialogFooter className="mt-6">
                        <Button
                            type="button"
                            variant="outline"
                            onClick={() => onOpenChange(false)}
                            disabled={isSubmitting}
                        >
                            Cancel
                        </Button>
                        <Button
                            type="submit"
                            disabled={isSubmitting}
                            className="bg-gradient-to-br from-[#FE6132] to-[#FE6132]/80 text-white hover:opacity-90"
                        >
                            {isSubmitting ? "Registering..." : "Register Vendor"}
                        </Button>
                    </DialogFooter>
                </form>
            </DialogContent>
        </Dialog>
    );
}
