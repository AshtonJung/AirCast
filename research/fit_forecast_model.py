import json
import numpy as np
import pandas as pd

SRC = "/Users/femcman/Documents/jei-pm25-episode-recovery/data/processed/cleaned_daily_data.csv"
OUT = "/tmp/aircast_forecast_model.json"
OUT_RECENT = "/tmp/aircast_recent_observations.json"

df = pd.read_csv(SRC, parse_dates=["date"])
df = df.sort_values("date").reset_index(drop=True)

# Build next-day pairs: only consecutive calendar days (date diff == 1 day),
# so we never learn/evaluate across a data gap.
df["next_date"] = df["date"].shift(-1)
df["next_pm25"] = df["pm25"].shift(-1)
df["gap_days"] = (df["next_date"] - df["date"]).dt.days

pairs = df[df["gap_days"] == 1].copy()
pairs = pairs.dropna(subset=["pm25", "wind", "precip", "next_pm25"])

# Time-based split: train through end of 2022, test 2023 onward. This avoids
# leakage (no future info used to predict the past) and evaluates the model
# on a genuine, more-recent holdout period.
train = pairs[pairs["date"] < "2023-01-01"].copy()
test = pairs[pairs["date"] >= "2023-01-01"].copy()

feature_cols = ["pm25", "wind", "precip"]
X_train = np.column_stack([np.ones(len(train)), train[feature_cols].values])
y_train = train["next_pm25"].values

# Ordinary least squares via numpy (transparent, no black-box library needed).
coef, residuals, rank, sv = np.linalg.lstsq(X_train, y_train, rcond=None)
intercept, b_pm25, b_wind, b_precip = coef

def predict(row):
    return intercept + b_pm25 * row["pm25"] + b_wind * row["wind"] + b_precip * row["precip"]

train["pred"] = train.apply(predict, axis=1)
test["pred"] = test.apply(predict, axis=1)

def mae(y_true, y_pred):
    return float(np.mean(np.abs(y_true - y_pred)))

def rmse(y_true, y_pred):
    return float(np.sqrt(np.mean((y_true - y_pred) ** 2)))

model_mae_test = mae(test["next_pm25"], test["pred"])
model_rmse_test = rmse(test["next_pm25"], test["pred"])
model_mae_train = mae(train["next_pm25"], train["pred"])
model_rmse_train = rmse(train["next_pm25"], train["pred"])

# Naive persistence baseline: predict tomorrow's PM2.5 = today's PM2.5.
baseline_pred_test = test["pm25"].values
baseline_mae_test = mae(test["next_pm25"], baseline_pred_test)
baseline_rmse_test = rmse(test["next_pm25"], baseline_pred_test)

# Empirical residuals on the test set, used for an honest (not assumed-normal)
# interval: the middle 80% of actual test-set errors.
test_residuals = (test["next_pm25"] - test["pred"]).values
lower_q, upper_q = np.percentile(test_residuals, [10, 90])

result = {
    "generated_at": pd.Timestamp.now().isoformat(),
    "source_dataset": "jei-pm25-episode-recovery/data/processed/cleaned_daily_data.csv",
    "dataset": {
        "source_name": "EPA AirData (Anaheim + Mission Viejo, Orange County, CA) PM2.5 + NOAA John Wayne Airport (USW00093184) wind/precipitation, cleaned and merged for the JEI PM2.5 Episode-Recovery study",
        "geography": "Orange County, California, USA",
        "date_range_start": pairs["date"].min().strftime("%Y-%m-%d"),
        "date_range_end": pairs["date"].max().strftime("%Y-%m-%d"),
        "n_consecutive_day_pairs": int(len(pairs)),
        "n_train_pairs": int(len(train)),
        "n_test_pairs": int(len(test)),
        "variables": ["PM2.5 (ug/m3, daily mean)", "Wind speed (m/s, daily mean)", "Precipitation (mm/day)", "Season", "Year"],
    },
    "model": {
        "model_type": "Ordinary least squares regression: next-day PM2.5 ~ today's PM2.5 (persistence) + wind + precipitation",
        "target": "Next-day daily mean PM2.5 (ug/m3)",
        "inputs": feature_cols,
        "coefficients": {
            "intercept": float(intercept),
            "pm25_today": float(b_pm25),
            "wind": float(b_wind),
            "precip": float(b_precip),
        },
        "train_date_range": [train["date"].min().strftime("%Y-%m-%d"), train["date"].max().strftime("%Y-%m-%d")],
        "test_date_range": [test["date"].min().strftime("%Y-%m-%d"), test["date"].max().strftime("%Y-%m-%d")],
    },
    "evaluation": {
        "test": {
            "model_mae": model_mae_test,
            "model_rmse": model_rmse_test,
            "baseline_persistence_mae": baseline_mae_test,
            "baseline_persistence_rmse": baseline_rmse_test,
            "n": int(len(test)),
        },
        "train": {
            "model_mae": model_mae_train,
            "model_rmse": model_rmse_train,
            "n": int(len(train)),
        },
        "empirical_residual_interval_80pct": {
            "lower": float(lower_q),
            "upper": float(upper_q),
            "description": "10th-90th percentile of (observed - predicted) next-day PM2.5 on the held-out 2023+ test set.",
        },
    },
}

with open(OUT, "w") as f:
    json.dump(result, f, indent=2)

# Bundle a real recent window (last 60 days of the full series) for demo/preview use.
recent = df.dropna(subset=["pm25"]).tail(60).copy()
recent_records = []
for _, row in recent.iterrows():
    recent_records.append({
        "date": row["date"].strftime("%Y-%m-%d"),
        "pm25": None if pd.isna(row["pm25"]) else round(float(row["pm25"]), 2),
        "wind": None if pd.isna(row["wind"]) else round(float(row["wind"]), 2),
        "precip": None if pd.isna(row["precip"]) else round(float(row["precip"]), 2),
        "season": row["season"],
    })

# Pick one real, deterministic test-set day (with a real next-day observation)
# to power a Prediction Challenge demo scenario grounded in an actual event
# rather than synthetic numbers. Choose a day with a moderately large error
# for interest, from the back half of the test period.
mid_test = test.iloc[len(test) // 2]
challenge_example = {
    "date": mid_test["date"].strftime("%Y-%m-%d"),
    "pm25_today": round(float(mid_test["pm25"]), 2),
    "wind_today": round(float(mid_test["wind"]), 2),
    "precip_today": round(float(mid_test["precip"]), 2),
    "model_forecast_next_day": round(float(mid_test["pred"]), 2),
    "observed_next_day": round(float(mid_test["next_pm25"]), 2),
}

with open(OUT_RECENT, "w") as f:
    json.dump({"recent_observations": recent_records, "challenge_example": challenge_example}, f, indent=2)

print(json.dumps(result, indent=2))
print("---CHALLENGE EXAMPLE---")
print(json.dumps(challenge_example, indent=2))
