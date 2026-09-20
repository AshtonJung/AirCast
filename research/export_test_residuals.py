import json
import numpy as np
import pandas as pd

SRC = "/Users/femcman/Documents/jei-pm25-episode-recovery/data/processed/cleaned_daily_data.csv"
OUT = "/tmp/aircast_test_residuals.json"

df = pd.read_csv(SRC, parse_dates=["date"])
df = df.sort_values("date").reset_index(drop=True)
df["next_date"] = df["date"].shift(-1)
df["next_pm25"] = df["pm25"].shift(-1)
df["gap_days"] = (df["next_date"] - df["date"]).dt.days

pairs = df[df["gap_days"] == 1].copy()
pairs = pairs.dropna(subset=["pm25", "wind", "precip", "next_pm25"])

train = pairs[pairs["date"] < "2023-01-01"].copy()
test = pairs[pairs["date"] >= "2023-01-01"].copy()

feature_cols = ["pm25", "wind", "precip"]
X_train = np.column_stack([np.ones(len(train)), train[feature_cols].values])
y_train = train["next_pm25"].values
coef, *_ = np.linalg.lstsq(X_train, y_train, rcond=None)
intercept, b_pm25, b_wind, b_precip = coef

def predict(row):
    return intercept + b_pm25 * row["pm25"] + b_wind * row["wind"] + b_precip * row["precip"]

test = test.copy()
test["predicted"] = test.apply(predict, axis=1)
test["residual"] = test["next_pm25"] - test["predicted"]

records = []
for _, row in test.iterrows():
    records.append({
        "date": row["date"].strftime("%Y-%m-%d"),
        "observed": round(float(row["next_pm25"]), 2),
        "predicted": round(float(row["predicted"]), 2),
        "residual": round(float(row["residual"]), 2),
    })

with open(OUT, "w") as f:
    json.dump({"test_points": records}, f, indent=2)

print(f"Exported {len(records)} test points")
print("MAE check:", np.mean(np.abs(test["residual"])))
