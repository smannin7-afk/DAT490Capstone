import argparse
from pathlib import Path
import pandas as pd
import numpy as np

REQUIRED_COLUMNS = [
    "action_taken",
    "state_code",
    "applicant_sex",
    "loan_type",
    "loan_purpose",
    "lien_status",
    "loan_amount",
    "loan_to_value_ratio",
    "property_value",
    "occupancy_type",
    "income",
    "debt_to_income_ratio",
    "applicant_age",
]

FINAL_COLUMNS = [
    "state_code",
    "applicant_sex",
    "loan_type",
    "loan_purpose",
    "lien_status",
    "loan_amount",
    "loan_to_value_ratio",
    "property_value",
    "occupancy_type",
    "income",
    "debt_to_income_ratio",
    "applicant_age",
    "target",
]

NUMERIC_COLUMNS = [
    "loan_amount",
    "loan_to_value_ratio",
    "property_value",
    "income",
]

TARGET_ROW_COUNT = 332_301

DTYPES = {
    "action_taken": "string",
    "state_code": "string",
    "applicant_sex": "string",
    "loan_type": "string",
    "loan_purpose": "string",
    "lien_status": "string",
    "loan_amount": "string",
    "loan_to_value_ratio": "string",
    "property_value": "string",
    "occupancy_type": "string",
    "income": "string",
    "debt_to_income_ratio": "string",
    "applicant_age": "string",
}

def clean_numeric(series):
    return pd.to_numeric(
        series.astype("string")
        .str.replace(",", "", regex=False)
        .str.replace("$", "", regex=False)
        .str.replace("%", "", regex=False)
        .str.strip(),
        errors="coerce",
    )

def load_filtered_chunks(input_path, chunksize):
    chunks = []
    total_rows = 0
    kept_action_rows = 0

    for chunk in pd.read_csv(
        input_path,
        usecols=lambda col: col in REQUIRED_COLUMNS,
        dtype=DTYPES,
        chunksize=chunksize,
        low_memory=False,
    ):
        total_rows += len(chunk)

        missing_columns = sorted(set(REQUIRED_COLUMNS) - set(chunk.columns))
        if missing_columns:
            raise ValueError(f"Missing required columns from input file: {missing_columns}")

        chunk["action_taken_num"] = pd.to_numeric(chunk["action_taken"], errors="coerce")
        chunk = chunk[chunk["action_taken_num"].isin([1, 2, 3])].copy()
        kept_action_rows += len(chunk)

        if chunk.empty:
            continue

        for col in NUMERIC_COLUMNS:
            chunk[col] = clean_numeric(chunk[col])

        chunk = chunk.dropna(subset=["income", "loan_amount"]).copy()

        chunk["target"] = np.where(chunk["action_taken_num"].isin([1, 2]), 1, 0).astype("int8")
        chunk = chunk[FINAL_COLUMNS]

        chunks.append(chunk)

    if not chunks:
        raise ValueError("No rows remained after filtering action_taken and required nonmissing fields.")

    data = pd.concat(chunks, ignore_index=True)

    return data, total_rows, kept_action_rows

def winsorize_99(data):
    result = data.copy()
    caps = {}

    for col in NUMERIC_COLUMNS:
        cap = result[col].quantile(0.99)
        caps[col] = cap
        result[col] = result[col].clip(upper=cap)

    return result, caps

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", default="data/processed/hmda_2023_analytical.parquet")
    parser.add_argument("--chunksize", type=int, default=250000)
    parser.add_argument("--expected-rows", type=int, default=TARGET_ROW_COUNT)
    parser.add_argument("--allow-row-count-mismatch", action="store_true")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        raise FileNotFoundError(f"Input file does not exist: {input_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)

    data, total_rows, kept_action_rows = load_filtered_chunks(input_path, args.chunksize)
    row_count_before_winsor = len(data)

    data, caps = winsorize_99(data)

    print(f"Raw rows read: {total_rows:,}")
    print(f"Rows after action_taken in 1, 2, 3: {kept_action_rows:,}")
    print(f"Rows after dropping missing income or loan_amount: {row_count_before_winsor:,}")
    print("99th-percentile winsorization caps:")
    for col, cap in caps.items():
        print(f"  {col}: {cap}")

    if row_count_before_winsor != args.expected_rows:
        message = (
            f"Expected {args.expected_rows:,} rows, but produced {row_count_before_winsor:,}. "
            "Check whether the same HMDA extract and filters from the report were used."
        )
        if args.allow_row_count_mismatch:
            print(f"WARNING: {message}")
        else:
            raise ValueError(message)

    data.to_parquet(output_path, index=False)

    print(f"Saved analytical dataset to: {output_path}")
    print(f"Final columns: {list(data.columns)}")
    print(f"Final shape: {data.shape}")

if __name__ == "__main__":
    main()
