import { useState, useEffect } from 'react'
import './App.css'
import StockScreener from './components/StockScreener'
import StockDetail from './components/StockDetail'
import StockCompare from './components/StockCompare'

type Theme = 'dark' | 'light'
type View = 'screener' | 'detail' | 'compare'

function App() {
  const [selectedStock, setSelectedStock] = useState<string | null>(null)
  const [view, setView] = useState<View>('screener')
  const [compareStocks, setCompareStocks] = useState<[string, string] | undefined>(undefined)
  const [theme, setTheme] = useState<Theme>(() => {
    const saved = localStorage.getItem('theme')
    return (saved as Theme) || 'dark'
  })
  const [watchlist, setWatchlist] = useState<string[]>(() => {
    const saved = localStorage.getItem('watchlist')
    return saved ? JSON.parse(saved) : []
  })

  // Apply theme on mount and when it changes
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('theme', theme)
  }, [theme])

  // Save watchlist to localStorage when it changes
  useEffect(() => {
    localStorage.setItem('watchlist', JSON.stringify(watchlist))
  }, [watchlist])

  const toggleTheme = () => {
    setTheme(prev => prev === 'dark' ? 'light' : 'dark')
  }

  const addToWatchlist = (symbol: string) => {
    setWatchlist(prev => {
      if (prev.includes(symbol)) return prev
      return [...prev, symbol]
    })
  }

  const removeFromWatchlist = (symbol: string) => {
    setWatchlist(prev => prev.filter(s => s !== symbol))
  }

  const isInWatchlist = (symbol: string) => watchlist.includes(symbol)

  const handleSelectStock = (symbol: string) => {
    setSelectedStock(symbol)
    setView('detail')
  }

  const handleBackToScreener = () => {
    setSelectedStock(null)
    setView('screener')
  }

  const handleOpenCompare = (stocks?: [string, string]) => {
    setCompareStocks(stocks)
    setView('compare')
  }

  const handleCloseCompare = () => {
    setCompareStocks(undefined)
    setView('screener')
  }

  const handleCompareFromDetail = (symbol: string) => {
    setCompareStocks([symbol, ''])
    setView('compare')
  }

  return (
    <div className="App">
      <header className="app-header">
        <div className="header-content">
          <div className="header-title">
            <h1>Stock Screener</h1>
            <p>Advanced equity screening and analysis platform</p>
          </div>
          <div className="header-actions">
            <button
              className={`compare-toggle ${view === 'compare' ? 'active' : ''}`}
              onClick={() => view === 'compare' ? handleCloseCompare() : handleOpenCompare()}
              title="Compare Stocks"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="18" y1="20" x2="18" y2="10"/>
                <line x1="12" y1="20" x2="12" y2="4"/>
                <line x1="6" y1="20" x2="6" y2="14"/>
              </svg>
              <span>Compare</span>
            </button>
            <button
              className="theme-toggle"
              onClick={toggleTheme}
              aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
            >
              {theme === 'dark' ? (
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="5"/>
                  <line x1="12" y1="1" x2="12" y2="3"/>
                  <line x1="12" y1="21" x2="12" y2="23"/>
                  <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/>
                  <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/>
                  <line x1="1" y1="12" x2="3" y2="12"/>
                  <line x1="21" y1="12" x2="23" y2="12"/>
                  <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/>
                  <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>
                </svg>
              ) : (
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
                </svg>
              )}
              <span>{theme === 'dark' ? 'Light' : 'Dark'}</span>
            </button>
          </div>
        </div>
      </header>

      <main className="app-main">
        {view === 'compare' ? (
          <StockCompare
            initialStocks={compareStocks}
            onClose={handleCloseCompare}
            onSelectStock={handleSelectStock}
          />
        ) : view === 'detail' && selectedStock ? (
          <div>
            <div className="detail-actions">
              <button
                className="back-button"
                onClick={handleBackToScreener}
              >
                ← Back to Screener
              </button>
              <button
                className="compare-button"
                onClick={() => handleCompareFromDetail(selectedStock)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <line x1="18" y1="20" x2="18" y2="10"/>
                  <line x1="12" y1="20" x2="12" y2="4"/>
                  <line x1="6" y1="20" x2="6" y2="14"/>
                </svg>
                Compare with another stock
              </button>
            </div>
            <StockDetail
              symbol={selectedStock}
              isInWatchlist={isInWatchlist(selectedStock)}
              onAddToWatchlist={() => addToWatchlist(selectedStock)}
              onRemoveFromWatchlist={() => removeFromWatchlist(selectedStock)}
            />
          </div>
        ) : (
          <StockScreener
            onSelectStock={handleSelectStock}
            watchlist={watchlist}
            onRemoveFromWatchlist={removeFromWatchlist}
          />
        )}
      </main>
    </div>
  )
}

export default App
