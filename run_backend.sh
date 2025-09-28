#!/bin/bash

echo "🚀 Starting Apex Backend Server..."

# Change to backend directory
cd backend

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found!"
    echo "   Please run ./setup.sh first to create the environment."
    exit 1
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Verify activation
if [ -z "$VIRTUAL_ENV" ]; then
    echo "❌ Failed to activate virtual environment!"
    echo "   Try running ./setup.sh to recreate the environment."
    exit 1
fi

echo "✅ Virtual environment activated: $VIRTUAL_ENV"

# Check if .env file exists
if [ ! -f "../.env" ]; then
    echo "⚠️  Warning: .env file not found!"
    echo "   Please run ./setup.sh first to create the .env file"
    echo "   Or create .env manually with: OPENAI_API_KEY=your_key_here"
    echo ""
fi

# Verify required packages are installed
echo "🔍 Verifying dependencies..."
python -c "import fastapi" 2>/dev/null || { 
    echo "❌ FastAPI not found! Please run ./setup.sh to install dependencies."
    exit 1
}

python -c "import uvicorn" 2>/dev/null || { 
    echo "❌ Uvicorn not found! Please run ./setup.sh to install dependencies."
    exit 1
}

echo "✅ Dependencies verified!"

echo ""
echo "🌐 Server starting at http://127.0.0.1:8000"
echo "📖 API docs at http://127.0.0.1:8000/docs"
echo "❌ Press Ctrl+C to stop the server"
echo ""

# Start the server
echo "🚀 Starting server process..."
python main.py
