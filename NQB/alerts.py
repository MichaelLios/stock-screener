"""
NQB — Alert delivery (Discord, Telegram, email)
Only fires for A and A+ grade setups to avoid noise.
Configure delivery channels via environment variables / .env file:
  DISCORD_WEBHOOK_URL
  TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID
  ALERT_EMAIL_FROM + ALERT_EMAIL_TO + ALERT_EMAIL_PASSWORD
"""
from __future__ import annotations
import smtplib
from email.mime.text import MIMEText
import requests
import config as cfg
from signals import TradeSignal


def send_if_notable(sig: TradeSignal) -> list[str]:
    """Send alerts only for A / A+ grades. Returns list of channels delivered."""
    if getattr(sig, "grade", "") not in ("A", "A+"):
        return []
    subject = f"NQB {sig.grade} Setup: {sig.signal} ({sig.timeframe_label})"
    return _deliver(_compose(sig), subject)


def _compose(sig: TradeSignal) -> str:
    direction  = "LONG"  if "BUY"  in sig.signal else "SHORT"
    grade      = getattr(sig, "grade", "")
    score      = max(sig.bull_score, sig.bear_score)
    mtf_note   = "HTF confirmed ✓" if getattr(sig, "mtf_confirmed", False) else "HTF not confirmed"
    bull_votes = [v.note for v in sig.votes if v.direction == "BULL"]
    bear_votes = [v.note for v in sig.votes if v.direction == "BEAR"]
    reasons    = "; ".join(bull_votes if "BUY" in sig.signal else bear_votes)[:250]

    return (
        f"🔔 NQB {grade} Setup — {sig.signal}\n"
        f"Direction: {direction}  |  TF: {sig.timeframe_label}\n"
        f"Entry {sig.price:,.1f}  |  Stop {sig.stop_loss:,.1f}  |  Target {sig.target:,.1f}\n"
        f"R:R {sig.risk_reward:.1f}x  |  Confluence score {score:.0f}/100  |  {mtf_note}\n"
        f"Reasons: {reasons}\n"
        f"⚠️ Not financial advice. Always backtest before trading real capital."
    )


def _deliver(msg: str, subject: str = "NQB Alert") -> list[str]:
    sent = []

    if cfg.DISCORD_WEBHOOK_URL:
        try:
            r = requests.post(cfg.DISCORD_WEBHOOK_URL,
                              json={"content": msg}, timeout=5)
            if r.status_code in (200, 204):
                sent.append("Discord")
        except Exception:
            pass

    if cfg.TELEGRAM_BOT_TOKEN and cfg.TELEGRAM_CHAT_ID:
        try:
            url = f"https://api.telegram.org/bot{cfg.TELEGRAM_BOT_TOKEN}/sendMessage"
            r = requests.post(url, json={"chat_id": cfg.TELEGRAM_CHAT_ID,
                                          "text": msg}, timeout=5)
            if r.status_code == 200:
                sent.append("Telegram")
        except Exception:
            pass

    if cfg.ALERT_EMAIL_FROM and cfg.ALERT_EMAIL_TO and cfg.ALERT_EMAIL_PASSWORD:
        try:
            m = MIMEText(msg)
            m["Subject"] = subject
            m["From"]    = cfg.ALERT_EMAIL_FROM
            m["To"]      = cfg.ALERT_EMAIL_TO
            with smtplib.SMTP(cfg.ALERT_EMAIL_SMTP, cfg.ALERT_EMAIL_PORT) as s:
                s.starttls()
                s.login(cfg.ALERT_EMAIL_FROM, cfg.ALERT_EMAIL_PASSWORD)
                s.send_message(m)
            sent.append("Email")
        except Exception:
            pass

    return sent
