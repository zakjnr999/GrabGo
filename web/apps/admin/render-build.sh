#!/bin/bash
set -e

echo "🚀 Starting GrabGo Admin Panel build for Render..."

# Install all dependencies from root (for monorepo)
echo "📦 Installing dependencies..."
pnpm install

# Navigate to admin app
cd web/apps/admin

# Build the Next.js app
echo "🔨 Building Next.js app..."
pnpm build

# Copy static files for standalone mode
echo "📁 Copying static assets..."
if [ -d "public" ]; then
  cp -r public .next/standalone/web/apps/admin/
fi

if [ -d ".next/static" ]; then
  cp -r .next/static .next/standalone/web/apps/admin/.next/
fi

echo "✅ Build completed successfully!"
