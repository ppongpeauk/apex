from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import uvicorn
import tempfile
import os
from data_analyzer import DataAnalyzer

app = FastAPI(title="Apex Data Visualization API", version="1.0.0")

# Add CORS middleware to allow requests from SwiftUI app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your SwiftUI app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the data analyzer
analyzer = DataAnalyzer()


# Pydantic models
class ChatHistoryItem(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class ChatMessage(BaseModel):
    message: str
    history: list[ChatHistoryItem] = []
    current_data: Optional[dict] = None


@app.get("/")
def read_root():
    return {"message": "Apex Data Visualization API", "status": "running"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.post("/analyze-csv")
async def analyze_csv(file: UploadFile = File(...)):
    """
    Analyze uploaded CSV file and return chart recommendations
    """
    print(f"📊 [Backend] Received file: {file.filename}")

    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="File must be a CSV")

    # Read file content
    try:
        content = await file.read()
        file_size = len(content)
        print(
            f"📏 [Backend] File size: {file_size:,} bytes ({file_size/1024/1024:.1f} MB)"
        )

        # Log file size for monitoring (no limit - we'll handle large files intelligently)
        if file_size > 50 * 1024 * 1024:  # 50MB+
            print(
                f"🐘 [Backend] Large file detected: {file_size/1024/1024:.1f}MB - using smart sampling"
            )

    except Exception as e:
        print(f"❌ [Backend] Error reading file: {e}")
        raise HTTPException(status_code=400, detail=f"Error reading file: {str(e)}")

    # Save uploaded file temporarily
    temp_file_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".csv") as temp_file:
            temp_file.write(content)
            temp_file_path = temp_file.name

        print(f"💾 [Backend] Saved temporary file: {temp_file_path}")

        # Analyze the CSV
        print(f"🔍 [Backend] Starting analysis...")
        result = analyzer.analyze_csv(temp_file_path)

        if not result["success"]:
            print(
                f"❌ [Backend] Analysis failed: {result.get('error', 'Unknown error')}"
            )
            raise HTTPException(status_code=400, detail=result["error"])

        print(f"✅ [Backend] Analysis completed successfully")

        # Double-check for any remaining NaN values before JSON serialization
        try:
            import json

            response_data = {"filename": file.filename, "analysis": result}

            # Test JSON serialization to catch NaN issues early
            json.dumps(response_data)
            print(f"🔍 [Backend] JSON serialization test passed")
            return response_data

        except (ValueError, TypeError) as json_error:
            print(f"❌ [Backend] JSON serialization failed: {json_error}")
            print(f"❌ [Backend] Problematic data type: {type(result)}")

            # Return a safe fallback response
            return {
                "filename": file.filename,
                "analysis": {
                    "success": False,
                    "error": f"Data contains non-JSON-serializable values: {str(json_error)}",
                },
            }

    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        print(f"❌ [Backend] Unexpected error: {e}")
        print(f"❌ [Backend] Error type: {type(e).__name__}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    finally:
        # Clean up temporary file
        if temp_file_path and os.path.exists(temp_file_path):
            try:
                os.unlink(temp_file_path)
                print(f"🗑️ [Backend] Cleaned up temporary file")
            except Exception as e:
                print(f"⚠️ [Backend] Failed to clean up temp file: {e}")


@app.get("/chart-types")
def get_supported_chart_types():
    """
    Return list of supported chart types
    """
    return {
        "chart_types": [
            {
                "type": "line",
                "name": "Line Chart",
                "description": "For time series or continuous data trends",
            },
            {
                "type": "bar",
                "name": "Bar Chart",
                "description": "For categorical comparisons",
            },
            {
                "type": "scatter",
                "name": "Scatter Plot",
                "description": "For correlation between two numeric variables",
            },
            {
                "type": "pie",
                "name": "Pie Chart",
                "description": "For proportional data (parts of a whole)",
            },
            {
                "type": "histogram",
                "name": "Histogram",
                "description": "For distribution of a single numeric variable",
            },
            {
                "type": "box",
                "name": "Box Plot",
                "description": "For distribution statistics and outliers",
            },
            {
                "type": "heatmap",
                "name": "Heatmap",
                "description": "For correlation matrices or 2D data intensity",
            },
        ]
    }


@app.post("/chat")
async def chat_endpoint(chat_message: ChatMessage):
    """
    Handle chat messages and return OpenAI responses with intelligent chart detection
    """
    print(f"💬 [Backend] Received chat message: {chat_message.message}")

    try:
        # Extract current data context if provided
        current_data = None
        if hasattr(chat_message, 'current_data') and chat_message.current_data:
            current_data = chat_message.current_data
            print(f"📊 [Backend] Using current data context with {len(current_data.get('columns', []))} columns")
        
        # Use the analyzer's enhanced chat method with intelligent chart detection
        response_data = analyzer.send_chat_message_with_chart_detection(
            chat_message.message, 
            chat_message.history,
            current_data
        )
        print(f"✅ [Backend] Chat response generated successfully")

        return response_data

    except Exception as e:
        print(f"❌ [Backend] Chat error: {e}")
        raise HTTPException(status_code=500, detail=f"Chat error: {str(e)}")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False, log_level="info")
