"""
NQB Trading Bot — Configuration
"""
import os
from dotenv import load_dotenv

load_dotenv()

TICKER = "NQ=F"

# ── Timeframes ────────────────────────────────────────────────────────────────
TIMEFRAMES = {
    "scalp":  {"interval": "5m",  "period": "5d",  "label": "5-min  (Scalp)",  "htf": "swing"},
    "swing":  {"interval": "1h",  "period": "60d", "label": "1-Hour (Swing)",  "htf": "trend"},
    "trend":  {"interval": "1d",  "period": "1y",  "label": "Daily  (Trend)",  "htf": None},
}

# ── Indicator settings ────────────────────────────────────────────────────────
EMA_FAST   = 9
EMA_MID    = 21
EMA_SLOW   = 50
EMA_TREND  = 200

RSI_PERIOD       = 14
RSI_OVERBOUGHT   = 70
RSI_OVERSOLD     = 30

MACD_FAST        = 12
MACD_SLOW        = 26
MACD_SIGNAL      = 9

BB_PERIOD        = 20
BB_STD           = 2

ATR_PERIOD       = 14

STOCH_K          = 14
STOCH_D          = 3
STOCH_SMOOTH     = 3

VWAP_ENABLED     = True

# ── Signal scoring thresholds ─────────────────────────────────────────────────
STRONG_BUY_THRESHOLD  = 70
BUY_THRESHOLD         = 50
SELL_THRESHOLD        = 50
STRONG_SELL_THRESHOLD = 70

# ── Risk / position sizing ────────────────────────────────────────────────────
ATR_STOP_MULTIPLIER   = 1.5
ATR_TARGET_MULTIPLIER = 3.0
RISK_REWARD_MIN       = 2.5

# ── Scan interval (seconds) ───────────────────────────────────────────────────
SCAN_INTERVAL = 300

# ── Market sessions (America/New_York) ────────────────────────────────────────
# (hour, minute) tuples
SESSIONS = [
    ("NY Open",              (9, 30),  (11, 0),  True,  "#26a65b"),
    ("Lunch Chop",           (11, 0),  (14, 0),  False, "#c8a84b"),
    ("Power Hour",           (15, 0),  (16, 0),  True,  "#4a9eff"),
    ("After Hours",          (16, 0),  (18, 0),  False, "#6b6b8a"),
]

# ── Alert delivery (set via .env or environment variables) ────────────────────
DISCORD_WEBHOOK_URL  = os.getenv("DISCORD_WEBHOOK_URL",  "")
TELEGRAM_BOT_TOKEN   = os.getenv("TELEGRAM_BOT_TOKEN",   "")
TELEGRAM_CHAT_ID     = os.getenv("TELEGRAM_CHAT_ID",     "")
ALERT_EMAIL_FROM     = os.getenv("ALERT_EMAIL_FROM",     "")
ALERT_EMAIL_TO       = os.getenv("ALERT_EMAIL_TO",       "")
ALERT_EMAIL_PASSWORD = os.getenv("ALERT_EMAIL_PASSWORD", "")
ALERT_EMAIL_SMTP     = os.getenv("ALERT_EMAIL_SMTP",     "smtp.gmail.com")
ALERT_EMAIL_PORT     = int(os.getenv("ALERT_EMAIL_PORT", "587"))

# ── Trade journal CSV path ────────────────────────────────────────────────────
JOURNAL_CSV = os.path.join(os.path.dirname(__file__), "trade_journal.csv")

# ── Risk / position sizing defaults ──────────────────────────────────────────
DEFAULT_ACCOUNT_SIZE = 50_000.0   # USD
DEFAULT_RISK_PCT     = 1.0        # % of account per trade
DEFAULT_MAX_LOSS     = 500.0      # hard max dollar loss per trade
NQ_POINT_VALUE       = 20.0       # $20 per full point per NQ contract
MNQ_POINT_VALUE      = 2.0        # $2 per full point per MNQ (micro) contract

# ── Paper trading ─────────────────────────────────────────────────────────────
PAPER_AUTO_LOG_GRADES = ("A+", "A")   # grades that auto-open a paper trade
PAPER_MAX_OPEN_TRADES = 5             # don't open more paper trades than this

# ── ML model ─────────────────────────────────────────────────────────────────
ML_MIN_CONFIDENCE_DISPLAY = 0.0       # show badge even at low confidence
ML_RETRAIN_INTERVAL_TRADES = 10       # retrain after every N new completed trades
