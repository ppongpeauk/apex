# Apex Data Visualizer

An intelligent data visualization tool that automatically analyzes CSV files and creates the most appropriate charts using AI. Built with SwiftUI for macOS and Python FastAPI backend.

## 🌟 Features

- **Drag & Drop Interface**: Simply drag CSV files into the app
- **AI-Powered Chart Selection**: GPT-4O mini automatically determines the best chart type
- **Multiple Chart Types**: Line, Bar, Scatter, Pie, Histogram, Box Plot, and Heatmap
- **Real-World Data Support**: Handles messy, real-world CSV data with various encodings
- **Native macOS App**: Built with SwiftUI and Swift Charts for optimal performance
- **Automatic Data Mapping**: AI determines X, Y, Z axes and generates titles

## 🏗️ Architecture

- **Frontend**: SwiftUI macOS app with drag & drop support
- **Backend**: Python FastAPI server with pandas and OpenAI integration
- **Charts**: Native Swift Charts framework for optimal performance
- **AI**: GPT-4O mini for intelligent chart type classification

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

| Chart Type | Use Case | Example Data |
|------------|----------|--------------|
| **Line Chart** | Time series, trends | Sales over time, sensor readings |
| **Bar Chart** | Categorical comparisons | Sales by region, counts by category |
| **Scatter Plot** | Correlation analysis | Height vs weight, price vs rating |
| **Pie Chart** | Proportional data | Market share, budget allocation |
| **Histogram** | Distribution analysis | Age distribution, score frequencies |
| **Box Plot** | Statistical distribution | Salary ranges, performance metrics |
| **Heatmap** | 2D intensity data | Correlation matrices, geographic data |

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
├── ApexVisualizerApp/      # SwiftUI macOS app
│   └── Sources/
│       └── ApexVisualizerApp/
│           ├── main.swift              # App entry point
│           ├── ContentView.swift       # Main UI
│           ├── ChartVisualizationView.swift  # Chart rendering
│           ├── DataVisualizationViewModel.swift  # View model
│           └── APIService.swift        # Backend communication
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

1. **File Upload**: User drags CSV file into the app
2. **Data Analysis**: Backend analyzes data structure and content
3. **AI Classification**: GPT-4O mini determines optimal chart type and mappings
4. **Data Processing**: Backend processes data according to AI recommendations
5. **Visualization**: SwiftUI app renders chart using Swift Charts
6. **Display**: User sees chart with title, labels, and reasoning

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
- **Memory issues**: Large CSV files are limited to 100 rows for performance

## 📈 Performance Notes

- CSV files are limited to first 100 rows for visualization performance
- Chart data is processed server-side to reduce client load
- Drag & drop is optimized for responsive UI feedback
- API calls are asynchronous to prevent UI blocking

## 🚧 Future Enhancements

- [ ] Support for Excel files (.xlsx)
- [ ] Interactive chart features (zoom, pan, filter)
- [ ] Export charts as images
- [ ] Multiple chart views for single dataset
- [ ] Custom chart styling options
- [ ] Offline mode with local AI models
- [ ] Batch processing multiple files
- [ ] Chart sharing and collaboration features

## 📄 License

MIT License - feel free to use this project for your hackathon or personal projects!

## 🤝 Contributing

This is a hackathon project, but contributions are welcome! Please feel free to submit issues and pull requests.

---

Built with ❤️ for VTHacks 2024
