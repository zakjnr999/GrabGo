#!/usr/bin/env bash
# Render build script for GrabGo ML Service

set -e  # Exit on error

echo "🚀 Starting build process..."

# Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📥 Installing dependencies..."
pip install -r requirements.txt

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p ml_models/recommendation
mkdir -p ml_models/forecasting
mkdir -p ml_models/fraud
mkdir -p logs

echo "✅ Build completed successfully!"
