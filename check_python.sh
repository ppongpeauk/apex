#!/bin/bash

echo "🐍 Python Version Compatibility Check"
echo "====================================="

# Check current Python version
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    echo "Current Python version: $PYTHON_VERSION"
    
    case $PYTHON_VERSION in
        "3.13")
            echo "✅ Python 3.13 - Latest version, good compatibility with updated packages"
            ;;
        "3.12")
            echo "✅ Python 3.12 - Excellent compatibility, recommended"
            ;;
        "3.11")
            echo "✅ Python 3.11 - Excellent compatibility, highly recommended"
            ;;
        "3.10")
            echo "✅ Python 3.10 - Good compatibility"
            ;;
        "3.9")
            echo "✅ Python 3.9 - Good compatibility"
            ;;
        *)
            echo "⚠️  Python $PYTHON_VERSION - May have compatibility issues"
            ;;
    esac
else
    echo "❌ Python 3 not found"
fi

echo ""
echo "📋 Recommended Python Versions (in order of preference):"
echo "1. Python 3.11 - Most stable with all packages"
echo "2. Python 3.12 - Latest stable with excellent compatibility"
echo "3. Python 3.10 - Good compatibility"
echo "4. Python 3.13 - Latest but may need updated packages"
echo "5. Python 3.9 - Older but stable"

echo ""
echo "🔧 If you want to install a different Python version:"
echo ""
echo "Option 1 - Using Homebrew (recommended):"
echo "  brew install python@3.11"
echo "  # Then use: python3.11 -m venv venv"
echo ""
echo "Option 2 - Using pyenv:"
echo "  brew install pyenv"
echo "  pyenv install 3.11.7"
echo "  pyenv local 3.11.7"
echo ""
echo "Option 3 - Download from python.org:"
echo "  Visit: https://www.python.org/downloads/"
echo "  Download Python 3.11 or 3.12"
