#!/bin/bash

echo "🔍 Apex Data Visualizer - Diagnostic Tool"
echo "========================================"

# Check Python installation
echo ""
echo "🐍 Python Environment:"
echo "----------------------"
if command -v python3 &> /dev/null; then
    echo "✅ Python 3: $(python3 --version)"
else
    echo "❌ Python 3 not found"
fi

if command -v pip3 &> /dev/null; then
    echo "✅ pip3: $(pip3 --version)"
elif python3 -m pip --version &> /dev/null; then
    echo "✅ pip (via python3 -m): $(python3 -m pip --version)"
else
    echo "❌ pip not found"
fi

# Check Swift installation
echo ""
echo "🏃 Swift Environment:"
echo "--------------------"
if command -v swift &> /dev/null; then
    echo "✅ Swift: $(swift --version | head -1)"
else
    echo "❌ Swift not found"
fi

# Check project structure
echo ""
echo "📁 Project Structure:"
echo "--------------------"
if [ -f "setup.sh" ]; then
    echo "✅ setup.sh found"
else
    echo "❌ setup.sh not found"
fi

if [ -f "run_backend.sh" ]; then
    echo "✅ run_backend.sh found"
else
    echo "❌ run_backend.sh not found"
fi

if [ -f "run_app.sh" ]; then
    echo "✅ run_app.sh found"
else
    echo "❌ run_app.sh not found"
fi

if [ -d "backend" ]; then
    echo "✅ backend/ directory found"
    
    if [ -f "backend/main.py" ]; then
        echo "  ✅ main.py found"
    else
        echo "  ❌ main.py not found"
    fi
    
    if [ -f "backend/requirements.txt" ]; then
        echo "  ✅ requirements.txt found"
    else
        echo "  ❌ requirements.txt not found"
    fi
    
    if [ -d "backend/venv" ]; then
        echo "  ✅ Virtual environment found"
        
        # Test virtual environment
        cd backend
        source venv/bin/activate 2>/dev/null
        if [ -n "$VIRTUAL_ENV" ]; then
            echo "  ✅ Virtual environment can be activated"
            
            # Check installed packages
            echo ""
            echo "📦 Installed Packages:"
            echo "---------------------"
            python -c "import fastapi; print('✅ FastAPI installed')" 2>/dev/null || echo "❌ FastAPI not installed"
            python -c "import uvicorn; print('✅ Uvicorn installed')" 2>/dev/null || echo "❌ Uvicorn not installed"
            python -c "import pandas; print('✅ Pandas installed')" 2>/dev/null || echo "❌ Pandas not installed"
            python -c "import openai; print('✅ OpenAI installed')" 2>/dev/null || echo "❌ OpenAI not installed"
            python -c "import dotenv; print('✅ python-dotenv installed')" 2>/dev/null || echo "❌ python-dotenv not installed"
            
        else
            echo "  ❌ Virtual environment cannot be activated"
        fi
        cd ..
    else
        echo "  ❌ Virtual environment not found"
    fi
else
    echo "❌ backend/ directory not found"
fi

if [ -d "ApexVisualizerApp" ]; then
    echo "✅ ApexVisualizerApp/ directory found"
else
    echo "❌ ApexVisualizerApp/ directory not found"
fi

# Check environment file
echo ""
echo "🔐 Environment Configuration:"
echo "----------------------------"
if [ -f ".env" ]; then
    echo "✅ .env file found"
    if grep -q "^OPENAI_API_KEY=" .env && ! grep -q "your_openai_api_key_here" .env; then
        echo "✅ OpenAI API key appears to be set"
    else
        echo "⚠️  OpenAI API key not set or using placeholder"
    fi
else
    echo "❌ .env file not found"
fi

if [ -f "env.example" ]; then
    echo "✅ env.example found"
else
    echo "❌ env.example not found"
fi

# Check test data
echo ""
echo "🧪 Test Data:"
echo "-------------"
if [ -d "test_data" ]; then
    echo "✅ test_data/ directory found"
    echo "   Files: $(ls test_data/ 2>/dev/null | wc -l) CSV files"
else
    echo "❌ test_data/ directory not found"
fi

echo ""
echo "🎯 Recommendations:"
echo "==================="

if [ ! -d "backend/venv" ]; then
    echo "1. Run ./setup.sh to create virtual environment"
fi

if [ ! -f ".env" ]; then
    echo "2. Create .env file with your OpenAI API key"
fi

if ! command -v python3 &> /dev/null; then
    echo "3. Install Python 3 from python.org"
fi

if ! command -v swift &> /dev/null; then
    echo "4. Install Xcode or Swift toolchain"
fi

echo ""
echo "For help, check the README.md file or run ./setup.sh"
