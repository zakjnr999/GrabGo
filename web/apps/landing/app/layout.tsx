import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "GrabGo | Food, Groceries, Pharmacy in One App",
  description:
    "Order food, groceries, and pharmacy essentials with real-time delivery tracking in GrabGo.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="font-sans antialiased">
        {children}
      </body>
    </html>
  );
}
