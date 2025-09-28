import pandas as pd
import numpy as np
from typing import Dict, List, Any, Optional
import json
from openai import OpenAI
from config import OPENAI_API_KEY

class DataAnalyzer:
    def __init__(self):
        self.client = OpenAI(api_key=OPENAI_API_KEY)
    
    def analyze_csv(self, file_path: str) -> Dict[str, Any]:
        """
        Analyze CSV file using smart sampling for large files
        """
        try:
            print(f"📊 [DataAnalyzer] Starting analysis of file: {file_path}")

            # Get file info and determine strategy
            file_info = self._get_file_info(file_path)
            print(f"📄 [DataAnalyzer] File info: {file_info['rows']:,} rows, {file_info['size_mb']:.1f}MB")

            # Use smart sampling for large files
            if file_info['rows'] > 10000 or file_info['size_mb'] > 5:
                print(f"🧠 [DataAnalyzer] Using smart sampling strategy for large file")
                return self._analyze_large_csv(file_path, file_info)
            else:
                print(f"📋 [DataAnalyzer] Using standard analysis for small file")
                return self._analyze_small_csv(file_path)

        except Exception as e:
            print(f"❌ [DataAnalyzer] Error during analysis: {e}")
            return {
                "success": False,
                "error": str(e)
            }

    def _get_file_info(self, file_path: str) -> Dict[str, Any]:
        """
        Efficiently get file information without loading entire file
        """
        import os

        file_size = os.path.getsize(file_path)
        size_mb = file_size / (1024 * 1024)

        # Estimate row count by reading a small sample
        try:
            sample_df = pd.read_csv(file_path, nrows=1000)
            sample_size = len(str(sample_df.to_csv(index=False)).encode('utf-8'))
            estimated_rows = max(1000, int(file_size / sample_size * 1000))
        except:
            estimated_rows = 10000  # Default estimate

        return {
            'size_bytes': file_size,
            'size_mb': size_mb,
            'rows': estimated_rows
        }

    def _analyze_large_csv(self, file_path: str, file_info: Dict) -> Dict[str, Any]:
        """
        Analyze large CSV files using smart sampling
        """
        print(f"🎯 [DataAnalyzer] Implementing smart sampling strategy...")

        # Step 1: Read header and first few rows to understand structure
        header_df = pd.read_csv(file_path, nrows=100)
        print(f"📋 [DataAnalyzer] Read header and first 100 rows. Columns: {list(header_df.columns)}")

        # Step 2: Get strategic samples from different parts of the file
        samples = self._get_strategic_samples(file_path, file_info)

        # Step 3: Combine samples for analysis
        combined_df = pd.concat([header_df] + samples, ignore_index=True).drop_duplicates()
        print(f"📊 [DataAnalyzer] Combined sample size: {len(combined_df)} rows")

        # Step 4: Analyze the sample
        data_info = self._get_data_info(combined_df, original_size=file_info['rows'])

        # Step 5: Get AI recommendation based on sample
        ai_recommendation = self._get_ai_recommendation(combined_df, data_info)

        # Step 6: Process FULL dataset for visualization (user requirement)
        print(f"🎯 [DataAnalyzer] Processing full dataset for visualization...")
        full_processed_data = self._process_full_dataset_for_chart(file_path, ai_recommendation)

        # Also keep sample for debugging/fallback
        sample_processed_data = self._process_data_for_chart(combined_df, ai_recommendation)

        # Clean all data for JSON serialization
        clean_data = {
            "success": True,
            "data_info": self._clean_for_json(data_info),
            "recommendation": self._clean_for_json(ai_recommendation),
            "processed_data": self._clean_for_json(full_processed_data),  # Full dataset
            "sample_data": self._clean_for_json(sample_processed_data),   # Sample for debugging
            "raw_data": self._clean_for_json(combined_df.to_dict('records')[:100]),
            "sampling_info": {
                "original_rows": file_info['rows'],
                "sample_rows": len(combined_df),
                "full_processed_rows": len(full_processed_data),
                "file_size_mb": file_info['size_mb']
            }
        }
        return clean_data

    def _get_strategic_samples(self, file_path: str, file_info: Dict) -> List[pd.DataFrame]:
        """
        Get strategic samples optimized for different data types including time series
        """
        samples = []
        sample_size = 500  # Sample size for each section

        try:
            # Total lines estimate
            total_rows = file_info['rows']

            # For time series data, we need better temporal distribution
            # Sample at regular intervals throughout the file
            num_samples = min(5, max(3, total_rows // 10000))  # 3-5 samples depending on size
            interval = total_rows // (num_samples + 1)

            print(f"📍 [DataAnalyzer] Using {num_samples} strategically spaced samples")

            for i in range(1, num_samples + 1):
                try:
                    skip_rows = min(total_rows - sample_size - 1, i * interval)
                    if skip_rows > 0:
                        sample_df = pd.read_csv(file_path, skiprows=range(1, skip_rows + 1), nrows=sample_size)
                        if not sample_df.empty:
                            samples.append(sample_df)
                            print(f"📍 [DataAnalyzer] Sampled {len(sample_df)} rows from position {skip_rows:,}")
                except Exception as sample_error:
                    print(f"⚠️ [DataAnalyzer] Failed to get sample {i}: {sample_error}")
                    continue

            # Always try to get a sample from the end for completeness
            if total_rows > 2000:
                try:
                    end_skip = max(0, total_rows - sample_size - 100)
                    end_df = pd.read_csv(file_path, skiprows=range(1, end_skip + 1), nrows=sample_size)
                    if not end_df.empty:
                        samples.append(end_df)
                        print(f"📍 [DataAnalyzer] Sampled {len(end_df)} rows from end")
                except Exception as end_error:
                    print(f"⚠️ [DataAnalyzer] Failed to get end sample: {end_error}")

        except Exception as e:
            print(f"⚠️ [DataAnalyzer] Could not get strategic samples: {e}")

        return samples

    def _analyze_small_csv(self, file_path: str) -> Dict[str, Any]:
        """
        Standard analysis for small CSV files
        """
        df = self._read_csv_robust(file_path)
        data_info = self._get_data_info(df)
        ai_recommendation = self._get_ai_recommendation(df, data_info)
        processed_data = self._process_data_for_chart(df, ai_recommendation)

        # Clean all data for JSON serialization
        clean_data = {
            "success": True,
            "data_info": self._clean_for_json(data_info),
            "recommendation": self._clean_for_json(ai_recommendation),
            "processed_data": self._clean_for_json(processed_data),
            "raw_data": self._clean_for_json(df.to_dict('records')[:100])
        }
        return clean_data

    def _read_csv_robust(self, file_path: str) -> pd.DataFrame:
        """
        Robustly read CSV files with various encodings and separators
        """
        encodings = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']
        separators = [',', ';', '\t', '|']
        
        for encoding in encodings:
            for sep in separators:
                try:
                    df = pd.read_csv(file_path, encoding=encoding, sep=sep)
                    if len(df.columns) > 1:  # Valid if multiple columns
                        return df
                except:
                    continue
        
        # Fallback
        return pd.read_csv(file_path)
    
    def _get_data_info(self, df: pd.DataFrame, original_size: Optional[int] = None) -> Dict[str, Any]:
        """
        Extract basic information about the dataset
        """
        # Use original size if provided (for sampled data), otherwise use actual dataframe shape
        shape = [original_size or df.shape[0], df.shape[1]]

        info = {
            "shape": shape,
            "columns": list(df.columns),
            "dtypes": df.dtypes.astype(str).to_dict(),
            "missing_values": df.isnull().sum().to_dict(),
            "numeric_columns": list(df.select_dtypes(include=[np.number]).columns),
            "categorical_columns": list(df.select_dtypes(include=['object', 'category']).columns),
            "datetime_columns": [],
            "sample_data": {},
            "is_sampled": original_size is not None
        }
        
        # Detect datetime columns (more robust detection)
        for col in df.columns:
            try:
                # Only consider as datetime if it's not purely numeric
                if col not in info["numeric_columns"]:
                    sample_values = df[col].dropna().head(10)
                    # Try to parse as datetime
                    parsed_dates = pd.to_datetime(sample_values, errors='coerce')
                    # Only count as datetime if most values are successfully parsed AND not purely numeric
                    valid_dates = parsed_dates.notna().sum()
                    if valid_dates >= len(sample_values) * 0.7:  # 70% success rate
                        info["datetime_columns"].append(col)
            except:
                pass
        
        # Get sample data for each column
        for col in df.columns:
            sample_values = df[col].dropna().head(5).tolist()
            info["sample_data"][col] = sample_values
        
        return info

    def _get_data_insights(self, df: pd.DataFrame) -> Dict[str, Any]:
        """
        Get key insights about the data for better AI recommendations
        """
        insights = {}

        try:
            # Numeric column insights
            numeric_cols = df.select_dtypes(include=[np.number]).columns
            if len(numeric_cols) > 0:
                value_ranges = {}
                for col in numeric_cols[:3]:
                    col_min = df[col].min()
                    col_max = df[col].max()
                    # Handle NaN values - convert to None for JSON serialization
                    value_ranges[col] = {
                        "min": None if pd.isna(col_min) else float(col_min),
                        "max": None if pd.isna(col_max) else float(col_max)
                    }

                insights["numeric_patterns"] = {
                    "has_time_series_pattern": any(col.lower() in ['date', 'time', 'year', 'month'] for col in df.columns),
                    "value_ranges": value_ranges
                }

            # Categorical insights
            categorical_cols = df.select_dtypes(include=['object']).columns
            if len(categorical_cols) > 0:
                insights["categorical_patterns"] = {
                    col: {
                        "unique_values": int(df[col].nunique()),
                        "top_values": df[col].value_counts().head(3).to_dict()
                    } for col in categorical_cols[:3]
                }

            # Data characteristics
            missing_count = df.isnull().sum().sum()
            total_cells = len(df) * len(df.columns)
            missing_ratio = missing_count / total_cells if total_cells > 0 else 0

            insights["data_characteristics"] = {
                "total_rows": len(df),
                "missing_data_ratio": float(missing_ratio),
                "primarily_numeric": len(numeric_cols) > len(categorical_cols)
            }

        except Exception as e:
            print(f"⚠️ [DataAnalyzer] Could not generate insights: {e}")
            insights = {"error": "Could not analyze data patterns"}

        return insights

    def _clean_for_json(self, data: Any) -> Any:
        """
        Recursively clean data to remove NaN values that can't be JSON serialized
        """
        if isinstance(data, dict):
            return {k: self._clean_for_json(v) for k, v in data.items()}
        elif isinstance(data, list):
            return [self._clean_for_json(item) for item in data]
        elif pd.isna(data):
            return None
        elif isinstance(data, (np.integer, np.floating)):
            if pd.isna(data) or np.isinf(data):
                return None
            return float(data) if isinstance(data, np.floating) else int(data)
        elif isinstance(data, float):
            if pd.isna(data) or np.isinf(data):
                return None
            return data
        elif data is np.nan:
            return None
        else:
            return data

    def _get_ai_recommendation(self, df: pd.DataFrame, data_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Use OpenAI to recommend chart type and data mappings (optimized for large files)
        """
        # Create a concise, optimized representation for AI analysis
        data_summary = {
            "columns": data_info["columns"],
            "dtypes": data_info["dtypes"],
            "numeric_columns": data_info["numeric_columns"],
            "categorical_columns": data_info["categorical_columns"],
            "datetime_columns": data_info["datetime_columns"],
            "shape": data_info["shape"],
            "is_large_dataset": data_info.get("is_sampled", False),
            "sample_data": {col: data_info["sample_data"][col][:3] for col in data_info["sample_data"]}  # Limit samples
        }

        # Add data distribution insights for better recommendations
        if len(df) > 0:
            data_summary["insights"] = self._get_data_insights(df)

        prompt = f"""
        Analyze this dataset and recommend the best visualization approach.

        IMPORTANT: This may be a large dataset ({data_summary['shape'][0]:,} rows) analyzed using smart sampling.

        Data Summary:
        {json.dumps(data_summary, indent=2)}

        Available chart types:
        - line: For time series or continuous data trends
        - bar: For categorical comparisons
        - scatter: For correlation between two numeric variables
        - pie: For proportional data (parts of a whole)
        - histogram: For distribution of a single numeric variable
        - box: For distribution statistics and outliers
        - heatmap: For correlation matrices or 2D data intensity

        Please respond with a JSON object containing:
        {{
            "chart_type": "one of the available chart types",
            "x_axis": "column name for x-axis",
            "y_axis": "column name for y-axis (null if not applicable)",
            "z_axis": "column name for z-axis/color/size (null if not applicable)",
            "title": "descriptive chart title",
            "x_label": "x-axis label",
            "y_label": "y-axis label (null if not applicable)",
            "reasoning": "brief explanation of why this chart type was chosen",
            "data_processing": {{
                "aggregate": "sum/mean/count/none - how to aggregate data if needed",
                "group_by": "column to group by (null if not applicable)",
                "sort_by": "column to sort by (null if not applicable)",
                "limit": "number of top/bottom items to show (null for all)"
            }}
        }}

        Choose the most appropriate visualization that will provide the most insight into this data.
        """
        
        try:
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a data visualization expert. Respond only with valid JSON."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.1
            )
            
            recommendation = json.loads(response.choices[0].message.content)

            # Validate recommendation to prevent same-axis assignments
            recommendation = self._validate_recommendation(recommendation, data_info)
            return recommendation
            
        except Exception as e:
            # Fallback recommendation
            return self._get_fallback_recommendation(data_info)

    def _validate_recommendation(self, recommendation: Dict[str, Any], data_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate and fix common issues in AI recommendations
        """
        x_axis = recommendation.get("x_axis")
        y_axis = recommendation.get("y_axis")

        # Fix same-axis assignments
        if x_axis and y_axis and x_axis == y_axis:
            print(f"⚠️ [DataAnalyzer] Detected same-axis assignment: {x_axis}. Fixing...")

            # Try to find a better combination
            numeric_cols = data_info["numeric_columns"]
            categorical_cols = data_info["categorical_columns"]
            datetime_cols = data_info["datetime_columns"]

            # If we have categorical and numeric, use that combo
            if categorical_cols and numeric_cols:
                recommendation["x_axis"] = categorical_cols[0]
                recommendation["y_axis"] = numeric_cols[0]
                recommendation["chart_type"] = "bar"
                recommendation["title"] = f"{numeric_cols[0]} by {categorical_cols[0]}"
                recommendation["x_label"] = categorical_cols[0]
                recommendation["y_label"] = numeric_cols[0]
                recommendation["reasoning"] = "Categorical vs numeric comparison"
                if "data_processing" not in recommendation:
                    recommendation["data_processing"] = {}
                recommendation["data_processing"]["group_by"] = categorical_cols[0]
                recommendation["data_processing"]["aggregate"] = "sum"

            # If we have datetime and numeric, use time series
            elif datetime_cols and numeric_cols:
                recommendation["x_axis"] = datetime_cols[0]
                recommendation["y_axis"] = numeric_cols[0]
                recommendation["chart_type"] = "line"
                recommendation["title"] = f"{numeric_cols[0]} over {datetime_cols[0]}"
                recommendation["x_label"] = datetime_cols[0]
                recommendation["y_label"] = numeric_cols[0]
                recommendation["reasoning"] = "Time series visualization"

            # If we have multiple numeric columns, use scatter plot
            elif len(numeric_cols) >= 2:
                recommendation["x_axis"] = numeric_cols[0]
                recommendation["y_axis"] = numeric_cols[1]
                recommendation["chart_type"] = "scatter"
                recommendation["title"] = f"{numeric_cols[1]} vs {numeric_cols[0]}"
                recommendation["x_label"] = numeric_cols[0]
                recommendation["y_label"] = numeric_cols[1]
                recommendation["reasoning"] = "Correlation analysis"

            print(f"✅ [DataAnalyzer] Fixed to: {recommendation['x_axis']} vs {recommendation['y_axis']}")

        return recommendation

    def _get_fallback_recommendation(self, data_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Provide a fallback recommendation if AI fails
        """
        numeric_cols = data_info["numeric_columns"]
        categorical_cols = data_info["categorical_columns"]
        datetime_cols = data_info["datetime_columns"]
        
        # Simple heuristics
        if len(datetime_cols) > 0 and len(numeric_cols) > 0:
            return {
                "chart_type": "line",
                "x_axis": datetime_cols[0],
                "y_axis": numeric_cols[0],
                "z_axis": None,
                "title": f"{numeric_cols[0]} over {datetime_cols[0]}",
                "x_label": datetime_cols[0],
                "y_label": numeric_cols[0],
                "reasoning": "Time series data detected",
                "data_processing": {"aggregate": "none", "group_by": None, "sort_by": datetime_cols[0], "limit": None}
            }
        elif len(numeric_cols) >= 2:
            return {
                "chart_type": "scatter",
                "x_axis": numeric_cols[0],
                "y_axis": numeric_cols[1],
                "z_axis": None,
                "title": f"{numeric_cols[1]} vs {numeric_cols[0]}",
                "x_label": numeric_cols[0],
                "y_label": numeric_cols[1],
                "reasoning": "Two numeric variables for correlation analysis",
                "data_processing": {"aggregate": "none", "group_by": None, "sort_by": None, "limit": None}
            }
        elif len(categorical_cols) > 0 and len(numeric_cols) > 0:
            return {
                "chart_type": "bar",
                "x_axis": categorical_cols[0],
                "y_axis": numeric_cols[0],
                "z_axis": None,
                "title": f"{numeric_cols[0]} by {categorical_cols[0]}",
                "x_label": categorical_cols[0],
                "y_label": numeric_cols[0],
                "reasoning": "Categorical vs numeric data",
                "data_processing": {"aggregate": "sum", "group_by": categorical_cols[0], "sort_by": None, "limit": 20}
            }
        else:
            # Default to first two columns
            cols = data_info["columns"]
            return {
                "chart_type": "bar",
                "x_axis": cols[0] if len(cols) > 0 else None,
                "y_axis": cols[1] if len(cols) > 1 else None,
                "z_axis": None,
                "title": "Data Visualization",
                "x_label": cols[0] if len(cols) > 0 else "X",
                "y_label": cols[1] if len(cols) > 1 else "Y",
                "reasoning": "Default visualization",
                "data_processing": {"aggregate": "none", "group_by": None, "sort_by": None, "limit": None}
            }

    def _process_full_dataset_for_chart(self, file_path: str, recommendation: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Process the FULL dataset for visualization (not just samples)
        """
        try:
            print(f"📊 [DataAnalyzer] Loading full dataset for chart processing...")

            # Read the full dataset efficiently
            df = self._read_csv_robust(file_path)
            print(f"📊 [DataAnalyzer] Loaded {len(df):,} rows for full processing")

            # Apply the same processing logic as sample, but on full dataset
            processed_df = df.copy()

            # Apply data processing steps
            processing = recommendation.get("data_processing", {})

            # Group by if specified
            if processing.get("group_by"):
                group_col = processing["group_by"]
                agg_method = processing.get("aggregate", "sum")

                if recommendation["y_axis"] and agg_method != "none":
                    if agg_method == "sum":
                        processed_df = processed_df.groupby(group_col)[recommendation["y_axis"]].sum().reset_index()
                    elif agg_method == "mean":
                        processed_df = processed_df.groupby(group_col)[recommendation["y_axis"]].mean().reset_index()
                    elif agg_method == "count":
                        processed_df = processed_df.groupby(group_col).size().reset_index(name=recommendation["y_axis"])

            # Sort if specified
            if processing.get("sort_by") and processing["sort_by"] in processed_df.columns:
                processed_df = processed_df.sort_values(processing["sort_by"])

            # For visualization, limit to reasonable number of points
            # But much higher than sample limit
            max_chart_points = 10000  # Reasonable for most chart libraries
            if len(processed_df) > max_chart_points:
                print(f"📊 [DataAnalyzer] Limiting to {max_chart_points:,} points for chart performance")
                # For time series, sample evenly across the data
                if recommendation.get("x_axis") in processed_df.columns:
                    step = len(processed_df) // max_chart_points
                    processed_df = processed_df.iloc[::step]
                else:
                    processed_df = processed_df.head(max_chart_points)

            print(f"📊 [DataAnalyzer] Final processed dataset: {len(processed_df):,} rows")

            # Convert to records for JSON serialization
            return self._clean_for_json(processed_df.to_dict('records'))

        except Exception as e:
            print(f"❌ [DataAnalyzer] Error processing full dataset: {e}")
            # Fallback to sample processing
            return self._process_data_for_chart_fallback(file_path, recommendation)

    def _process_data_for_chart_fallback(self, file_path: str, recommendation: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Fallback method if full dataset processing fails
        """
        try:
            # Read a larger sample for fallback
            df = pd.read_csv(file_path, nrows=5000)
            return self._process_data_for_chart(df, recommendation)
        except Exception as e:
            print(f"❌ [DataAnalyzer] Fallback processing also failed: {e}")
            return []

    def _process_data_for_chart(self, df: pd.DataFrame, recommendation: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Process the data according to the AI recommendation
        """
        try:
            processed_df = df.copy()
            
            # Apply data processing steps
            processing = recommendation.get("data_processing", {})
            
            # Group by if specified
            if processing.get("group_by"):
                group_col = processing["group_by"]
                agg_method = processing.get("aggregate", "sum")
                
                if recommendation["y_axis"] and agg_method != "none":
                    if agg_method == "sum":
                        processed_df = processed_df.groupby(group_col)[recommendation["y_axis"]].sum().reset_index()
                    elif agg_method == "mean":
                        processed_df = processed_df.groupby(group_col)[recommendation["y_axis"]].mean().reset_index()
                    elif agg_method == "count":
                        processed_df = processed_df.groupby(group_col).size().reset_index(name=recommendation["y_axis"])
            
            # Sort if specified
            if processing.get("sort_by") and processing["sort_by"] in processed_df.columns:
                processed_df = processed_df.sort_values(processing["sort_by"])
            
            # Limit if specified
            if processing.get("limit"):
                processed_df = processed_df.head(processing["limit"])
            
            # Convert to records for JSON serialization
            return self._clean_for_json(processed_df.to_dict('records'))

        except Exception as e:
            # Return original data if processing fails
            return self._clean_for_json(df.to_dict('records')[:100])
