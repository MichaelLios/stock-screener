import { useState, useEffect } from 'react'
import axios from 'axios'
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid
} from 'recharts'
import FundamentalsDashboard from './FundamentalsDashboard'
import './StockDetail.css'

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
  description: string
  history: Array<{
    Date: string
    Open: number
    High: number
    Low: number
    Close: number
    Volume: number
  }>
}

interface NewsArticle {
  title: string
  publisher: string
  link: string
  publishedAt: number
  type: string
  thumbnail: string
  relatedTickers: string[]
}

interface Props {
  symbol: string
  isInWatchlist: boolean
  onAddToWatchlist: () => void
  onRemoveFromWatchlist: () => void
}

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

// Skeleton Components
function SkeletonPulse({ className }: { className?: string }) {
  return <div className={`skeleton-pulse ${className || ''}`} />
}

function StockDetailSkeleton() {
  return (
    <div className="stock-detail">
      {/* Header Skeleton */}
      <div className="stock-header">
        <div className="stock-title">
          <SkeletonPulse className="skeleton-title" />
          <SkeletonPulse className="skeleton-symbol" />
        </div>
        <div className="stock-price-section">
          <SkeletonPulse className="skeleton-price" />
          <SkeletonPulse className="skeleton-change" />
        </div>
      </div>

      {/* Chart Skeleton */}
      <div className="stock-chart">
        <SkeletonPulse className="skeleton-chart-title" />
        <SkeletonPulse className="skeleton-chart" />
      </div>

      {/* Stats Skeleton */}
      <div className="stock-stats">
        <div className="stat-grid">
          {[...Array(9)].map((_, i) => (
            <div key={i} className="stat-item">
              <SkeletonPulse className="skeleton-stat-label" />
              <SkeletonPulse className="skeleton-stat-value" />
            </div>
          ))}
        </div>
      </div>

      {/* Description Skeleton */}
      <div className="stock-description">
        <SkeletonPulse className="skeleton-desc-title" />
        <SkeletonPulse className="skeleton-desc-line" />
        <SkeletonPulse className="skeleton-desc-line" />
        <SkeletonPulse className="skeleton-desc-line short" />
      </div>

      {/* History Table Skeleton */}
      <div className="stock-history">
        <SkeletonPulse className="skeleton-history-title" />
        <div className="skeleton-table">
          <div className="skeleton-table-header">
            {[...Array(7)].map((_, i) => (
              <SkeletonPulse key={i} className="skeleton-th" />
            ))}
          </div>
          {[...Array(5)].map((_, i) => (
            <div key={i} className="skeleton-table-row">
              {[...Array(7)].map((_, j) => (
                <SkeletonPulse key={j} className="skeleton-td" />
              ))}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function StockDetail({ symbol, isInWatchlist, onAddToWatchlist, onRemoveFromWatchlist }: Props) {
  const [stockInfo, setStockInfo] = useState<StockInfo | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [news, setNews] = useState<NewsArticle[]>([])
  const [loadingNews, setLoadingNews] = useState(true)

  useEffect(() => {
    const fetchStockInfo = async () => {
      setLoading(true)
      setError(null)

      try {
        const response = await axios.post(`${API_URL}/api/stocks/info`, {
          symbol
        })
        setStockInfo(response.data)
      } catch (err) {
        setError('Failed to fetch stock information.')
        console.error(err)
      } finally {
        setLoading(false)
      }
    }

    const fetchNews = async () => {
      setLoadingNews(true)
      try {
        const response = await axios.get(`${API_URL}/api/stocks/news/${symbol}`)
        setNews(response.data.news || [])
      } catch (err) {
        console.error('Failed to fetch news:', err)
        setNews([])
      } finally {
        setLoadingNews(false)
      }
    }

    fetchStockInfo()
    fetchNews()
  }, [symbol])

  const formatNumber = (num: number, prefix: string = ''): string => {
    if (num >= 1e12) return `${prefix}${(num / 1e12).toFixed(2)}T`
    if (num >= 1e9) return `${prefix}${(num / 1e9).toFixed(2)}B`
    if (num >= 1e6) return `${prefix}${(num / 1e6).toFixed(2)}M`
    if (num >= 1e3) return `${prefix}${(num / 1e3).toFixed(2)}K`
    return `${prefix}${num.toFixed(2)}`
  }

  const formatTimeAgo = (timestamp: number): string => {
    const seconds = Math.floor((Date.now() - timestamp * 1000) / 1000)

    if (seconds < 60) return 'just now'
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`
    if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`
    return new Date(timestamp * 1000).toLocaleDateString()
  }

  if (loading) {
    return <StockDetailSkeleton />
  }

  if (error || !stockInfo) {
    return <div className="error-message">{error || 'Stock not found'}</div>
  }

  const changeSymbol = stockInfo.change >= 0 ? '+' : ''

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

  const changeClass = getChangeIntensity(stockInfo.changePercent)

  // Prepare chart data
  const chartData = stockInfo.history?.map((day) => ({
    date: new Date(day.Date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
    price: day.Close,
    open: day.Open,
    high: day.High,
    low: day.Low,
    volume: day.Volume
  })) || []

  // Determine chart color based on overall trend
  const isPositiveTrend = chartData.length > 1 &&
    chartData[chartData.length - 1].price >= chartData[0].price
  const chartColor = isPositiveTrend ? '#10b981' : '#ef4444'
  const chartGradientId = `colorPrice-${symbol}`

  // Calculate price range for Y-axis
  const prices = chartData.map(d => d.price)
  const minPrice = Math.min(...prices) * 0.995
  const maxPrice = Math.max(...prices) * 1.005

  return (
    <div className="stock-detail">
      <div className="stock-header">
        <div className="stock-title">
          <h2>{stockInfo.name}</h2>
          <p className="symbol">{stockInfo.symbol}</p>
        </div>
        <div className="stock-header-right">
          <div className="stock-price-section">
            <div className="current-price">${stockInfo.price.toFixed(2)}</div>
            <div className={`price-change ${changeClass}`}>
              {changeSymbol}${stockInfo.change.toFixed(2)} ({changeSymbol}{stockInfo.changePercent.toFixed(2)}%)
            </div>
          </div>
          <button
            className={`watchlist-button ${isInWatchlist ? 'in-watchlist' : ''}`}
            onClick={isInWatchlist ? onRemoveFromWatchlist : onAddToWatchlist}
          >
            {isInWatchlist ? (
              <>
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
                </svg>
                <span>In Watchlist</span>
              </>
            ) : (
              <>
                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/>
                </svg>
                <span>Add to Watchlist</span>
              </>
            )}
          </button>
        </div>
      </div>

      {chartData.length > 0 && (
        <div className="stock-chart">
          <h3>Price History (Last Month)</h3>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height={300}>
              <AreaChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id={chartGradientId} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={chartColor} stopOpacity={0.3} />
                    <stop offset="95%" stopColor={chartColor} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#2a2a35" vertical={false} />
                <XAxis
                  dataKey="date"
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: '#6b7280', fontSize: 12 }}
                  dy={10}
                />
                <YAxis
                  domain={[minPrice, maxPrice]}
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: '#6b7280', fontSize: 12 }}
                  tickFormatter={(value) => `$${value.toFixed(0)}`}
                  dx={-10}
                  width={60}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: '#1f1f28',
                    border: '1px solid #2a2a35',
                    borderRadius: '8px',
                    boxShadow: '0 4px 12px rgba(0, 0, 0, 0.3)'
                  }}
                  labelStyle={{ color: '#9ca3af', marginBottom: '8px' }}
                  itemStyle={{ color: '#fff' }}
                  formatter={(value: number) => [`$${value.toFixed(2)}`, 'Price']}
                />
                <Area
                  type="monotone"
                  dataKey="price"
                  stroke={chartColor}
                  strokeWidth={2}
                  fill={`url(#${chartGradientId})`}
                  dot={false}
                  activeDot={{ r: 6, fill: chartColor, stroke: '#fff', strokeWidth: 2 }}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      <div className="stock-stats">
        {/* 52-Week Range Bar */}
        {stockInfo.fiftyTwoWeekLow > 0 && stockInfo.fiftyTwoWeekHigh > 0 && (
          <div className="range-bar-section">
            <h4>52-Week Range</h4>
            <div className="range-bar-container">
              <span className="range-label range-low">${stockInfo.fiftyTwoWeekLow.toFixed(2)}</span>
              <div className="range-bar">
                <div className="range-bar-track">
                  <div
                    className="range-bar-fill"
                    style={{
                      width: `${Math.min(100, Math.max(0, ((stockInfo.price - stockInfo.fiftyTwoWeekLow) / (stockInfo.fiftyTwoWeekHigh - stockInfo.fiftyTwoWeekLow)) * 100))}%`
                    }}
                  />
                  <div
                    className="range-bar-marker"
                    style={{
                      left: `${Math.min(100, Math.max(0, ((stockInfo.price - stockInfo.fiftyTwoWeekLow) / (stockInfo.fiftyTwoWeekHigh - stockInfo.fiftyTwoWeekLow)) * 100))}%`
                    }}
                  >
                    <div className="range-bar-tooltip">
                      ${stockInfo.price.toFixed(2)}
                    </div>
                  </div>
                </div>
              </div>
              <span className="range-label range-high">${stockInfo.fiftyTwoWeekHigh.toFixed(2)}</span>
            </div>
            <div className="range-bar-info">
              {(() => {
                const position = ((stockInfo.price - stockInfo.fiftyTwoWeekLow) / (stockInfo.fiftyTwoWeekHigh - stockInfo.fiftyTwoWeekLow)) * 100
                const fromLow = ((stockInfo.price - stockInfo.fiftyTwoWeekLow) / stockInfo.fiftyTwoWeekLow * 100).toFixed(1)
                const fromHigh = ((stockInfo.fiftyTwoWeekHigh - stockInfo.price) / stockInfo.fiftyTwoWeekHigh * 100).toFixed(1)
                return (
                  <>
                    <span className={position > 50 ? 'positive' : 'negative'}>
                      {position.toFixed(0)}% of 52-week range
                    </span>
                    <span className="range-details">
                      +{fromLow}% from low | -{fromHigh}% from high
                    </span>
                  </>
                )
              })()}
            </div>
          </div>
        )}

        <div className="stat-grid">
          <div className="stat-item">
            <span className="stat-label">Market Cap</span>
            <span className="stat-value">{formatNumber(stockInfo.marketCap, '$')}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Volume</span>
            <span className="stat-value">{formatNumber(stockInfo.volume)}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Avg Volume</span>
            <span className="stat-value">{formatNumber(stockInfo.avgVolume)}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">P/E Ratio</span>
            <span className="stat-value">{stockInfo.peRatio?.toFixed(2) ?? 'N/A'}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Dividend Yield</span>
            <span className="stat-value">
              {stockInfo.dividendYield ? (stockInfo.dividendYield * 100).toFixed(2) + '%' : 'N/A'}
            </span>
          </div>
          <div className="stat-item">
            <span className="stat-label">52 Week High</span>
            <span className="stat-value">${stockInfo.fiftyTwoWeekHigh.toFixed(2)}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">52 Week Low</span>
            <span className="stat-value">${stockInfo.fiftyTwoWeekLow.toFixed(2)}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Sector</span>
            <span className="stat-value">{stockInfo.sector}</span>
          </div>
          <div className="stat-item">
            <span className="stat-label">Industry</span>
            <span className="stat-value">{stockInfo.industry}</span>
          </div>
        </div>
      </div>

      {stockInfo.description && stockInfo.description !== 'N/A' && (
        <div className="stock-description">
          <h3>About {stockInfo.name}</h3>
          <p>{stockInfo.description}</p>
        </div>
      )}

      {/* Fundamental Analysis Dashboard */}
      <FundamentalsDashboard symbol={symbol} />

      {stockInfo.history && stockInfo.history.length > 0 && (
        <div className="stock-history">
          <h3>Recent Price History (Last 10 Days)</h3>
          <div className="history-table-container">
            <table className="history-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Open</th>
                  <th>High</th>
                  <th>Low</th>
                  <th>Close</th>
                  <th>Change</th>
                  <th>Volume</th>
                </tr>
              </thead>
              <tbody>
                {stockInfo.history.slice(-10).reverse().map((day, index) => {
                  const dayChange = ((day.Close - day.Open) / day.Open) * 100
                  const dayIntensity = getChangeIntensity(dayChange)
                  return (
                    <tr key={index} className={`history-row ${dayIntensity}`}>
                      <td>{new Date(day.Date).toLocaleDateString()}</td>
                      <td>${day.Open.toFixed(2)}</td>
                      <td className="high-cell">${day.High.toFixed(2)}</td>
                      <td className="low-cell">${day.Low.toFixed(2)}</td>
                      <td className={`close-cell ${dayIntensity}`}>${day.Close.toFixed(2)}</td>
                      <td className={`change-cell ${dayIntensity}`}>
                        {dayChange >= 0 ? '+' : ''}{dayChange.toFixed(2)}%
                      </td>
                      <td>{formatNumber(day.Volume)}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* News Section */}
      <div className="stock-news">
        <h3>
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2"/>
            <path d="M18 14h-8"/>
            <path d="M15 18h-5"/>
            <path d="M10 6h8v4h-8V6Z"/>
          </svg>
          Latest News
        </h3>
        {loadingNews ? (
          <div className="news-loading">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="news-item-skeleton">
                <SkeletonPulse className="skeleton-news-title" />
                <SkeletonPulse className="skeleton-news-meta" />
              </div>
            ))}
          </div>
        ) : news.length > 0 ? (
          <div className="news-list">
            {news.map((article, index) => (
              <a
                key={index}
                href={article.link}
                target="_blank"
                rel="noopener noreferrer"
                className="news-item"
              >
                {article.thumbnail && (
                  <div className="news-thumbnail">
                    <img src={article.thumbnail} alt="" loading="lazy" />
                  </div>
                )}
                <div className="news-content">
                  <h4 className="news-title">{article.title}</h4>
                  <div className="news-meta">
                    <span className="news-publisher">{article.publisher}</span>
                    <span className="news-time">{formatTimeAgo(article.publishedAt)}</span>
                  </div>
                  {article.relatedTickers && article.relatedTickers.length > 1 && (
                    <div className="news-tickers">
                      {article.relatedTickers.slice(0, 5).map((ticker, i) => (
                        <span key={i} className="news-ticker">{ticker}</span>
                      ))}
                    </div>
                  )}
                </div>
                <div className="news-arrow">
                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
                    <polyline points="15 3 21 3 21 9"/>
                    <line x1="10" y1="14" x2="21" y2="3"/>
                  </svg>
                </div>
              </a>
            ))}
          </div>
        ) : (
          <div className="news-empty">
            <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2"/>
              <path d="M18 14h-8"/>
              <path d="M15 18h-5"/>
              <path d="M10 6h8v4h-8V6Z"/>
            </svg>
            <p>No recent news available for {stockInfo.symbol}</p>
          </div>
        )}
      </div>
    </div>
  )
}

export default StockDetail
