#!/bin/bash
"""
Wrapper script to test OpenAI API key using the backend virtual environment
"""

echo "🧪 Testing OpenAI API Key for Apex Data Visualization"
echo "=" * 60

# Check if we're in the right directory
if [ ! -f "test_api_key.py" ]; then
    echo "❌ test_api_key.py not found!"
    echo "   Please run this script from the project root directory."
    exit 1
fi

# Check if backend virtual environment exists
if [ ! -d "backend/venv" ]; then
    echo "❌ Backend virtual environment not found!"
    echo "   Please run ./setup.sh first to create the environment."
    exit 1
fi

# Activate backend virtual environment
echo "🔌 Activating backend virtual environment..."
source backend/venv/bin/activate

# Verify activation
if [ -z "$VIRTUAL_ENV" ]; then
    echo "❌ Failed to activate virtual environment!"
    exit 1
fi

echo "✅ Virtual environment activated: $VIRTUAL_ENV"

# Run the test
echo "🚀 Running API key test..."
python test_api_key.py
