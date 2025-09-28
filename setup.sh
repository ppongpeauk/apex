#!/bin/bash

echo "🚀 Setting up Apex Data Visualizer..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "🐍 Detected Python version: $PYTHON_VERSION"

# Check for Python version compatibility
if [[ "$PYTHON_VERSION" == "3.13" ]]; then
    echo "✅ Python 3.13 detected - using latest compatible package versions"
elif [[ "$PYTHON_VERSION" == "3.12" ]]; then
    echo "✅ Python 3.12 detected - good compatibility"
elif [[ "$PYTHON_VERSION" == "3.11" ]]; then
    echo "✅ Python 3.11 detected - excellent compatibility"
elif [[ "$PYTHON_VERSION" == "3.10" ]]; then
    echo "✅ Python 3.10 detected - good compatibility"
elif [[ "$PYTHON_VERSION" == "3.9" ]]; then
    echo "✅ Python 3.9 detected - good compatibility"
else
    echo "⚠️  Python $PYTHON_VERSION detected - may have compatibility issues"
    echo "   Recommended: Python 3.9, 3.10, 3.11, 3.12, or 3.13"
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
    echo "❌ pip is not installed. Please install pip first."
    exit 1
fi

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed. Please install Xcode or Swift toolchain first."
    exit 1
fi

# Setup Python backend
echo "📦 Setting up Python backend..."
cd backend

# Remove existing virtual environment if it's corrupted
if [ -d "venv" ]; then
    echo "🔄 Removing existing virtual environment..."
    rm -rf venv
fi

# Create fresh virtual environment
echo "🆕 Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Verify activation
if [ -z "$VIRTUAL_ENV" ]; then
    echo "❌ Failed to activate virtual environment!"
    exit 1
fi

echo "✅ Virtual environment activated: $VIRTUAL_ENV"

# Upgrade pip to latest version
echo "📦 Upgrading pip..."
python -m pip install --upgrade pip

# Install requirements with verbose output
echo "📦 Installing Python dependencies..."
echo "   This may take a few minutes, especially for pandas..."

# For Python 3.13, we need to install packages in a specific order
if [[ "$PYTHON_VERSION" == "3.13" ]]; then
    echo "🔧 Installing packages optimized for Python 3.13..."
    pip install --upgrade pip setuptools wheel
    pip install numpy>=1.26.0
    pip install pandas>=2.2.0
    pip install -r requirements.txt --verbose
else
    pip install -r requirements.txt --verbose
fi

# Verify installations
echo "🔍 Verifying installations..."
python -c "import fastapi; print('✅ FastAPI installed successfully')" || { echo "❌ FastAPI installation failed"; exit 1; }
python -c "import uvicorn; print('✅ Uvicorn installed successfully')" || { echo "❌ Uvicorn installation failed"; exit 1; }
python -c "import pandas; print('✅ Pandas installed successfully')" || { echo "❌ Pandas installation failed"; exit 1; }
python -c "import openai; print('✅ OpenAI installed successfully')" || { echo "❌ OpenAI installation failed"; exit 1; }

echo "✅ Backend setup complete!"

# Setup environment file
cd ..
if [ ! -f ".env" ]; then
    if [ -f "env.example" ]; then
        cp env.example .env
        echo "📄 Created .env file from env.example"
        echo "⚠️  Please edit .env and add your OpenAI API key!"
        echo "   Open .env and replace 'your_openai_api_key_here' with your actual key"
    else
        echo "OPENAI_API_KEY=your_openai_api_key_here" > .env
        echo "📄 Created .env file"
        echo "⚠️  Please edit .env and add your OpenAI API key!"
    fi
else
    echo "✅ .env file already exists"
fi

# Check for OpenAI API key
if [ ! -f ".env" ] || ! grep -q "^OPENAI_API_KEY=" .env || grep -q "your_openai_api_key_here" .env; then
    echo "⚠️  Please edit .env and set your OpenAI API key!"
    echo "   Get your key from: https://platform.openai.com/api-keys"
fi

# Create test directories if they don't exist
if [ ! -d "test_data" ]; then
    mkdir -p test_data
    echo "📁 Created test_data directory"
fi

# Test the backend setup
echo "🧪 Testing backend setup..."
cd backend
source venv/bin/activate
python -c "
try:
    from fastapi import FastAPI
    from data_analyzer import DataAnalyzer
    print('✅ All imports successful!')
except Exception as e:
    print(f'❌ Import test failed: {e}')
    exit(1)
"

if [ $? -eq 0 ]; then
    echo "✅ Backend test passed!"
else
    echo "❌ Backend test failed!"
    exit 1
fi

cd ..

echo ""
echo "🎉 Setup complete! You can now run the application."
echo ""
echo "Next steps:"
echo "1. Edit .env and add your OpenAI API key"
echo "2. Run: ./run_backend.sh (in one terminal)"
echo "3. Run: ./run_app.sh (in another terminal)"
echo ""
echo "Or test manually:"
echo "  cd backend && source venv/bin/activate && python main.py"
