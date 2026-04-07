from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import yfinance as yf
import pandas as pd
from datetime import datetime, timedelta
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configuration from environment variables
BACKEND_HOST = os.getenv("BACKEND_HOST", "0.0.0.0")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "http://localhost:5173,http://localhost:3000").split(",")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

app = FastAPI(title="Stock Screener API")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class ScreenerCriteria(BaseModel):
    min_price: Optional[float] = None
    max_price: Optional[float] = None
    min_market_cap: Optional[float] = None
    max_market_cap: Optional[float] = None
    min_volume: Optional[float] = None
    min_pe_ratio: Optional[float] = None
    max_pe_ratio: Optional[float] = None
    min_dividend_yield: Optional[float] = None
    sector: Optional[str] = None
print("hello")
class StockSymbol(BaseModel):
    symbol: str

# Popular stocks to screen (you can expand this list)
POPULAR_STOCKS = [
    "AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA", "BRK-B",
    "JPM", "V", "JNJ", "WMT", "PG", "MA", "HD", "DIS", "NFLX", "PYPL",
    "INTC", "CSCO", "PFE", "KO", "PEP", "ABBV", "NKE", "MRK", "TMO", "COST"
]

# Extended list with company names for autocomplete
STOCK_DIRECTORY = [
    {"symbol": "AAPL", "name": "Apple Inc."},
    {"symbol": "MSFT", "name": "Microsoft Corporation"},
    {"symbol": "GOOGL", "name": "Alphabet Inc. (Google)"},
    {"symbol": "AMZN", "name": "Amazon.com Inc."},
    {"symbol": "NVDA", "name": "NVIDIA Corporation"},
    {"symbol": "META", "name": "Meta Platforms Inc. (Facebook)"},
    {"symbol": "TSLA", "name": "Tesla Inc."},
    {"symbol": "BRK-B", "name": "Berkshire Hathaway Inc."},
    {"symbol": "JPM", "name": "JPMorgan Chase & Co."},
    {"symbol": "V", "name": "Visa Inc."},
    {"symbol": "JNJ", "name": "Johnson & Johnson"},
    {"symbol": "WMT", "name": "Walmart Inc."},
    {"symbol": "PG", "name": "Procter & Gamble Co."},
    {"symbol": "MA", "name": "Mastercard Inc."},
    {"symbol": "HD", "name": "The Home Depot Inc."},
    {"symbol": "DIS", "name": "The Walt Disney Company"},
    {"symbol": "NFLX", "name": "Netflix Inc."},
    {"symbol": "PYPL", "name": "PayPal Holdings Inc."},
    {"symbol": "INTC", "name": "Intel Corporation"},
    {"symbol": "CSCO", "name": "Cisco Systems Inc."},
    {"symbol": "PFE", "name": "Pfizer Inc."},
    {"symbol": "KO", "name": "The Coca-Cola Company"},
    {"symbol": "PEP", "name": "PepsiCo Inc."},
    {"symbol": "ABBV", "name": "AbbVie Inc."},
    {"symbol": "NKE", "name": "Nike Inc."},
    {"symbol": "MRK", "name": "Merck & Co. Inc."},
    {"symbol": "TMO", "name": "Thermo Fisher Scientific Inc."},
    {"symbol": "COST", "name": "Costco Wholesale Corporation"},
    {"symbol": "BA", "name": "The Boeing Company"},
    {"symbol": "AMD", "name": "Advanced Micro Devices Inc."},
    {"symbol": "ORCL", "name": "Oracle Corporation"},
    {"symbol": "IBM", "name": "International Business Machines"},
    {"symbol": "ADBE", "name": "Adobe Inc."},
    {"symbol": "CRM", "name": "Salesforce Inc."},
    {"symbol": "QCOM", "name": "QUALCOMM Inc."},
    {"symbol": "TXN", "name": "Texas Instruments Inc."},
    {"symbol": "HON", "name": "Honeywell International Inc."},
    {"symbol": "UNP", "name": "Union Pacific Corporation"},
    {"symbol": "GE", "name": "General Electric Company"},
    {"symbol": "CAT", "name": "Caterpillar Inc."},
    {"symbol": "GS", "name": "The Goldman Sachs Group Inc."},
    {"symbol": "MS", "name": "Morgan Stanley"},
    {"symbol": "BAC", "name": "Bank of America Corporation"},
    {"symbol": "C", "name": "Citigroup Inc."},
    {"symbol": "WFC", "name": "Wells Fargo & Company"},
    {"symbol": "AXP", "name": "American Express Company"},
    {"symbol": "BLK", "name": "BlackRock Inc."},
    {"symbol": "SCHW", "name": "The Charles Schwab Corporation"},
    {"symbol": "CVX", "name": "Chevron Corporation"},
    {"symbol": "XOM", "name": "Exxon Mobil Corporation"},
    {"symbol": "LLY", "name": "Eli Lilly and Company"},
    {"symbol": "UNH", "name": "UnitedHealth Group Inc."},
    {"symbol": "CVS", "name": "CVS Health Corporation"},
    {"symbol": "AMGN", "name": "Amgen Inc."},
    {"symbol": "BMY", "name": "Bristol-Myers Squibb Company"},
    {"symbol": "MDT", "name": "Medtronic plc"},
    {"symbol": "GILD", "name": "Gilead Sciences Inc."},
    {"symbol": "F", "name": "Ford Motor Company"},
    {"symbol": "GM", "name": "General Motors Company"},
    {"symbol": "SPOT", "name": "Spotify Technology S.A."},
    {"symbol": "SQ", "name": "Block Inc. (Square)"},
    {"symbol": "UBER", "name": "Uber Technologies Inc."},
    {"symbol": "LYFT", "name": "Lyft Inc."},
    {"symbol": "SNAP", "name": "Snap Inc."},
    {"symbol": "TWTR", "name": "Twitter Inc."},
    {"symbol": "PINS", "name": "Pinterest Inc."},
    {"symbol": "ROKU", "name": "Roku Inc."},
    {"symbol": "ZM", "name": "Zoom Video Communications Inc."},
    {"symbol": "DOCU", "name": "DocuSign Inc."},
]

@app.get("/")
async def root():
    return {"message": "Stock Screener API is running"}

@app.get("/api/stocks/popular")
async def get_popular_stocks():
    """Get a list of popular stock symbols"""
    return {"stocks": POPULAR_STOCKS}

@app.get("/api/stocks/directory")
async def get_stock_directory():
    """Get a directory of stocks with symbols and names for autocomplete"""
    return {"stocks": STOCK_DIRECTORY}

@app.post("/api/stocks/info")
async def get_stock_info(stock: StockSymbol):
    """Get detailed information about a specific stock"""
    try:
        ticker = yf.Ticker(stock.symbol)
        info = ticker.info

        # Get historical data for chart
        hist = ticker.history(period="1mo")

        stock_data = {
            "symbol": stock.symbol,
            "name": info.get("longName", "N/A"),
            "price": info.get("currentPrice", info.get("regularMarketPrice", 0)),
            "change": info.get("regularMarketChange", 0),
            "changePercent": info.get("regularMarketChangePercent", 0),
            "marketCap": info.get("marketCap", 0),
            "volume": info.get("volume", 0),
            "avgVolume": info.get("averageVolume", 0),
            "peRatio": info.get("trailingPE", 0),
            "dividendYield": info.get("dividendYield", 0),
            "fiftyTwoWeekHigh": info.get("fiftyTwoWeekHigh", 0),
            "fiftyTwoWeekLow": info.get("fiftyTwoWeekLow", 0),
            "sector": info.get("sector", "N/A"),
            "industry": info.get("industry", "N/A"),
            "description": info.get("longBusinessSummary", "N/A"),
            "history": hist.reset_index().to_dict('records') if not hist.empty else []
        }

        return stock_data
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"Stock {stock.symbol} not found: {str(e)}")

@app.post("/api/stocks/screen")
async def screen_stocks(criteria: ScreenerCriteria):
    """Screen stocks based on specified criteria"""
    try:
        results = []

        for symbol in POPULAR_STOCKS:
            try:
                ticker = yf.Ticker(symbol)
                info = ticker.info

                # Extract relevant data
                price = info.get("currentPrice", info.get("regularMarketPrice", 0))
                market_cap = info.get("marketCap", 0)
                volume = info.get("volume", 0)
                pe_ratio = info.get("trailingPE", None)
                dividend_yield = info.get("dividendYield", 0)
                sector = info.get("sector", "")

                # Apply filters
                if criteria.min_price and price < criteria.min_price:
                    continue
                if criteria.max_price and price > criteria.max_price:
                    continue
                if criteria.min_market_cap and market_cap < criteria.min_market_cap:
                    continue
                if criteria.max_market_cap and market_cap > criteria.max_market_cap:
                    continue
                if criteria.min_volume and volume < criteria.min_volume:
                    continue
                if criteria.min_pe_ratio and (pe_ratio is None or pe_ratio < criteria.min_pe_ratio):
                    continue
                if criteria.max_pe_ratio and (pe_ratio is None or pe_ratio > criteria.max_pe_ratio):
                    continue
                if criteria.min_dividend_yield and dividend_yield < criteria.min_dividend_yield:
                    continue
                if criteria.sector and sector.lower() != criteria.sector.lower():
                    continue

                # Stock passes all filters
                results.append({
                    "symbol": symbol,
                    "name": info.get("longName", "N/A"),
                    "price": price,
                    "marketCap": market_cap,
                    "volume": volume,
                    "peRatio": pe_ratio,
                    "dividendYield": dividend_yield,
                    "sector": sector,
                    "change": info.get("regularMarketChange", 0),
                    "changePercent": info.get("regularMarketChangePercent", 0)
                })

            except Exception as e:
                # Skip stocks that fail to fetch
                print(f"Error fetching {symbol}: {str(e)}")
                continue

        return {"results": results, "count": len(results)}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error screening stocks: {str(e)}")

@app.get("/api/stocks/quote/{symbol}")
async def get_quote(symbol: str):
    """Get real-time quote for a stock"""
    try:
        ticker = yf.Ticker(symbol.upper())
        info = ticker.info

        quote = {
            "symbol": symbol.upper(),
            "name": info.get("longName", "N/A"),
            "price": info.get("currentPrice", info.get("regularMarketPrice", 0)),
            "change": info.get("regularMarketChange", 0),
            "changePercent": info.get("regularMarketChangePercent", 0),
            "volume": info.get("volume", 0),
            "marketCap": info.get("marketCap", 0),
        }

        return quote
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"Could not fetch quote for {symbol}: {str(e)}")

@app.get("/api/stocks/news/{symbol}")
async def get_stock_news(symbol: str):
    """Get recent news articles for a stock"""
    try:
        ticker = yf.Ticker(symbol.upper())
        news = ticker.news

        # Format news articles
        articles = []
        for item in news[:10]:  # Limit to 10 articles
            article = {
                "title": item.get("title", ""),
                "publisher": item.get("publisher", ""),
                "link": item.get("link", ""),
                "publishedAt": item.get("providerPublishTime", 0),
                "type": item.get("type", ""),
                "thumbnail": item.get("thumbnail", {}).get("resolutions", [{}])[0].get("url", "") if item.get("thumbnail") else "",
                "relatedTickers": item.get("relatedTickers", [])
            }
            articles.append(article)

        return {"symbol": symbol.upper(), "news": articles, "count": len(articles)}
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"Could not fetch news for {symbol}: {str(e)}")

@app.get("/api/stocks/fundamentals/{symbol}")
async def get_fundamentals(symbol: str):
    """Get fundamental financial data for a stock"""
    try:
        ticker = yf.Ticker(symbol.upper())
        info = ticker.info

        # Get financial statements
        income_stmt = ticker.income_stmt
        balance_sheet = ticker.balance_sheet
        cash_flow = ticker.cashflow

        # Helper function to safely get values from DataFrames
        def safe_get(df, key, default=None):
            try:
                if df is not None and not df.empty and key in df.index:
                    values = df.loc[key].dropna().tolist()
                    return values if values else default
                return default
            except:
                return default

        # Helper to get dates from DataFrame columns
        def get_dates(df):
            try:
                if df is not None and not df.empty:
                    return [col.strftime('%Y-%m-%d') if hasattr(col, 'strftime') else str(col) for col in df.columns]
                return []
            except:
                return []

        # Build fundamentals response
        fundamentals = {
            "symbol": symbol.upper(),
            "name": info.get("longName", "N/A"),

            # Valuation Metrics
            "valuation": {
                "marketCap": info.get("marketCap", 0),
                "enterpriseValue": info.get("enterpriseValue", 0),
                "trailingPE": info.get("trailingPE"),
                "forwardPE": info.get("forwardPE"),
                "pegRatio": info.get("pegRatio"),
                "priceToBook": info.get("priceToBook"),
                "priceToSales": info.get("priceToSalesTrailing12Months"),
                "enterpriseToRevenue": info.get("enterpriseToRevenue"),
                "enterpriseToEbitda": info.get("enterpriseToEbitda"),
            },

            # Profitability Metrics
            "profitability": {
                "profitMargin": info.get("profitMargins"),
                "operatingMargin": info.get("operatingMargins"),
                "grossMargin": info.get("grossMargins"),
                "returnOnAssets": info.get("returnOnAssets"),
                "returnOnEquity": info.get("returnOnEquity"),
            },

            # Growth Metrics
            "growth": {
                "revenueGrowth": info.get("revenueGrowth"),
                "earningsGrowth": info.get("earningsGrowth"),
                "earningsQuarterlyGrowth": info.get("earningsQuarterlyGrowth"),
            },

            # Financial Health
            "financialHealth": {
                "totalCash": info.get("totalCash", 0),
                "totalCashPerShare": info.get("totalCashPerShare"),
                "totalDebt": info.get("totalDebt", 0),
                "debtToEquity": info.get("debtToEquity"),
                "currentRatio": info.get("currentRatio"),
                "quickRatio": info.get("quickRatio"),
            },

            # Per Share Data
            "perShare": {
                "trailingEps": info.get("trailingEps"),
                "forwardEps": info.get("forwardEps"),
                "bookValue": info.get("bookValue"),
                "revenuePerShare": info.get("revenuePerShare"),
                "freeCashflow": info.get("freeCashflow"),
            },

            # Dividend Info
            "dividend": {
                "dividendRate": info.get("dividendRate"),
                "dividendYield": info.get("dividendYield"),
                "payoutRatio": info.get("payoutRatio"),
                "exDividendDate": info.get("exDividendDate"),
                "lastDividendValue": info.get("lastDividendValue"),
            },

            # Historical Income Statement Data (for charts)
            "incomeHistory": {
                "dates": get_dates(income_stmt),
                "totalRevenue": safe_get(income_stmt, "Total Revenue", []),
                "grossProfit": safe_get(income_stmt, "Gross Profit", []),
                "operatingIncome": safe_get(income_stmt, "Operating Income", []),
                "netIncome": safe_get(income_stmt, "Net Income", []),
                "ebitda": safe_get(income_stmt, "EBITDA", []),
            },

            # Historical Balance Sheet Data
            "balanceSheetHistory": {
                "dates": get_dates(balance_sheet),
                "totalAssets": safe_get(balance_sheet, "Total Assets", []),
                "totalLiabilities": safe_get(balance_sheet, "Total Liabilities Net Minority Interest", []),
                "totalEquity": safe_get(balance_sheet, "Stockholders Equity", []),
                "totalDebt": safe_get(balance_sheet, "Total Debt", []),
                "cash": safe_get(balance_sheet, "Cash And Cash Equivalents", []),
            },

            # Historical Cash Flow Data
            "cashFlowHistory": {
                "dates": get_dates(cash_flow),
                "operatingCashFlow": safe_get(cash_flow, "Operating Cash Flow", []),
                "freeCashFlow": safe_get(cash_flow, "Free Cash Flow", []),
                "capitalExpenditures": safe_get(cash_flow, "Capital Expenditure", []),
            },

            # Analyst Recommendations
            "analystTargets": {
                "targetHigh": info.get("targetHighPrice"),
                "targetLow": info.get("targetLowPrice"),
                "targetMean": info.get("targetMeanPrice"),
                "targetMedian": info.get("targetMedianPrice"),
                "recommendationMean": info.get("recommendationMean"),
                "recommendationKey": info.get("recommendationKey"),
                "numberOfAnalysts": info.get("numberOfAnalystOpinions"),
            },
        }

        return fundamentals
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"Could not fetch fundamentals for {symbol}: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=BACKEND_HOST, port=BACKEND_PORT)
