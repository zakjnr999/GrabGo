#!/bin/bash

# GrabGo ML Service - Quick Start Script

set -e

echo "🚀 GrabGo ML Service - Quick Start"
echo "=================================="

# Check Python version
echo "📋 Checking Python version..."
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "✅ Python $python_version detected"

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Copy environment file
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env
    echo "⚠️  Please edit .env with your configuration"
else
    echo "✅ .env file already exists"
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p ml_models/recommendation
mkdir -p ml_models/forecasting
mkdir -p ml_models/fraud
mkdir -p logs
echo "✅ Directories created"

# Check database connections
echo "🔍 Checking database connections..."
echo "Please ensure PostgreSQL, MongoDB, and Redis are running"
echo "PostgreSQL: localhost:5432"
echo "MongoDB: localhost:27017"
echo "Redis: localhost:6379"

# Ask if user wants to start the service
read -p "🚀 Start the ML service now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "🚀 Starting ML service..."
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
else
    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "To start the service manually, run:"
    echo "  source venv/bin/activate"
    echo "  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
    echo ""
    echo "API Documentation will be available at:"
    echo "  http://localhost:8000/docs"
    echo ""
fi
