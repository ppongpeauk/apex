#!/usr/bin/env python3
"""
Startup script for the Apex Data Visualization backend server
"""
import os
import sys
import subprocess
from pathlib import Path

def check_requirements():
    """Check if required packages are installed"""
    try:
        import fastapi
        import uvicorn
        import pandas
        import openai
        return True
    except ImportError as e:
        print(f"Missing required package: {e}")
        print("Please install requirements with: pip install -r requirements.txt")
        return False

def check_env():
    """Check if environment variables are set"""
    if not os.getenv("OPENAI_API_KEY"):
        print("Warning: OPENAI_API_KEY environment variable not set!")
        print("Please set your OpenAI API key:")
        print("export OPENAI_API_KEY='your-api-key-here'")
        return False
    return True

def main():
    print("🚀 Starting Apex Data Visualization Backend...")
    
    if not check_requirements():
        sys.exit(1)
    
    if not check_env():
        print("You can still run the server, but AI features won't work without the API key.")
        response = input("Continue anyway? (y/N): ")
        if response.lower() != 'y':
            sys.exit(1)
    
    print("✅ All checks passed!")
    print("🌐 Starting server at http://127.0.0.1:8000")
    print("📖 API docs available at http://127.0.0.1:8000/docs")
    print("Press Ctrl+C to stop the server")
    
    # Start the server
    os.system("python main.py")

if __name__ == "__main__":
    main()
