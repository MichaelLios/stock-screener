import { useState, useEffect } from 'react'
import axios from 'axios'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
  Legend,
  LineChart,
  Line
} from 'recharts'
import './FundamentalsDashboard.css'

interface FundamentalsData {
  symbol: string
  name: string
  valuation: {
    marketCap: number
    enterpriseValue: number
    trailingPE: number | null
    forwardPE: number | null
    pegRatio: number | null
    priceToBook: number | null
    priceToSales: number | null
    enterpriseToRevenue: number | null
    enterpriseToEbitda: number | null
  }
  profitability: {
    profitMargin: number | null
    operatingMargin: number | null
    grossMargin: number | null
    returnOnAssets: number | null
    returnOnEquity: number | null
  }
  growth: {
    revenueGrowth: number | null
    earningsGrowth: number | null
    earningsQuarterlyGrowth: number | null
  }
  financialHealth: {
    totalCash: number
    totalCashPerShare: number | null
    totalDebt: number
    debtToEquity: number | null
    currentRatio: number | null
    quickRatio: number | null
  }
  perShare: {
    trailingEps: number | null
    forwardEps: number | null
    bookValue: number | null
    revenuePerShare: number | null
    freeCashflow: number | null
  }
  dividend: {
    dividendRate: number | null
    dividendYield: number | null
    payoutRatio: number | null
    exDividendDate: number | null
    lastDividendValue: number | null
  }
  incomeHistory: {
    dates: string[]
    totalRevenue: number[]
    grossProfit: number[]
    operatingIncome: number[]
    netIncome: number[]
    ebitda: number[]
  }
  balanceSheetHistory: {
    dates: string[]
    totalAssets: number[]
    totalLiabilities: number[]
    totalEquity: number[]
    totalDebt: number[]
    cash: number[]
  }
  cashFlowHistory: {
    dates: string[]
    operatingCashFlow: number[]
    freeCashFlow: number[]
    capitalExpenditures: number[]
  }
  analystTargets: {
    targetHigh: number | null
    targetLow: number | null
    targetMean: number | null
    targetMedian: number | null
    recommendationMean: number | null
    recommendationKey: string | null
    numberOfAnalysts: number | null
  }
}

interface Props {
  symbol: string
}

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

function FundamentalsDashboard({ symbol }: Props) {
  const [data, setData] = useState<FundamentalsData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<'overview' | 'income' | 'balance' | 'cashflow'>('overview')

  useEffect(() => {
    const fetchFundamentals = async () => {
      setLoading(true)
      setError(null)
      try {
        const response = await axios.get(`${API_URL}/api/stocks/fundamentals/${symbol}`)
        setData(response.data)
      } catch (err) {
        setError('Failed to load fundamental data')
        console.error(err)
      } finally {
        setLoading(false)
      }
    }

    fetchFundamentals()
  }, [symbol])

  const formatNumber = (num: number | null | undefined, prefix: string = ''): string => {
    if (num === null || num === undefined) return 'N/A'
    if (Math.abs(num) >= 1e12) return `${prefix}${(num / 1e12).toFixed(2)}T`
    if (Math.abs(num) >= 1e9) return `${prefix}${(num / 1e9).toFixed(2)}B`
    if (Math.abs(num) >= 1e6) return `${prefix}${(num / 1e6).toFixed(2)}M`
    if (Math.abs(num) >= 1e3) return `${prefix}${(num / 1e3).toFixed(2)}K`
    return `${prefix}${num.toFixed(2)}`
  }

  const formatPercent = (num: number | null | undefined): string => {
    if (num === null || num === undefined) return 'N/A'
    return `${(num * 100).toFixed(2)}%`
  }

  const formatRatio = (num: number | null | undefined): string => {
    if (num === null || num === undefined) return 'N/A'
    return num.toFixed(2)
  }

  const getGradeColor = (value: number | null, thresholds: { good: number; bad: number }, higherIsBetter = true): string => {
    if (value === null) return ''
    if (higherIsBetter) {
      if (value >= thresholds.good) return 'grade-good'
      if (value <= thresholds.bad) return 'grade-bad'
      return 'grade-neutral'
    } else {
      if (value <= thresholds.good) return 'grade-good'
      if (value >= thresholds.bad) return 'grade-bad'
      return 'grade-neutral'
    }
  }

  const getRecommendationColor = (key: string | null): string => {
    if (!key) return ''
    const lowerKey = key.toLowerCase()
    if (lowerKey.includes('buy') || lowerKey.includes('strong')) return 'rec-buy'
    if (lowerKey.includes('hold')) return 'rec-hold'
    if (lowerKey.includes('sell') || lowerKey.includes('under')) return 'rec-sell'
    return ''
  }

  if (loading) {
    return (
      <div className="fundamentals-dashboard">
        <div className="fundamentals-loading">
          <div className="loading-spinner"></div>
          <p>Loading fundamental data...</p>
        </div>
      </div>
    )
  }

  if (error || !data) {
    return (
      <div className="fundamentals-dashboard">
        <div className="fundamentals-error">
          <p>{error || 'Unable to load data'}</p>
        </div>
      </div>
    )
  }

  // Prepare chart data
  const incomeChartData = data.incomeHistory.dates.map((date, i) => ({
    date: date.substring(0, 4), // Just the year
    revenue: data.incomeHistory.totalRevenue[i] || 0,
    grossProfit: data.incomeHistory.grossProfit[i] || 0,
    netIncome: data.incomeHistory.netIncome[i] || 0,
  })).reverse()

  const balanceChartData = data.balanceSheetHistory.dates.map((date, i) => ({
    date: date.substring(0, 4),
    assets: data.balanceSheetHistory.totalAssets[i] || 0,
    liabilities: data.balanceSheetHistory.totalLiabilities[i] || 0,
    equity: data.balanceSheetHistory.totalEquity[i] || 0,
  })).reverse()

  const cashFlowChartData = data.cashFlowHistory.dates.map((date, i) => ({
    date: date.substring(0, 4),
    operating: data.cashFlowHistory.operatingCashFlow[i] || 0,
    freeCashFlow: data.cashFlowHistory.freeCashFlow[i] || 0,
    capex: Math.abs(data.cashFlowHistory.capitalExpenditures[i] || 0),
  })).reverse()

  // Margin trend data
  const marginTrendData = data.incomeHistory.dates.map((date, i) => {
    const revenue = data.incomeHistory.totalRevenue[i] || 1
    return {
      date: date.substring(0, 4),
      grossMargin: ((data.incomeHistory.grossProfit[i] || 0) / revenue) * 100,
      operatingMargin: ((data.incomeHistory.operatingIncome[i] || 0) / revenue) * 100,
      netMargin: ((data.incomeHistory.netIncome[i] || 0) / revenue) * 100,
    }
  }).reverse()

  return (
    <div className="fundamentals-dashboard">
      <div className="fundamentals-header">
        <h3>
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M3 3v18h18"/>
            <path d="m19 9-5 5-4-4-3 3"/>
          </svg>
          Fundamental Analysis
        </h3>
        <div className="tab-nav">
          <button
            className={`tab-button ${activeTab === 'overview' ? 'active' : ''}`}
            onClick={() => setActiveTab('overview')}
          >
            Overview
          </button>
          <button
            className={`tab-button ${activeTab === 'income' ? 'active' : ''}`}
            onClick={() => setActiveTab('income')}
          >
            Income
          </button>
          <button
            className={`tab-button ${activeTab === 'balance' ? 'active' : ''}`}
            onClick={() => setActiveTab('balance')}
          >
            Balance Sheet
          </button>
          <button
            className={`tab-button ${activeTab === 'cashflow' ? 'active' : ''}`}
            onClick={() => setActiveTab('cashflow')}
          >
            Cash Flow
          </button>
        </div>
      </div>

      {activeTab === 'overview' && (
        <div className="fundamentals-content">
          {/* Analyst Recommendations */}
          {data.analystTargets.recommendationKey && (
            <div className="analyst-section">
              <h4>Analyst Consensus</h4>
              <div className="analyst-card">
                <div className={`recommendation-badge ${getRecommendationColor(data.analystTargets.recommendationKey)}`}>
                  {data.analystTargets.recommendationKey?.toUpperCase()}
                </div>
                <div className="analyst-details">
                  <div className="target-prices">
                    <div className="target-item">
                      <span className="target-label">Low</span>
                      <span className="target-value">${data.analystTargets.targetLow?.toFixed(2) || 'N/A'}</span>
                    </div>
                    <div className="target-item highlight">
                      <span className="target-label">Average</span>
                      <span className="target-value">${data.analystTargets.targetMean?.toFixed(2) || 'N/A'}</span>
                    </div>
                    <div className="target-item">
                      <span className="target-label">High</span>
                      <span className="target-value">${data.analystTargets.targetHigh?.toFixed(2) || 'N/A'}</span>
                    </div>
                  </div>
                  <p className="analyst-count">
                    Based on {data.analystTargets.numberOfAnalysts || 0} analyst ratings
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* Key Metrics Grid */}
          <div className="metrics-grid">
            {/* Valuation */}
            <div className="metric-card">
              <h4>Valuation</h4>
              <div className="metric-list">
                <div className="metric-row">
                  <span className="metric-label">Market Cap</span>
                  <span className="metric-value">{formatNumber(data.valuation.marketCap, '$')}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Enterprise Value</span>
                  <span className="metric-value">{formatNumber(data.valuation.enterpriseValue, '$')}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">P/E (TTM)</span>
                  <span className={`metric-value ${getGradeColor(data.valuation.trailingPE, { good: 15, bad: 30 }, false)}`}>
                    {formatRatio(data.valuation.trailingPE)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Forward P/E</span>
                  <span className={`metric-value ${getGradeColor(data.valuation.forwardPE, { good: 12, bad: 25 }, false)}`}>
                    {formatRatio(data.valuation.forwardPE)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">PEG Ratio</span>
                  <span className={`metric-value ${getGradeColor(data.valuation.pegRatio, { good: 1, bad: 2 }, false)}`}>
                    {formatRatio(data.valuation.pegRatio)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Price/Book</span>
                  <span className="metric-value">{formatRatio(data.valuation.priceToBook)}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Price/Sales</span>
                  <span className="metric-value">{formatRatio(data.valuation.priceToSales)}</span>
                </div>
              </div>
            </div>

            {/* Profitability */}
            <div className="metric-card">
              <h4>Profitability</h4>
              <div className="metric-list">
                <div className="metric-row">
                  <span className="metric-label">Gross Margin</span>
                  <span className={`metric-value ${getGradeColor(data.profitability.grossMargin, { good: 0.4, bad: 0.2 })}`}>
                    {formatPercent(data.profitability.grossMargin)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Operating Margin</span>
                  <span className={`metric-value ${getGradeColor(data.profitability.operatingMargin, { good: 0.2, bad: 0.05 })}`}>
                    {formatPercent(data.profitability.operatingMargin)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Profit Margin</span>
                  <span className={`metric-value ${getGradeColor(data.profitability.profitMargin, { good: 0.15, bad: 0.03 })}`}>
                    {formatPercent(data.profitability.profitMargin)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Return on Assets</span>
                  <span className={`metric-value ${getGradeColor(data.profitability.returnOnAssets, { good: 0.1, bad: 0.03 })}`}>
                    {formatPercent(data.profitability.returnOnAssets)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Return on Equity</span>
                  <span className={`metric-value ${getGradeColor(data.profitability.returnOnEquity, { good: 0.2, bad: 0.08 })}`}>
                    {formatPercent(data.profitability.returnOnEquity)}
                  </span>
                </div>
              </div>
            </div>

            {/* Growth */}
            <div className="metric-card">
              <h4>Growth</h4>
              <div className="metric-list">
                <div className="metric-row">
                  <span className="metric-label">Revenue Growth (YoY)</span>
                  <span className={`metric-value ${getGradeColor(data.growth.revenueGrowth, { good: 0.15, bad: 0 })}`}>
                    {formatPercent(data.growth.revenueGrowth)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Earnings Growth</span>
                  <span className={`metric-value ${getGradeColor(data.growth.earningsGrowth, { good: 0.2, bad: 0 })}`}>
                    {formatPercent(data.growth.earningsGrowth)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Quarterly Earnings Growth</span>
                  <span className={`metric-value ${getGradeColor(data.growth.earningsQuarterlyGrowth, { good: 0.1, bad: -0.1 })}`}>
                    {formatPercent(data.growth.earningsQuarterlyGrowth)}
                  </span>
                </div>
              </div>
            </div>

            {/* Financial Health */}
            <div className="metric-card">
              <h4>Financial Health</h4>
              <div className="metric-list">
                <div className="metric-row">
                  <span className="metric-label">Total Cash</span>
                  <span className="metric-value">{formatNumber(data.financialHealth.totalCash, '$')}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Total Debt</span>
                  <span className="metric-value">{formatNumber(data.financialHealth.totalDebt, '$')}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Debt/Equity</span>
                  <span className={`metric-value ${getGradeColor(data.financialHealth.debtToEquity, { good: 50, bad: 150 }, false)}`}>
                    {formatRatio(data.financialHealth.debtToEquity)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Current Ratio</span>
                  <span className={`metric-value ${getGradeColor(data.financialHealth.currentRatio, { good: 2, bad: 1 })}`}>
                    {formatRatio(data.financialHealth.currentRatio)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Quick Ratio</span>
                  <span className={`metric-value ${getGradeColor(data.financialHealth.quickRatio, { good: 1.5, bad: 0.8 })}`}>
                    {formatRatio(data.financialHealth.quickRatio)}
                  </span>
                </div>
              </div>
            </div>

            {/* Per Share Data */}
            <div className="metric-card">
              <h4>Per Share Data</h4>
              <div className="metric-list">
                <div className="metric-row">
                  <span className="metric-label">EPS (TTM)</span>
                  <span className="metric-value">${data.perShare.trailingEps?.toFixed(2) || 'N/A'}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Forward EPS</span>
                  <span className="metric-value">${data.perShare.forwardEps?.toFixed(2) || 'N/A'}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Book Value</span>
                  <span className="metric-value">${data.perShare.bookValue?.toFixed(2) || 'N/A'}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Revenue/Share</span>
                  <span className="metric-value">${data.perShare.revenuePerShare?.toFixed(2) || 'N/A'}</span>
                </div>
              </div>
            </div>

            {/* Dividends */}
            <div className="metric-card">
              <h4>Dividends</h4>
              <div className="metric-list">
                <div className="metric-row">
                  <span className="metric-label">Dividend Rate</span>
                  <span className="metric-value">${data.dividend.dividendRate?.toFixed(2) || 'N/A'}</span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Dividend Yield</span>
                  <span className={`metric-value ${getGradeColor(data.dividend.dividendYield, { good: 0.03, bad: 0 })}`}>
                    {formatPercent(data.dividend.dividendYield)}
                  </span>
                </div>
                <div className="metric-row">
                  <span className="metric-label">Payout Ratio</span>
                  <span className={`metric-value ${getGradeColor(data.dividend.payoutRatio, { good: 0.5, bad: 0.8 }, false)}`}>
                    {formatPercent(data.dividend.payoutRatio)}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'income' && (
        <div className="fundamentals-content">
          <div className="chart-section">
            <h4>Revenue & Profitability Trend</h4>
            {incomeChartData.length > 0 ? (
              <div className="chart-container">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={incomeChartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#2a2a35" />
                    <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 12 }} />
                    <YAxis
                      tick={{ fill: '#6b7280', fontSize: 12 }}
                      tickFormatter={(value) => formatNumber(value)}
                    />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: '#1f1f28',
                        border: '1px solid #2a2a35',
                        borderRadius: '8px',
                      }}
                      formatter={(value: number) => [formatNumber(value, '$'), '']}
                    />
                    <Legend />
                    <Bar dataKey="revenue" name="Revenue" fill="#6366f1" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="grossProfit" name="Gross Profit" fill="#10b981" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="netIncome" name="Net Income" fill="#f59e0b" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="no-data">No income history available</div>
            )}
          </div>

          <div className="chart-section">
            <h4>Margin Trends</h4>
            {marginTrendData.length > 0 ? (
              <div className="chart-container">
                <ResponsiveContainer width="100%" height={250}>
                  <LineChart data={marginTrendData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#2a2a35" />
                    <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 12 }} />
                    <YAxis
                      tick={{ fill: '#6b7280', fontSize: 12 }}
                      tickFormatter={(value) => `${value.toFixed(0)}%`}
                    />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: '#1f1f28',
                        border: '1px solid #2a2a35',
                        borderRadius: '8px',
                      }}
                      formatter={(value: number) => [`${value.toFixed(2)}%`, '']}
                    />
                    <Legend />
                    <Line type="monotone" dataKey="grossMargin" name="Gross Margin" stroke="#10b981" strokeWidth={2} dot={{ r: 4 }} />
                    <Line type="monotone" dataKey="operatingMargin" name="Operating Margin" stroke="#6366f1" strokeWidth={2} dot={{ r: 4 }} />
                    <Line type="monotone" dataKey="netMargin" name="Net Margin" stroke="#f59e0b" strokeWidth={2} dot={{ r: 4 }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="no-data">No margin data available</div>
            )}
          </div>
        </div>
      )}

      {activeTab === 'balance' && (
        <div className="fundamentals-content">
          <div className="chart-section">
            <h4>Assets, Liabilities & Equity</h4>
            {balanceChartData.length > 0 ? (
              <div className="chart-container">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={balanceChartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#2a2a35" />
                    <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 12 }} />
                    <YAxis
                      tick={{ fill: '#6b7280', fontSize: 12 }}
                      tickFormatter={(value) => formatNumber(value)}
                    />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: '#1f1f28',
                        border: '1px solid #2a2a35',
                        borderRadius: '8px',
                      }}
                      formatter={(value: number) => [formatNumber(value, '$'), '']}
                    />
                    <Legend />
                    <Bar dataKey="assets" name="Total Assets" fill="#10b981" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="liabilities" name="Total Liabilities" fill="#ef4444" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="equity" name="Stockholders Equity" fill="#6366f1" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="no-data">No balance sheet history available</div>
            )}
          </div>

          {/* Debt vs Cash Comparison */}
          <div className="comparison-cards">
            <div className="comparison-card positive">
              <h5>Cash Position</h5>
              <div className="comparison-value">{formatNumber(data.financialHealth.totalCash, '$')}</div>
              <p>Cash per share: ${data.financialHealth.totalCashPerShare?.toFixed(2) || 'N/A'}</p>
            </div>
            <div className="comparison-card negative">
              <h5>Debt Position</h5>
              <div className="comparison-value">{formatNumber(data.financialHealth.totalDebt, '$')}</div>
              <p>Debt/Equity: {formatRatio(data.financialHealth.debtToEquity)}</p>
            </div>
            <div className={`comparison-card ${data.financialHealth.totalCash > data.financialHealth.totalDebt ? 'positive' : 'negative'}`}>
              <h5>Net Cash/Debt</h5>
              <div className="comparison-value">
                {formatNumber(data.financialHealth.totalCash - data.financialHealth.totalDebt, '$')}
              </div>
              <p>{data.financialHealth.totalCash > data.financialHealth.totalDebt ? 'Net Cash Position' : 'Net Debt Position'}</p>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'cashflow' && (
        <div className="fundamentals-content">
          <div className="chart-section">
            <h4>Cash Flow Trends</h4>
            {cashFlowChartData.length > 0 ? (
              <div className="chart-container">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={cashFlowChartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#2a2a35" />
                    <XAxis dataKey="date" tick={{ fill: '#6b7280', fontSize: 12 }} />
                    <YAxis
                      tick={{ fill: '#6b7280', fontSize: 12 }}
                      tickFormatter={(value) => formatNumber(value)}
                    />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: '#1f1f28',
                        border: '1px solid #2a2a35',
                        borderRadius: '8px',
                      }}
                      formatter={(value: number) => [formatNumber(value, '$'), '']}
                    />
                    <Legend />
                    <Bar dataKey="operating" name="Operating Cash Flow" fill="#10b981" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="freeCashFlow" name="Free Cash Flow" fill="#6366f1" radius={[4, 4, 0, 0]} />
                    <Bar dataKey="capex" name="Capital Expenditures" fill="#f59e0b" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="no-data">No cash flow history available</div>
            )}
          </div>

          {/* Free Cash Flow Card */}
          <div className="fcf-highlight">
            <h5>Free Cash Flow Analysis</h5>
            <div className="fcf-value">
              {formatNumber(data.perShare.freeCashflow, '$')}
            </div>
            <p className="fcf-description">
              Free cash flow represents cash generated after capital expenditures.
              Strong FCF indicates the company can fund growth, pay dividends, or reduce debt.
            </p>
          </div>
        </div>
      )}
    </div>
  )
}

export default FundamentalsDashboard
