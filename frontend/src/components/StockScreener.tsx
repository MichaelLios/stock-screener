import { useState, useEffect } from 'react'
import axios from 'axios'
import './StockScreener.css'

// Skeleton Components
function SkeletonPulse({ className }: { className?: string }) {
  return <div className={`skeleton-pulse ${className || ''}`} />
}

function StockCardSkeleton() {
  return (
    <div className="stock-card skeleton-card">
      <div className="stock-card-header">
        <SkeletonPulse className="skeleton-card-symbol" />
        <SkeletonPulse className="skeleton-card-change" />
      </div>
      <SkeletonPulse className="skeleton-card-name" />
      <SkeletonPulse className="skeleton-card-price" />
      <SkeletonPulse className="skeleton-card-cap" />
    </div>
  )
}

interface Stock {
  symbol: string
  name: string
  price: number
  marketCap: number
  volume: number
  peRatio: number | null
  dividendYield: number
  sector: string
  change: number
  changePercent: number
}

interface QuickStock {
  symbol: string
  name: string
  price: number
  change: number
  changePercent: number
  marketCap: number
}

interface StockSuggestion {
  symbol: string
  name: string
}

interface ScreenerCriteria {
  min_price?: number
  max_price?: number
  min_market_cap?: number
  max_market_cap?: number
  min_volume?: number
  min_pe_ratio?: number
  max_pe_ratio?: number
  min_dividend_yield?: number
  sector?: string
}

interface Props {
  onSelectStock: (symbol: string) => void
  watchlist: string[]
  onRemoveFromWatchlist: (symbol: string) => void
}

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

type SortField = 'symbol' | 'name' | 'price' | 'changePercent' | 'marketCap' | 'volume' | 'peRatio' | 'dividendYield' | 'sector'
type SortDirection = 'asc' | 'desc'

function StockScreener({ onSelectStock, watchlist, onRemoveFromWatchlist }: Props) {
  const [criteria, setCriteria] = useState<ScreenerCriteria>({})
  const [results, setResults] = useState<Stock[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [quickStocks, setQuickStocks] = useState<QuickStock[]>([])
  const [loadingQuick, setLoadingQuick] = useState(true)
  const [searchSymbol, setSearchSymbol] = useState('')
  const [searchLoading, setSearchLoading] = useState(false)
  const [stockDirectory, setStockDirectory] = useState<StockSuggestion[]>([])
  const [suggestions, setSuggestions] = useState<StockSuggestion[]>([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [watchlistStocks, setWatchlistStocks] = useState<QuickStock[]>([])
  const [loadingWatchlist, setLoadingWatchlist] = useState(false)
  const [sortField, setSortField] = useState<SortField>('changePercent')
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc')

  useEffect(() => {
    loadQuickStocks()
    loadStockDirectory()
  }, [])

  // Load watchlist stocks when watchlist changes
  useEffect(() => {
    if (watchlist.length > 0) {
      loadWatchlistStocks()
    } else {
      setWatchlistStocks([])
    }
  }, [watchlist])

  useEffect(() => {
    // Close suggestions when clicking outside or pressing Escape
    const handleClickOutside = (e: MouseEvent) => {
      const target = e.target as HTMLElement
      if (!target.closest('.search-input-container')) {
        setShowSuggestions(false)
      }
    }

    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setShowSuggestions(false)
      }
    }

    document.addEventListener('click', handleClickOutside)
    document.addEventListener('keydown', handleEscape)
    return () => {
      document.removeEventListener('click', handleClickOutside)
      document.removeEventListener('keydown', handleEscape)
    }
  }, [])

  const loadQuickStocks = async () => {
    setLoadingQuick(true)
    try {
      const response = await axios.get(`${API_URL}/api/stocks/popular`)
      const symbols = response.data.stocks

      // Fetch quotes for popular stocks
      const stockPromises = symbols.slice(0, 12).map((symbol: string) =>
        axios.get(`${API_URL}/api/stocks/quote/${symbol}`).catch(() => null)
      )

      const stocksData = await Promise.all(stockPromises)
      const validStocks = stocksData
        .filter((res) => res !== null)
        .map((res) => res!.data)

      setQuickStocks(validStocks)
    } catch (err) {
      console.error('Failed to load quick stocks:', err)
    } finally {
      setLoadingQuick(false)
    }
  }

  const loadWatchlistStocks = async () => {
    setLoadingWatchlist(true)
    try {
      const stockPromises = watchlist.map((symbol: string) =>
        axios.get(`${API_URL}/api/stocks/quote/${symbol}`).catch(() => null)
      )

      const stocksData = await Promise.all(stockPromises)
      const validStocks = stocksData
        .filter((res) => res !== null)
        .map((res) => res!.data)

      setWatchlistStocks(validStocks)
    } catch (err) {
      console.error('Failed to load watchlist stocks:', err)
    } finally {
      setLoadingWatchlist(false)
    }
  }

  const loadStockDirectory = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/stocks/directory`)
      setStockDirectory(response.data.stocks)
    } catch (err) {
      console.error('Failed to load stock directory:', err)
    }
  }

  const handleSearchInputChange = (value: string) => {
    setSearchSymbol(value)

    if (value.trim().length > 0) {
      // Filter suggestions based on input
      const filtered = stockDirectory.filter(stock =>
        stock.symbol.toLowerCase().includes(value.toLowerCase()) ||
        stock.name.toLowerCase().includes(value.toLowerCase())
      ).slice(0, 8) // Limit to 8 suggestions

      setSuggestions(filtered)
      setShowSuggestions(true)
    } else {
      setSuggestions([])
      setShowSuggestions(false)
    }
  }

  const handleSelectSuggestion = (symbol: string) => {
    setSearchSymbol(symbol)
    setShowSuggestions(false)
    setSuggestions([])
    // Trigger search
    handleSearchWithSymbol(symbol)
  }

  const handleSearchWithSymbol = async (symbol: string) => {
    setSearchLoading(true)
    setError(null)

    try {
      // Try to fetch the stock to verify it exists
      await axios.get(`${API_URL}/api/stocks/quote/${symbol.toUpperCase()}`)
      // If successful, navigate to the stock detail page
      onSelectStock(symbol.toUpperCase())
    } catch (err) {
      setError(`Stock symbol "${symbol.toUpperCase()}" not found. Please check the symbol and try again.`)
    } finally {
      setSearchLoading(false)
    }
  }

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!searchSymbol.trim()) return

    setShowSuggestions(false)
    handleSearchWithSymbol(searchSymbol)
  }

  const handleInputChange = (field: keyof ScreenerCriteria, value: string) => {
    if (value === '') {
      const newCriteria = { ...criteria }
      delete newCriteria[field]
      setCriteria(newCriteria)
    } else {
      setCriteria({
        ...criteria,
        [field]: field === 'sector' ? value : parseFloat(value)
      })
    }
  }

  const handleQuickFilter = async (minPrice?: number, maxPrice?: number) => {
    const newCriteria: ScreenerCriteria = { ...criteria }
    if (minPrice !== undefined) newCriteria.min_price = minPrice
    if (maxPrice !== undefined) newCriteria.max_price = maxPrice

    setCriteria(newCriteria)

    // Auto-run the screen
    setLoading(true)
    setError(null)

    try {
      const response = await axios.post(`${API_URL}/api/stocks/screen`, newCriteria)
      setResults(response.data.results)
    } catch (err) {
      setError('Failed to screen stocks. Make sure the backend server is running.')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const handleScreen = async () => {
    setLoading(true)
    setError(null)

    try {
      const response = await axios.post(`${API_URL}/api/stocks/screen`, criteria)
      setResults(response.data.results)
    } catch (err) {
      setError('Failed to screen stocks. Make sure the backend server is running.')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const exportToCSV = () => {
    if (results.length === 0) return

    // CSV headers
    const headers = ['Symbol', 'Name', 'Price', 'Change %', 'Market Cap', 'Volume', 'P/E Ratio', 'Dividend Yield', 'Sector']

    // CSV rows
    const rows = results.map(stock => [
      stock.symbol,
      `"${stock.name.replace(/"/g, '""')}"`, // Escape quotes in names
      stock.price.toFixed(2),
      stock.changePercent.toFixed(2),
      stock.marketCap,
      stock.volume,
      stock.peRatio?.toFixed(2) ?? 'N/A',
      stock.dividendYield ? (stock.dividendYield * 100).toFixed(2) : 'N/A',
      stock.sector
    ])

    // Combine headers and rows
    const csvContent = [
      headers.join(','),
      ...rows.map(row => row.join(','))
    ].join('\n')

    // Create blob and download
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.setAttribute('href', url)
    link.setAttribute('download', `stock-screener-results-${new Date().toISOString().split('T')[0]}.csv`)
    link.style.visibility = 'hidden'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  const formatNumber = (num: number, prefix: string = ''): string => {
    if (num >= 1e12) return `${prefix}${(num / 1e12).toFixed(2)}T`
    if (num >= 1e9) return `${prefix}${(num / 1e9).toFixed(2)}B`
    if (num >= 1e6) return `${prefix}${(num / 1e6).toFixed(2)}M`
    if (num >= 1e3) return `${prefix}${(num / 1e3).toFixed(2)}K`
    return `${prefix}${num.toFixed(2)}`
  }

  const formatPercent = (num: number): string => {
    return `${num > 0 ? '+' : ''}${num.toFixed(2)}%`
  }

  // Get color intensity class based on percentage change
  const getChangeIntensity = (changePercent: number): string => {
    const absChange = Math.abs(changePercent)
    const direction = changePercent >= 0 ? 'positive' : 'negative'

    if (absChange >= 5) return `${direction} intensity-extreme`
    if (absChange >= 3) return `${direction} intensity-high`
    if (absChange >= 1.5) return `${direction} intensity-medium`
    if (absChange >= 0.5) return `${direction} intensity-low`
    return `${direction} intensity-minimal`
  }

  // Handle column sorting
  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc')
    } else {
      setSortField(field)
      setSortDirection('desc')
    }
  }

  // Sort results
  const sortedResults = [...results].sort((a, b) => {
    let aVal: string | number | null = a[sortField]
    let bVal: string | number | null = b[sortField]

    // Handle null values
    if (aVal === null || aVal === undefined) aVal = sortDirection === 'asc' ? Infinity : -Infinity
    if (bVal === null || bVal === undefined) bVal = sortDirection === 'asc' ? Infinity : -Infinity

    // String comparison
    if (typeof aVal === 'string' && typeof bVal === 'string') {
      return sortDirection === 'asc'
        ? aVal.localeCompare(bVal)
        : bVal.localeCompare(aVal)
    }

    // Numeric comparison
    if (sortDirection === 'asc') {
      return (aVal as number) - (bVal as number)
    }
    return (bVal as number) - (aVal as number)
  })

  // Sort indicator component
  const SortIndicator = ({ field }: { field: SortField }) => {
    if (sortField !== field) {
      return (
        <span className="sort-indicator inactive">
          <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M7 15l5 5 5-5M7 9l5-5 5 5"/>
          </svg>
        </span>
      )
    }
    return (
      <span className="sort-indicator active">
        {sortDirection === 'asc' ? (
          <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M7 14l5-5 5 5"/>
          </svg>
        ) : (
          <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M7 10l5 5 5-5"/>
          </svg>
        )}
      </span>
    )
  }

  return (
    <div className="stock-screener">
      {/* Watchlist Section */}
      {watchlist.length > 0 && (
        <div className="watchlist-section">
          <div className="watchlist-header">
            <h2>
              <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
              </svg>
              Your Watchlist ({watchlist.length})
            </h2>
          </div>
          {loadingWatchlist ? (
            <div className="stocks-grid">
              {watchlist.map((_, i) => (
                <StockCardSkeleton key={i} />
              ))}
            </div>
          ) : (
            <div className="stocks-grid">
              {watchlistStocks.map((stock) => (
                <div
                  key={stock.symbol}
                  className="stock-card watchlist-card"
                >
                  <button
                    className="remove-watchlist-btn"
                    onClick={(e) => {
                      e.stopPropagation()
                      onRemoveFromWatchlist(stock.symbol)
                    }}
                    title="Remove from watchlist"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <line x1="18" y1="6" x2="6" y2="18"/>
                      <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                  </button>
                  <div
                    className="stock-card-content"
                    onClick={() => onSelectStock(stock.symbol)}
                  >
                    <div className="stock-card-header">
                      <div className="stock-symbol">{stock.symbol}</div>
                      <div className={`stock-change ${getChangeIntensity(stock.changePercent)}`}>
                        {stock.change >= 0 ? '+' : ''}{stock.changePercent.toFixed(2)}%
                      </div>
                    </div>
                    <div className="stock-name">{stock.name}</div>
                    <div className="stock-price">${stock.price.toFixed(2)}</div>
                    <div className="stock-market-cap">{formatNumber(stock.marketCap, '$')} cap</div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      <div className="quick-select-section">
        <h2>Quick Select</h2>

        <div className="search-section">
          <h3>Search Stock</h3>
          <form onSubmit={handleSearch} className="search-form">
            <div className="search-input-container">
              <input
                type="text"
                className="search-input"
                placeholder="Enter stock symbol or company name..."
                value={searchSymbol}
                onChange={(e) => handleSearchInputChange(e.target.value)}
                onFocus={() => {
                  if (suggestions.length > 0) setShowSuggestions(true)
                }}
                disabled={searchLoading}
                autoComplete="off"
              />
              {showSuggestions && suggestions.length > 0 && (
                <div className="suggestions-dropdown">
                  {suggestions.map((stock) => (
                    <div
                      key={stock.symbol}
                      className="suggestion-item"
                      onClick={() => handleSelectSuggestion(stock.symbol)}
                    >
                      <span className="suggestion-symbol">{stock.symbol}</span>
                      <span className="suggestion-name">{stock.name}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
            <button
              type="submit"
              className="search-button"
              disabled={searchLoading || !searchSymbol.trim()}
            >
              {searchLoading ? 'Searching...' : 'Search'}
            </button>
          </form>
        </div>

        <div className="quick-filters">
          <h3>Price Ranges</h3>
          <div className="filter-buttons">
            <button
              className="filter-button"
              onClick={() => handleQuickFilter(0, 50)}
            >
              Under $50
            </button>
            <button
              className="filter-button"
              onClick={() => handleQuickFilter(50, 200)}
            >
              $50 - $200
            </button>
            <button
              className="filter-button"
              onClick={() => handleQuickFilter(200, 500)}
            >
              $200 - $500
            </button>
            <button
              className="filter-button"
              onClick={() => handleQuickFilter(500, undefined)}
            >
              Over $500
            </button>
          </div>
        </div>

        <div className="popular-stocks">
          <h3>Popular Stocks</h3>
          {loadingQuick ? (
            <div className="stocks-grid">
              {[...Array(12)].map((_, i) => (
                <StockCardSkeleton key={i} />
              ))}
            </div>
          ) : (
            <div className="stocks-grid">
              {quickStocks.map((stock) => (
                <div
                  key={stock.symbol}
                  className="stock-card"
                  onClick={() => onSelectStock(stock.symbol)}
                >
                  <div className="stock-card-header">
                    <div className="stock-symbol">{stock.symbol}</div>
                    <div className={`stock-change ${getChangeIntensity(stock.changePercent)}`}>
                      {stock.change >= 0 ? '+' : ''}{stock.changePercent.toFixed(2)}%
                    </div>
                  </div>
                  <div className="stock-name">{stock.name}</div>
                  <div className="stock-price">${stock.price.toFixed(2)}</div>
                  <div className="stock-market-cap">{formatNumber(stock.marketCap, '$')} cap</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="screener-form">
        <h2>Advanced Screen Criteria</h2>

        <div className="form-grid">
          <div className="form-group">
            <label>Min Price ($)</label>
            <input
              type="number"
              placeholder="e.g., 10"
              onChange={(e) => handleInputChange('min_price', e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Max Price ($)</label>
            <input
              type="number"
              placeholder="e.g., 500"
              onChange={(e) => handleInputChange('max_price', e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Min Market Cap ($)</label>
            <input
              type="number"
              placeholder="e.g., 1000000000"
              onChange={(e) => handleInputChange('min_market_cap', e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Max Market Cap ($)</label>
            <input
              type="number"
              placeholder="e.g., 5000000000000"
              onChange={(e) => handleInputChange('max_market_cap', e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Min Volume</label>
            <input
              type="number"
              placeholder="e.g., 1000000"
              onChange={(e) => handleInputChange('min_volume', e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Min P/E Ratio</label>
            <input
              type="number"
              placeholder="e.g., 10"
              onChange={(e) => handleInputChange('min_pe_ratio', e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Max P/E Ratio</label>
            <input
              type="number"
              placeholder="e.g., 30"
              onChange={(e) => handleInputChange('max_pe_ratio', e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Min Dividend Yield (%)</label>
            <input
              type="number"
              step="0.01"
              placeholder="e.g., 0.02"
              onChange={(e) => handleInputChange('min_dividend_yield', e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Sector</label>
            <input
              type="text"
              placeholder="e.g., Technology"
              onChange={(e) => handleInputChange('sector', e.target.value)}
            />
          </div>
        </div>

        <button
          className="screen-button"
          onClick={handleScreen}
          disabled={loading}
        >
          {loading ? 'Screening...' : 'Screen Stocks'}
        </button>
      </div>

      {error && <div className="error-message">{error}</div>}

      {results.length > 0 && (
        <div className="results-section">
          <div className="results-header">
            <h2>Results ({results.length} stocks found)</h2>
            <button className="export-button" onClick={exportToCSV}>
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                <polyline points="7 10 12 15 17 10"/>
                <line x1="12" y1="15" x2="12" y2="3"/>
              </svg>
              Export CSV
            </button>
          </div>
          <div className="results-table-container">
            <table className="results-table">
              <thead>
                <tr>
                  <th className="sortable-header" onClick={() => handleSort('symbol')}>
                    Symbol <SortIndicator field="symbol" />
                  </th>
                  <th className="sortable-header" onClick={() => handleSort('name')}>
                    Name <SortIndicator field="name" />
                  </th>
                  <th className="sortable-header" onClick={() => handleSort('price')}>
                    Price <SortIndicator field="price" />
                  </th>
                  <th className="sortable-header" onClick={() => handleSort('changePercent')}>
                    Change <SortIndicator field="changePercent" />
                  </th>
                  <th className="sortable-header" onClick={() => handleSort('marketCap')}>
                    Market Cap <SortIndicator field="marketCap" />
                  </th>
                  <th className="sortable-header" onClick={() => handleSort('volume')}>
                    Volume <SortIndicator field="volume" />
                  </th>
                  <th className="sortable-header" onClick={() => handleSort('peRatio')}>
                    P/E Ratio <SortIndicator field="peRatio" />
                  </th>
                  <th className="sortable-header" onClick={() => handleSort('dividendYield')}>
                    Div Yield <SortIndicator field="dividendYield" />
                  </th>
                  <th className="sortable-header" onClick={() => handleSort('sector')}>
                    Sector <SortIndicator field="sector" />
                  </th>
                </tr>
              </thead>
              <tbody>
                {sortedResults.map((stock) => (
                  <tr
                    key={stock.symbol}
                    onClick={() => onSelectStock(stock.symbol)}
                    className="clickable-row"
                  >
                    <td className="symbol-cell">{stock.symbol}</td>
                    <td>{stock.name}</td>
                    <td>${stock.price.toFixed(2)}</td>
                    <td className={`change-cell ${getChangeIntensity(stock.changePercent)}`}>
                      {formatPercent(stock.changePercent)}
                    </td>
                    <td>{formatNumber(stock.marketCap, '$')}</td>
                    <td>{formatNumber(stock.volume)}</td>
                    <td>{stock.peRatio?.toFixed(2) ?? 'N/A'}</td>
                    <td>{stock.dividendYield ? (stock.dividendYield * 100).toFixed(2) + '%' : 'N/A'}</td>
                    <td>{stock.sector}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}

export default StockScreener
