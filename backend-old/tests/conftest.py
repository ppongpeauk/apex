import os
import sys
from pathlib import Path


def pytest_sessionstart(session):
    project_root = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(project_root))
    os.environ.setdefault("PYTHONPATH", str(project_root))
