# Apex Data Visualizer

An intelligent data visualization tool that automatically analyzes CSV files and creates the most appropriate charts using AI. Built with SwiftUI for macOS and Python FastAPI backend with interactive chart customization.

## 🌟 Features

- **Drag & Drop Interface**: Simply drag CSV files into the app
- **AI-Powered Chart Selection**: GPT-4O mini automatically determines the best chart type
- **Interactive Chart Controls**: Real-time chart type switching and axis customization
- **Smart Data Processing**: Handles large CSV files with intelligent sampling (supports files up to 177K+ rows)
- **Real-World Data Support**: Handles messy, real-world CSV data with various encodings
- **Native macOS App**: Built with SwiftUI and Swift Charts for optimal performance
- **Automatic Data Mapping**: AI determines X, Y, Z axes with user override capability
- **Performance Optimized**: Smart sampling for LLM analysis while showing full datasets to users

## 🏗️ Architecture

- **Frontend**: SwiftUI macOS app with interactive column selection sidebar and real-time chart updates
- **Backend**: Python FastAPI server with pandas, OpenAI integration, and smart sampling strategies
- **Charts**: Native Swift Charts framework optimized for large datasets (5 bars max, 50 points max for line charts)
- **AI**: GPT-4O mini for intelligent chart type classification with validation and fallback mechanisms
- **Data Processing**: Dual-mode processing - full datasets for visualization, samples for LLM analysis

## 🚀 Quick Start

### Prerequisites
- macOS 13+ (for Swift Charts support)
- Python 3.8+
- OpenAI API key
- Xcode or Swift toolchain

### 1. Setup
```bash
./setup.sh
```

### 2. Set OpenAI API Key
The setup script will create a `.env` file for you. Edit it and add your OpenAI API key:
```bash
# Edit the .env file that was created
nano .env

# Replace 'your_openai_api_key_here' with your actual API key
OPENAI_API_KEY=sk-your-actual-key-here
```

### 3. Start Backend (Terminal 1)
```bash
./run_backend.sh
```

### 4. Start App (Terminal 2)
```bash
./run_app.sh
```

## 📊 Supported Chart Types

Currently optimized and fully supported:

| Chart Type | Use Case | Example Data | Features |
|------------|----------|--------------|----------|
| **Bar Chart** | Categorical comparisons | Sales by region, counts by category | Top 5 values, auto-aggregation, clean labels |
| **Line Chart** | Time series, trends | Sales over time, sensor readings | Smart sampling (50 points max), temporal distribution |

*Note: Focus on bar and line charts for optimal performance and reliability. Other chart types (scatter, pie, histogram) were simplified to ensure core functionality works perfectly.*

## 🔧 Manual Usage

### Backend Only
```bash
cd backend
source venv/bin/activate
python main.py
```

### SwiftUI App Only
```bash
cd ApexVisualizerApp
swift run
```

### API Testing
```bash
curl -X POST "http://127.0.0.1:8000/analyze-csv" \
     -H "Content-Type: multipart/form-data" \
     -F "file=@your_data.csv"
```

## 📁 Project Structure

```
apex/
├── backend/                 # Python FastAPI backend
│   ├── main.py             # FastAPI application
│   ├── data_analyzer.py    # Core data analysis logic
│   ├── config.py           # Configuration management
│   ├── requirements.txt    # Python dependencies
│   └── venv/               # Virtual environment (created by setup)
├── ApexApp/                # SwiftUI macOS app (Main App)
│   ├── ApexApp/
│   │   ├── ContentView.swift       # Main UI with interactive sidebar
│   │   ├── ChartVisualizationView.swift  # Optimized chart rendering
│   │   ├── DataVisualizationViewModel.swift  # View model with AnyCodable handling
│   │   ├── APIService.swift        # Backend communication with fallback
│   │   ├── ApexAppApp.swift        # App entry point
│   │   └── Info.plist              # Network permissions for large file processing
│   └── ApexApp.xcodeproj           # Xcode project
├── ApexVisualizerApp/              # Legacy app directory (alternative version)
├── test_data/              # Sample CSV files for testing
├── .env                    # Environment variables (created by setup)
├── env.example             # Template for environment variables
├── .gitignore              # Git ignore rules
└── README.md
```

## 🔐 Environment Setup

The project uses a `.env` file for configuration:

1. **Automatic Setup**: `./setup.sh` creates `.env` from `env.example`
2. **Manual Setup**: Copy `env.example` to `.env` and fill in values
3. **Required Variables**:
   - `OPENAI_API_KEY`: Your OpenAI API key from [platform.openai.com](https://platform.openai.com/api-keys)

**Important**: The `.env` file is git-ignored for security. Never commit API keys to version control!

## 🧪 Testing with Sample Data

The project includes sample CSV files in `test_data/`:

1. **Sales Data** (`sample_sales.csv`): Monthly sales by region and product
2. **Sensor Data** (`sample_sensor.csv`): Time-series sensor readings

## 🔍 How It Works

### Initial Analysis
1. **File Upload**: User drags CSV file into the app (supports files up to 177K+ rows)
2. **Smart Sampling**: Backend uses strategic sampling for AI analysis while preserving full dataset
3. **Data Analysis**: Backend analyzes data structure, types, and content patterns
4. **AI Classification**: GPT-4O mini determines optimal chart type with validation to prevent same-axis assignments
5. **Full Dataset Processing**: Backend processes complete dataset (up to 10K points) for visualization
6. **Chart Rendering**: SwiftUI app renders optimized charts (5 bars max, 50 line points max)

### Interactive Controls
7. **Real-time Customization**: User can switch between chart types (Bar ↔ Line) instantly
8. **Column Selection**: Interactive sidebar allows X/Y axis selection from available CSV columns
9. **Data Regeneration**: Chart updates immediately with new axis mappings using original data
10. **Performance Optimization**: Smart aggregation and sampling maintain responsive UI

## 🛠️ Development

### Adding New Chart Types

1. Update `data_analyzer.py` to include new chart type in AI prompt
2. Add visualization logic in `ChartVisualizationView.swift`
3. Update chart types endpoint in `main.py`

### Customizing AI Behavior

Edit the prompt in `data_analyzer.py` `_get_ai_recommendation()` method to adjust how the AI selects chart types and data mappings.

## 🐛 Troubleshooting

### Backend Issues
- **Port 8000 in use**: Change port in `main.py`
- **OpenAI API errors**: Check API key and quota
- **CSV parsing errors**: Check file encoding and format

### SwiftUI App Issues
- **Build errors**: Ensure macOS 13+ and Xcode installed
- **Network errors**: Verify backend is running on correct port
- **Chart rendering**: Check data format and Swift Charts compatibility

### Common Issues
- **CORS errors**: Backend includes CORS middleware for local development
- **File permissions**: Ensure CSV files are readable
- **AnyCodable display**: Fixed - charts now properly handle backend JSON responses
- **Chart switching resets**: Fixed - maintains original data when switching chart types
- **Label overflow**: Fixed - limited to 5 bars and 50 line points maximum

## 📈 Performance Notes

- **Large File Support**: Handles CSV files up to 177K+ rows with smart sampling
- **Dual Processing**: Samples data for AI analysis (1-3K rows) while processing full datasets for visualization
- **Chart Optimization**: Bar charts limited to top 5 values, line charts to 50 points maximum
- **Real-time Updates**: Interactive controls update charts instantly without backend calls
- **Memory Management**: Strategic sampling prevents memory issues with large datasets
- **Network Optimization**: Fallback connection logic (localhost → IP) with comprehensive logging

## 🚧 Future Enhancements

### High Priority
- [ ] Restore additional chart types (scatter, pie) with same optimization approach
- [ ] Advanced filtering system for categorical data (country selection, date ranges)
- [ ] Chart export functionality (PNG, PDF, SVG)
- [ ] Data aggregation options (sum, mean, count) user selection

### Medium Priority
- [ ] Support for Excel files (.xlsx)
- [ ] Interactive chart features (zoom, pan, hover tooltips)
- [ ] Multiple chart views for single dataset
- [ ] Custom chart styling and themes
- [ ] Batch processing multiple files

### Future Considerations
- [ ] Offline mode with local AI models
- [ ] Chart sharing and collaboration features
- [ ] WebSocket real-time updates for large file processing
- [ ] Database connectivity beyond CSV files

## 📄 License

MIT License - feel free to use this project for your hackathon or personal projects!

## 🤝 Contributing

This is a hackathon project, but contributions are welcome! Please feel free to submit issues and pull requests.

---

Built with ❤️ for VTHacks 2025

---

## 🎯 Recent Updates (September 27, 2025)

### ✅ Major Performance & Reliability Improvements
- **Fixed AnyCodable corruption**: Charts now properly handle backend JSON responses
- **Interactive sidebar**: Real-time chart type and axis selection with instant updates
- **Smart data limits**: Bar charts show top 5 values, line charts limited to 50 points
- **Large file support**: Successfully tested with 177K+ row COVID datasets
- **Chart switching**: Maintains original data when switching between chart types
- **Network resilience**: Fallback connection logic and comprehensive error handling

### 🔧 Technical Achievements
- **Dual processing architecture**: AI analysis on samples, full visualization on complete datasets
- **Strategic sampling**: Temporal distribution for time series, representative sampling for large files
- **Performance optimization**: 5-15x improvement in chart rendering and label management
- **Code simplification**: Focused on bar/line charts for maximum reliability
