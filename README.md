# Stock Screener

A stock screening and analysis platform with real-time market data from Yahoo Finance. Built with **FastAPI** (Python) and **React + Vite** (TypeScript).

![Python](https://img.shields.io/badge/Python-3.8+-blue) ![React](https://img.shields.io/badge/React-19-61dafb) ![FastAPI](https://img.shields.io/badge/FastAPI-0.128-009688) ![Vite](https://img.shields.io/badge/Vite-7-646cff)

## Features

- **Stock Search** — Search by symbol or company name with autocomplete (70+ pre-loaded stocks)
- **Quick Filters** — One-click price range filters (Under $50, $50-$200, $200-$500, Over $500)
- **Advanced Screening** — Filter by price, market cap, volume, P/E ratio, dividend yield, and sector
- **Stock Detail View** — Current price, key metrics, 52-week range, company info, and 10-day price history
- **Popular Stocks Grid** — Live prices for 12 major stocks at a glance
- **Dark Theme** — Professional, responsive UI

All data is fetched in real-time from Yahoo Finance — no API key required.

## Quick Start

### Prerequisites

- Python 3.8+
- Node.js 16+

### Setup

```bash
# 1. Clone the repo
git clone <your-repo-url>
cd finance-builder-thing

# 2. Run the setup script (creates .env files, installs dependencies)
setup.bat
```

Or set up manually:

```bash
# Create env files
copy .env.example .env
copy frontend\.env.example frontend\.env

# Python backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt

# React frontend
cd frontend
npm install
```

### Run

```bash
# Terminal 1 — Backend (http://localhost:8000)
start-backend.bat

# Terminal 2 — Frontend (http://localhost:5173)
start-frontend.bat
```

Then open **http://localhost:5173** in your browser.

## Project Structure

```
├── backend/
│   └── main.py              # FastAPI server with all API endpoints
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── StockScreener.tsx / .css
│   │   │   └── StockDetail.tsx / .css
│   │   ├── App.tsx / .css
│   │   ├── main.tsx
│   │   └── index.css
│   ├── .env.example
│   ├── package.json
│   └── vite.config.ts
├── .env.example             # Backend env template
├── .gitignore
├── requirements.txt
├── setup.bat
├── start-backend.bat
├── start-frontend.bat
├── SETUP.md                 # Detailed setup guide
└── ENV_VARIABLES.md         # Environment variables reference
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Health check |
| `GET` | `/api/stocks/popular` | List of popular stock symbols |
| `GET` | `/api/stocks/directory` | Full stock directory (for autocomplete) |
| `GET` | `/api/stocks/quote/{symbol}` | Real-time quote for a stock |
| `POST` | `/api/stocks/info` | Detailed stock information |
| `POST` | `/api/stocks/screen` | Screen stocks by criteria |

## Configuration

Environment variables are stored in `.env` (backend) and `frontend/.env` (frontend). See [ENV_VARIABLES.md](ENV_VARIABLES.md) for full reference.

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKEND_HOST` | `0.0.0.0` | Backend host |
| `BACKEND_PORT` | `8000` | Backend port |
| `CORS_ORIGINS` | `http://localhost:5173,http://localhost:3000` | Allowed origins |
| `ENVIRONMENT` | `development` | Environment mode |
| `VITE_API_URL` | `http://localhost:8000` | Backend URL (frontend) |

## Tech Stack

**Backend:** FastAPI, yfinance, pandas, uvicorn, python-dotenv
**Frontend:** React 18, TypeScript, Vite, Axios, Recharts

## Troubleshooting

See [SETUP.md](SETUP.md) for detailed setup instructions and troubleshooting steps.

Common issues:
- **Port in use** — Change `BACKEND_PORT` in `.env` and update `VITE_API_URL` in `frontend/.env`
- **No data showing** — Check both servers are running and you have internet access
- **CORS errors** — Ensure `CORS_ORIGINS` in `.env` includes your frontend URL

## Disclaimer

This tool is for **educational and research purposes only**. Not financial advice. Always do your own research before making investment decisions.

## License

MIT
