"""
NQB — ML confidence model

Uses a Logistic Regression (primary) and Random Forest (secondary) trained on
the bot's own completed trade history to estimate the probability that a setup
will hit its target before its stop.

⚠️  The output is a MODEL ESTIMATE, not a guaranteed probability.
    It is only as good as the historical data it was trained on.
    Do not use it as a substitute for your own analysis.

Minimum 30 completed trades required for any predictions.
"""
from __future__ import annotations
import json
import os
import pickle
import time
from dataclasses import dataclass
from typing import Any

import numpy as np

import database as db

MIN_TRADES_TO_TRAIN = 30
MODEL_PATH = os.path.join(os.path.dirname(__file__), "nqb_model.pkl")
_CACHE_TTL = 3600  # retrain at most once per hour

_model_cache: tuple[float, Any] = (0.0, None)  # (timestamp, fitted_model)

_SESSION_ORDER = ["NY Open", "Lunch Chop", "Power Hour", "After Hours", "Overnight / Pre-Market"]
_TF_ORDER      = ["5-min  (Scalp)", "1-Hour (Swing)", "Daily  (Trend)"]
_GRADE_ORDER   = ["A+", "A", "B", "C", ""]
_INDICATORS    = ["trend_ema", "ema_stack", "macd", "rsi", "bb",
                  "stoch_rsi", "vwap", "rel_volume"]


@dataclass
class ModelPrediction:
    confidence: float        # 0.0 – 1.0
    model_type: str          # "LogisticRegression" | "RandomForest"
    n_train: int
    label: str               # "Model estimate (not guaranteed)"
    features_available: bool


# ── Feature engineering ───────────────────────────────────────────────────────

def _extract_features(trade: dict) -> np.ndarray | None:
    """Convert a DB row to a fixed-length feature vector."""
    try:
        votes = json.loads(trade.get("indicator_votes") or "[]")
    except Exception:
        votes = []

    vote_map = {v["name"]: v for v in votes}

    feats = []

    # 1. Per-indicator net strength (-1 bear … +1 bull), signed by direction
    direction_sign = 1.0 if trade.get("direction") == "LONG" else -1.0
    for ind in _INDICATORS:
        v = vote_map.get(ind)
        if v:
            raw_strength = v["strength"]
            if v["direction"] == "BULL":
                feats.append(direction_sign * raw_strength)
            elif v["direction"] == "BEAR":
                feats.append(-direction_sign * raw_strength)
            else:
                feats.append(0.0)
        else:
            feats.append(0.0)

    # 2. Confluence score (0–100 → 0–1)
    feats.append(float(trade.get("confluence_score") or 0) / 100.0)

    # 3. R:R ratio (clipped)
    feats.append(min(float(trade.get("rr") or 0), 10.0) / 10.0)

    # 4. MTF confirmed
    feats.append(1.0 if trade.get("mtf_confirmed") else 0.0)

    # 5. Session (ordinal)
    sess = trade.get("session") or ""
    feats.append(_SESSION_ORDER.index(sess) / max(len(_SESSION_ORDER) - 1, 1)
                 if sess in _SESSION_ORDER else 0.5)

    # 6. Timeframe (ordinal)
    tf = trade.get("timeframe") or ""
    feats.append(_TF_ORDER.index(tf) / max(len(_TF_ORDER) - 1, 1)
                 if tf in _TF_ORDER else 0.5)

    # 7. Grade (ordinal: A+ best = 0, C worst = 1)
    grade = trade.get("grade") or ""
    feats.append(_GRADE_ORDER.index(grade) / max(len(_GRADE_ORDER) - 1, 1)
                 if grade in _GRADE_ORDER else 0.5)

    return np.array(feats, dtype=np.float32)


def _prepare_dataset(trades: list[dict]) -> tuple[np.ndarray, np.ndarray] | None:
    X, y = [], []
    for t in trades:
        if t.get("outcome") not in ("WIN", "LOSS"):
            continue
        fv = _extract_features(t)
        if fv is None:
            continue
        X.append(fv)
        y.append(1 if t["outcome"] == "WIN" else 0)
    if len(X) < MIN_TRADES_TO_TRAIN:
        return None
    return np.array(X), np.array(y)


# ── Training ──────────────────────────────────────────────────────────────────

def _train(X: np.ndarray, y: np.ndarray) -> tuple[Any, str]:
    """Train LR + RF, return the better-CV scorer."""
    from sklearn.linear_model import LogisticRegression
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.model_selection import cross_val_score
    from sklearn.preprocessing import StandardScaler
    from sklearn.pipeline import Pipeline

    lr = Pipeline([
        ("scaler", StandardScaler()),
        ("clf",    LogisticRegression(C=0.5, max_iter=1000, class_weight="balanced")),
    ])
    rf = RandomForestClassifier(
        n_estimators=50, max_depth=4, min_samples_leaf=4,
        class_weight="balanced", random_state=42,
    )

    n_splits = min(5, len(y) // 5)
    if n_splits < 2:
        n_splits = 2

    try:
        lr_cv = cross_val_score(lr, X, y, cv=n_splits, scoring="roc_auc").mean()
        rf_cv = cross_val_score(rf, X, y, cv=n_splits, scoring="roc_auc").mean()
    except Exception:
        lr_cv = 0.0
        rf_cv = 0.0

    if rf_cv >= lr_cv:
        rf.fit(X, y)
        return rf, "RandomForest"
    else:
        lr.fit(X, y)
        return lr, "LogisticRegression"


def train_and_save() -> dict:
    """Train on all completed trades and save model to disk. Returns status dict."""
    trades  = db.get_completed_trades()
    dataset = _prepare_dataset(trades)
    if dataset is None:
        return {"status": "skipped",
                "reason": f"Need {MIN_TRADES_TO_TRAIN} completed trades, "
                           f"have {len(trades)}"}

    X, y = dataset
    model, model_type = _train(X, y)

    with open(MODEL_PATH, "wb") as f:
        pickle.dump({"model": model, "type": model_type, "n_train": len(y)}, f)

    global _model_cache
    _model_cache = (time.time(), {"model": model, "type": model_type, "n_train": len(y)})

    wins = int(y.sum())
    return {
        "status":     "trained",
        "model_type": model_type,
        "n_train":    len(y),
        "win_rate":   round(wins / len(y) * 100, 1),
    }


def _load_model() -> dict | None:
    global _model_cache
    if time.time() - _model_cache[0] < _CACHE_TTL and _model_cache[1]:
        return _model_cache[1]
    if os.path.exists(MODEL_PATH):
        try:
            with open(MODEL_PATH, "rb") as f:
                pkg = pickle.load(f)
            _model_cache = (time.time(), pkg)
            return pkg
        except Exception:
            pass
    return None


# ── Prediction ────────────────────────────────────────────────────────────────

def predict(sig, session: str = "") -> ModelPrediction:
    """
    Predict the probability that sig hits its target before its stop.
    Returns a ModelPrediction with a confidence score and disclaimer label.
    sig: TradeSignal object (from signals.py)
    """
    # Build a synthetic trade-like dict from the signal
    trade_dict = {
        "direction":        "LONG" if "BUY" in sig.signal else "SHORT",
        "confluence_score": max(sig.bull_score, sig.bear_score),
        "rr":               sig.risk_reward,
        "mtf_confirmed":    getattr(sig, "mtf_confirmed", False),
        "session":          session,
        "timeframe":        sig.timeframe_label,
        "grade":            getattr(sig, "grade", ""),
        "indicator_votes":  json.dumps([
            {"name": v.name, "direction": v.direction,
             "strength": v.strength, "note": v.note}
            for v in sig.votes
        ]),
    }

    pkg = _load_model()
    if pkg is None:
        # Attempt auto-train if enough data exists
        result = train_and_save()
        if result.get("status") != "trained":
            return ModelPrediction(
                confidence=0.0, model_type="none", n_train=0,
                label="Insufficient data for ML model", features_available=False,
            )
        pkg = _load_model()

    fv = _extract_features(trade_dict)
    if fv is None:
        return ModelPrediction(
            confidence=0.0, model_type="none", n_train=0,
            label="Feature extraction failed", features_available=False,
        )

    model     = pkg["model"]
    mtype     = pkg.get("type", "Model")
    n_train   = pkg.get("n_train", 0)

    try:
        prob = model.predict_proba(fv.reshape(1, -1))[0][1]
    except Exception:
        prob = 0.5

    return ModelPrediction(
        confidence=round(float(prob), 3),
        model_type=mtype,
        n_train=n_train,
        label="Model estimate — not a guaranteed probability",
        features_available=True,
    )
