"""Data conversion utilities for the backend."""

from __future__ import annotations

import io
from typing import Tuple

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq


def convert_to_parquet(file_content: bytes, filename: str) -> bytes:
    """Convert file content to Parquet format.

    Args:
        file_content: Raw file bytes
        filename: Original filename for format detection

    Returns:
        Parquet formatted bytes
    """
    # Read the original file format
    df = _read_file_to_dataframe(file_content, filename)

    # Convert to Parquet
    table = pa.Table.from_pandas(df)

    # Write to bytes buffer
    buffer = io.BytesIO()
    pq.write_table(table, buffer, compression="snappy")

    return buffer.getvalue()


def read_parquet_data(parquet_content: bytes) -> pd.DataFrame:
    """Read Parquet data from bytes.

    Args:
        parquet_content: Parquet file content as bytes

    Returns:
        pandas DataFrame
    """
    buffer = io.BytesIO(parquet_content)
    table = pq.read_table(buffer)
    return table.to_pandas()


def _read_file_to_dataframe(file_content: bytes, filename: str) -> pd.DataFrame:
    """Read file content into pandas DataFrame based on file extension."""
    lowered = filename.lower()

    if lowered.endswith(".csv"):
        return pd.read_csv(io.BytesIO(file_content))
    elif lowered.endswith(".tsv"):
        return pd.read_csv(io.BytesIO(file_content), sep="\t")
    elif lowered.endswith(".json"):
        try:
            return pd.read_json(io.BytesIO(file_content), lines=True)
        except ValueError:
            return pd.read_json(io.BytesIO(file_content))
    elif lowered.endswith(".parquet"):
        return read_parquet_data(file_content)
    else:
        raise ValueError(f"Unsupported file format: {filename}")


def is_parquet_file(filename: str) -> bool:
    """Check if file is already in Parquet format."""
    return filename.lower().endswith(".parquet")
