import { useState, useEffect } from 'react'
import axios from 'axios'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  Legend
} from 'recharts'
import './StockCompare.css'

interface StockInfo {
  symbol: string
  name: string
  price: number
  change: number
  changePercent: number
  marketCap: number
  volume: number
  avgVolume: number
  peRatio: number
  dividendYield: number
  fiftyTwoWeekHigh: number
  fiftyTwoWeekLow: number
  sector: string
  industry: string
  history: Array<{
    Date: string
    Close: number
  }>
}

interface StockSuggestion {
  symbol: string
  name: string
}

interface Props {
  initialStocks?: [string, string]
  onClose: () => void
  onSelectStock: (symbol: string) => void
}

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

function SkeletonPulse({ className }: { className?: string }) {
  return <div className={`skeleton-pulse ${className || ''}`} />
}

function StockCompare({ initialStocks, onClose, onSelectStock }: Props) {
  const [stock1Symbol, setStock1Symbol] = useState(initialStocks?.[0] || '')
  const [stock2Symbol, setStock2Symbol] = useState(initialStocks?.[1] || '')
  const [stock1, setStock1] = useState<StockInfo | null>(null)
  const [stock2, setStock2] = useState<StockInfo | null>(null)
  const [loading1, setLoading1] = useState(false)
  const [loading2, setLoading2] = useState(false)
  const [error1, setError1] = useState<string | null>(null)
  const [error2, setError2] = useState<string | null>(null)
  const [stockDirectory, setStockDirectory] = useState<StockSuggestion[]>([])
  const [suggestions1, setSuggestions1] = useState<StockSuggestion[]>([])
  const [suggestions2, setSuggestions2] = useState<StockSuggestion[]>([])
  const [showSuggestions1, setShowSuggestions1] = useState(false)
  const [showSuggestions2, setShowSuggestions2] = useState(false)
  const [searchInput1, setSearchInput1] = useState('')
  const [searchInput2, setSearchInput2] = useState('')

  useEffect(() => {
    loadStockDirectory()
  }, [])

  useEffect(() => {
    if (initialStocks?.[0]) {
      loadStock(initialStocks[0], 1)
      setSearchInput1(initialStocks[0])
    }
    if (initialStocks?.[1]) {
      loadStock(initialStocks[1], 2)
      setSearchInput2(initialStocks[1])
    }
  }, [initialStocks])

  const loadStockDirectory = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/stocks/directory`)
      setStockDirectory(response.data.stocks)
    } catch (err) {
      console.error('Failed to load stock directory:', err)
    }
  }

  const loadStock = async (symbol: string, slot: 1 | 2) => {
    if (slot === 1) {
      setLoading1(true)
      setError1(null)
    } else {
      setLoading2(true)
      setError2(null)
    }

    try {
      const response = await axios.post(`${API_URL}/api/stocks/info`, { symbol })
      if (slot === 1) {
        setStock1(response.data)
        setStock1Symbol(symbol)
      } else {
        setStock2(response.data)
        setStock2Symbol(symbol)
      }
    } catch (err) {
      const errorMsg = `Failed to load ${symbol}`
      if (slot === 1) {
        setError1(errorMsg)
        setStock1(null)
      } else {
        setError2(errorMsg)
        setStock2(null)
      }
    } finally {
      if (slot === 1) setLoading1(false)
      else setLoading2(false)
    }
  }

  const handleSearchChange = (value: string, slot: 1 | 2) => {
    if (slot === 1) {
      setSearchInput1(value)
      if (value.trim().length > 0) {
        const filtered = stockDirectory.filter(stock =>
          stock.symbol.toLowerCase().includes(value.toLowerCase()) ||
          stock.name.toLowerCase().includes(value.toLowerCase())
        ).slice(0, 6)
        setSuggestions1(filtered)
        setShowSuggestions1(true)
      } else {
        setSuggestions1([])
        setShowSuggestions1(false)
      }
    } else {
      setSearchInput2(value)
      if (value.trim().length > 0) {
        const filtered = stockDirectory.filter(stock =>
          stock.symbol.toLowerCase().includes(value.toLowerCase()) ||
          stock.name.toLowerCase().includes(value.toLowerCase())
        ).slice(0, 6)
        setSuggestions2(filtered)
        setShowSuggestions2(true)
      } else {
        setSuggestions2([])
        setShowSuggestions2(false)
      }
    }
  }

  const handleSelectStock = (symbol: string, slot: 1 | 2) => {
    if (slot === 1) {
      setSearchInput1(symbol)
      setShowSuggestions1(false)
      loadStock(symbol, 1)
    } else {
      setSearchInput2(symbol)
      setShowSuggestions2(false)
      loadStock(symbol, 2)
    }
  }

  const handleSearchSubmit = (e: React.FormEvent, slot: 1 | 2) => {
    e.preventDefault()
    const value = slot === 1 ? searchInput1 : searchInput2
    if (value.trim()) {
      handleSelectStock(value.toUpperCase(), slot)
    }
  }

  const formatNumber = (num: number, prefix: string = ''): string => {
    if (!num && num !== 0) return 'N/A'
    if (num >= 1e12) return `${prefix}${(num / 1e12).toFixed(2)}T`
    if (num >= 1e9) return `${prefix}${(num / 1e9).toFixed(2)}B`
    if (num >= 1e6) return `${prefix}${(num / 1e6).toFixed(2)}M`
    if (num >= 1e3) return `${prefix}${(num / 1e3).toFixed(2)}K`
    return `${prefix}${num.toFixed(2)}`
  }

  const getChangeIntensity = (changePercent: number): string => {
    const absChange = Math.abs(changePercent)
    const direction = changePercent >= 0 ? 'positive' : 'negative'
    if (absChange >= 5) return `${direction} intensity-extreme`
    if (absChange >= 3) return `${direction} intensity-high`
    if (absChange >= 1.5) return `${direction} intensity-medium`
    if (absChange >= 0.5) return `${direction} intensity-low`
    return `${direction} intensity-minimal`
  }

  // Prepare chart data - normalize prices to percentage change from start
  const getChartData = () => {
    if (!stock1?.history && !stock2?.history) return []

    const history1 = stock1?.history || []
    const history2 = stock2?.history || []
    const maxLength = Math.max(history1.length, history2.length)

    const startPrice1 = history1[0]?.Close || 1
    const startPrice2 = history2[0]?.Close || 1

    const data = []
    for (let i = 0; i < maxLength; i++) {
      const date = history1[i]?.Date || history2[i]?.Date
      const entry: Record<string, string | number> = {
        date: new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
      }

      if (history1[i]) {
        entry[stock1Symbol] = ((history1[i].Close - startPrice1) / startPrice1) * 100
      }
      if (history2[i]) {
        entry[stock2Symbol] = ((history2[i].Close - startPrice2) / startPrice2) * 100
      }

      data.push(entry)
    }
    return data
  }

  const chartData = getChartData()

  const compareMetric = (val1: number | undefined, val2: number | undefined, higherIsBetter: boolean = true) => {
    if (val1 === undefined || val2 === undefined || val1 === null || val2 === null) return { winner1: false, winner2: false }
    if (val1 === val2) return { winner1: false, winner2: false }
    const winner1 = higherIsBetter ? val1 > val2 : val1 < val2
    return { winner1, winner2: !winner1 }
  }

  const ComparisonRow = ({
    label,
    value1,
    value2,
    format = 'default',
    higherIsBetter = true
  }: {
    label: string
    value1: number | string | undefined
    value2: number | string | undefined
    format?: 'currency' | 'percent' | 'number' | 'default'
    higherIsBetter?: boolean
  }) => {
    const numVal1 = typeof value1 === 'number' ? value1 : undefined
    const numVal2 = typeof value2 === 'number' ? value2 : undefined
    const comparison = compareMetric(numVal1, numVal2, higherIsBetter)

    const formatValue = (val: number | string | undefined): string => {
      if (val === undefined || val === null) return 'N/A'
      if (typeof val === 'string') return val
      switch (format) {
        case 'currency':
          return formatNumber(val, '$')
        case 'percent':
          return `${val.toFixed(2)}%`
        case 'number':
          return formatNumber(val)
        default:
          return val.toFixed(2)
      }
    }

    return (
      <div className="comparison-row">
        <div className={`compare-value ${comparison.winner1 ? 'winner' : ''}`}>
          {formatValue(value1)}
          {comparison.winner1 && <span className="winner-badge">Better</span>}
        </div>
        <div className="compare-label">{label}</div>
        <div className={`compare-value ${comparison.winner2 ? 'winner' : ''}`}>
          {formatValue(value2)}
          {comparison.winner2 && <span className="winner-badge">Better</span>}
        </div>
      </div>
    )
  }

  return (
    <div className="stock-compare">
      <div className="compare-header">
        <h2>Compare Stocks</h2>
        <button className="close-compare-btn" onClick={onClose}>
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"/>
            <line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
      </div>

      {/* Stock Selectors */}
      <div className="compare-selectors">
        <div className="stock-selector">
          <form onSubmit={(e) => handleSearchSubmit(e, 1)} className="selector-form">
            <div className="selector-input-container">
              <input
                type="text"
                placeholder="Enter first stock symbol..."
                value={searchInput1}
                onChange={(e) => handleSearchChange(e.target.value, 1)}
                onFocus={() => suggestions1.length > 0 && setShowSuggestions1(true)}
                onBlur={() => setTimeout(() => setShowSuggestions1(false), 200)}
                className="selector-input"
              />
              {showSuggestions1 && suggestions1.length > 0 && (
                <div className="selector-suggestions">
                  {suggestions1.map((s) => (
                    <div
                      key={s.symbol}
                      className="selector-suggestion"
                      onMouseDown={() => handleSelectStock(s.symbol, 1)}
                    >
                      <span className="suggestion-symbol">{s.symbol}</span>
                      <span className="suggestion-name">{s.name}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
            <button type="submit" className="selector-btn">Load</button>
          </form>
        </div>

        <div className="vs-badge">VS</div>

        <div className="stock-selector">
          <form onSubmit={(e) => handleSearchSubmit(e, 2)} className="selector-form">
            <div className="selector-input-container">
              <input
                type="text"
                placeholder="Enter second stock symbol..."
                value={searchInput2}
                onChange={(e) => handleSearchChange(e.target.value, 2)}
                onFocus={() => suggestions2.length > 0 && setShowSuggestions2(true)}
                onBlur={() => setTimeout(() => setShowSuggestions2(false), 200)}
                className="selector-input"
              />
              {showSuggestions2 && suggestions2.length > 0 && (
                <div className="selector-suggestions">
                  {suggestions2.map((s) => (
                    <div
                      key={s.symbol}
                      className="selector-suggestion"
                      onMouseDown={() => handleSelectStock(s.symbol, 2)}
                    >
                      <span className="suggestion-symbol">{s.symbol}</span>
                      <span className="suggestion-name">{s.name}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
            <button type="submit" className="selector-btn">Load</button>
          </form>
        </div>
      </div>

      {/* Stock Headers */}
      {(stock1 || stock2 || loading1 || loading2) && (
        <div className="compare-stock-headers">
          <div className="stock-header-card">
            {loading1 ? (
              <div className="stock-header-skeleton">
                <SkeletonPulse className="skeleton-name" />
                <SkeletonPulse className="skeleton-price" />
                <SkeletonPulse className="skeleton-change" />
              </div>
            ) : stock1 ? (
              <div className="stock-header-content" onClick={() => onSelectStock(stock1.symbol)}>
                <div className="stock-name-symbol">
                  <h3>{stock1.symbol}</h3>
                  <span className="stock-name">{stock1.name}</span>
                </div>
                <div className="stock-price-info">
                  <div className="stock-price">${stock1.price.toFixed(2)}</div>
                  <div className={`stock-change ${getChangeIntensity(stock1.changePercent)}`}>
                    {stock1.change >= 0 ? '+' : ''}{stock1.change.toFixed(2)} ({stock1.changePercent >= 0 ? '+' : ''}{stock1.changePercent.toFixed(2)}%)
                  </div>
                </div>
              </div>
            ) : error1 ? (
              <div className="stock-error">{error1}</div>
            ) : (
              <div className="stock-placeholder">Select first stock</div>
            )}
          </div>

          <div className="stock-header-card">
            {loading2 ? (
              <div className="stock-header-skeleton">
                <SkeletonPulse className="skeleton-name" />
                <SkeletonPulse className="skeleton-price" />
                <SkeletonPulse className="skeleton-change" />
              </div>
            ) : stock2 ? (
              <div className="stock-header-content" onClick={() => onSelectStock(stock2.symbol)}>
                <div className="stock-name-symbol">
                  <h3>{stock2.symbol}</h3>
                  <span className="stock-name">{stock2.name}</span>
                </div>
                <div className="stock-price-info">
                  <div className="stock-price">${stock2.price.toFixed(2)}</div>
                  <div className={`stock-change ${getChangeIntensity(stock2.changePercent)}`}>
                    {stock2.change >= 0 ? '+' : ''}{stock2.change.toFixed(2)} ({stock2.changePercent >= 0 ? '+' : ''}{stock2.changePercent.toFixed(2)}%)
                  </div>
                </div>
              </div>
            ) : error2 ? (
              <div className="stock-error">{error2}</div>
            ) : (
              <div className="stock-placeholder">Select second stock</div>
            )}
          </div>
        </div>
      )}

      {/* Performance Chart */}
      {stock1 && stock2 && chartData.length > 0 && (
        <div className="compare-chart">
          <h3>Price Performance (% Change from Start)</h3>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a35" vertical={false} />
                <XAxis
                  dataKey="date"
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: '#6b7280', fontSize: 12 }}
                  dy={10}
                />
                <YAxis
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: '#6b7280', fontSize: 12 }}
                  tickFormatter={(value) => `${value.toFixed(0)}%`}
                  dx={-10}
                  width={50}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#1f1f28',
                    border: '1px solid #2a2a35',
                    borderRadius: '8px',
                    boxShadow: '0 4px 12px rgba(0, 0, 0, 0.3)'
                  }}
                  labelStyle={{ color: '#9ca3af', marginBottom: '8px' }}
                  formatter={(value: number, name: string) => [`${value.toFixed(2)}%`, name]}
                />
                <Legend />
                <Line
                  type="monotone"
                  dataKey={stock1Symbol}
                  stroke="#3b82f6"
                  strokeWidth={2}
                  dot={false}
                  activeDot={{ r: 6, fill: '#3b82f6', stroke: '#fff', strokeWidth: 2 }}
                />
                <Line
                  type="monotone"
                  dataKey={stock2Symbol}
                  stroke="#f59e0b"
                  strokeWidth={2}
                  dot={false}
                  activeDot={{ r: 6, fill: '#f59e0b', stroke: '#fff', strokeWidth: 2 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* Comparison Table */}
      {stock1 && stock2 && (
        <div className="compare-metrics">
          <h3>Key Metrics Comparison</h3>
          <div className="comparison-table">
            <div className="comparison-header">
              <div className="compare-value header">{stock1.symbol}</div>
              <div className="compare-label header">Metric</div>
              <div className="compare-value header">{stock2.symbol}</div>
            </div>

            <ComparisonRow
              label="Price"
              value1={stock1.price}
              value2={stock2.price}
              format="currency"
              higherIsBetter={true}
            />
            <ComparisonRow
              label="Day Change"
              value1={stock1.changePercent}
              value2={stock2.changePercent}
              format="percent"
              higherIsBetter={true}
            />
            <ComparisonRow
              label="Market Cap"
              value1={stock1.marketCap}
              value2={stock2.marketCap}
              format="currency"
              higherIsBetter={true}
            />
            <ComparisonRow
              label="Volume"
              value1={stock1.volume}
              value2={stock2.volume}
              format="number"
              higherIsBetter={true}
            />
            <ComparisonRow
              label="Avg Volume"
              value1={stock1.avgVolume}
              value2={stock2.avgVolume}
              format="number"
              higherIsBetter={true}
            />
            <ComparisonRow
              label="P/E Ratio"
              value1={stock1.peRatio}
              value2={stock2.peRatio}
              format="default"
              higherIsBetter={false}
            />
            <ComparisonRow
              label="Dividend Yield"
              value1={stock1.dividendYield ? stock1.dividendYield * 100 : undefined}
              value2={stock2.dividendYield ? stock2.dividendYield * 100 : undefined}
              format="percent"
              higherIsBetter={true}
            />
            <ComparisonRow
              label="52W High"
              value1={stock1.fiftyTwoWeekHigh}
              value2={stock2.fiftyTwoWeekHigh}
              format="currency"
              higherIsBetter={true}
            />
            <ComparisonRow
              label="52W Low"
              value1={stock1.fiftyTwoWeekLow}
              value2={stock2.fiftyTwoWeekLow}
              format="currency"
              higherIsBetter={false}
            />
            <div className="comparison-row text-row">
              <div className="compare-value">{stock1.sector}</div>
              <div className="compare-label">Sector</div>
              <div className="compare-value">{stock2.sector}</div>
            </div>
            <div className="comparison-row text-row">
              <div className="compare-value">{stock1.industry}</div>
              <div className="compare-label">Industry</div>
              <div className="compare-value">{stock2.industry}</div>
            </div>
          </div>
        </div>
      )}

      {/* Empty State */}
      {!stock1 && !stock2 && !loading1 && !loading2 && (
        <div className="compare-empty">
          <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
            <line x1="18" y1="20" x2="18" y2="10"/>
            <line x1="12" y1="20" x2="12" y2="4"/>
            <line x1="6" y1="20" x2="6" y2="14"/>
          </svg>
          <h3>Compare Two Stocks</h3>
          <p>Enter stock symbols above to see a side-by-side comparison of key metrics and performance.</p>
        </div>
      )}
    </div>
  )
}

export default StockCompare
