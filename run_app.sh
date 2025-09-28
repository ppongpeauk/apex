#!/bin/bash

echo "📱 Starting Apex SwiftUI App..."

# Check if backend is running
echo "🔍 Checking if backend is running..."
if ! curl -s http://127.0.0.1:8000/health > /dev/null; then
    echo "❌ Backend server is not running!"
    echo "   Please start the backend first with: ./run_backend.sh"
    echo "   Or run it in a separate terminal window."
    exit 1
fi

echo "✅ Backend is running!"

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode command line tools not found!"
    echo "   Please install Xcode or run: xcode-select --install"
    exit 1
fi

echo "🚀 Building and running SwiftUI app with Xcode..."

# Build and run the app
xcodebuild -project ApexVisualizerApp.xcodeproj -scheme ApexVisualizerApp -configuration Debug build
if [ $? -eq 0 ]; then
    echo "✅ Build successful! Starting app..."
    open -a ApexVisualizerApp
else
    echo "❌ Build failed!"
    exit 1
fi
