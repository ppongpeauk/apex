import os
from dotenv import load_dotenv
from pathlib import Path

# Load environment variables from .env file in the project root or backend directory
# Try project root first, then backend directory
project_root = Path(__file__).parent.parent
backend_dir = Path(__file__).parent

env_paths = [
    project_root / ".env",
    backend_dir / ".env"
]

for env_path in env_paths:
    if env_path.exists():
        load_dotenv(env_path)
        print(f"✅ Loaded environment from: {env_path}")
        break
else:
    # Fallback to system environment variables
    load_dotenv()
    print("📝 Using system environment variables")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not OPENAI_API_KEY:
    print("❌ OPENAI_API_KEY not found!")
    print("💡 Create a .env file with: OPENAI_API_KEY=your_key_here")
    print("📄 Or copy env.example to .env and fill in your key")
    raise ValueError("OPENAI_API_KEY is required. Create a .env file or set environment variable.")
