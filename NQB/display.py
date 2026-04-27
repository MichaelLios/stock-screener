"""
NQB Trading Bot — Rich terminal display
"""

from datetime import datetime
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text
from rich import box
from signals import TradeSignal

console = Console()


_SIGNAL_COLORS = {
    "STRONG BUY":  "bold bright_green",
    "BUY":         "green",
    "NEUTRAL":     "yellow",
    "SELL":        "red",
    "STRONG SELL": "bold bright_red",
}

_DIRECTION_ICONS = {
    "BULL":    "[green]▲[/green]",
    "BEAR":    "[red]▼[/red]",
    "NEUTRAL": "[yellow]─[/yellow]",
}


def _signal_text(signal: str) -> Text:
    color = _SIGNAL_COLORS.get(signal, "white")
    t = Text(f"  {signal}  ", style=color)
    return t


def print_header():
    console.rule("[bold cyan]NQB — Nasdaq-100 Futures Trading Bot[/bold cyan]")
    console.print(f"[dim]Scan time: {datetime.now().strftime('%Y-%m-%d  %H:%M:%S')}[/dim]\n")


def print_signal(sig: TradeSignal, show_votes: bool = True):
    color = _SIGNAL_COLORS.get(sig.signal, "white")

    # ── Summary panel ────────────────────────────────────────────────────────
    lines = []
    lines.append(f"[bold]Price:[/bold]  {sig.price:,.2f}")
    lines.append(f"[bold]Signal:[/bold] [{color}]{sig.signal}[/{color}]")
    lines.append(f"[bold]Bull score:[/bold] [green]{sig.bull_score:.1f}[/green]  |  "
                 f"[bold]Bear score:[/bold] [red]{sig.bear_score:.1f}[/red]")
    if sig.atr:
        lines.append(f"[bold]ATR({14}):[/bold] {sig.atr:,.1f} pts")
    if sig.stop_loss and sig.target:
        direction = "Long" if "BUY" in sig.signal else "Short"
        lines.append(
            f"[bold]{direction} idea:[/bold]  "
            f"Entry [cyan]{sig.price:,.1f}[/cyan]  "
            f"Stop [red]{sig.stop_loss:,.1f}[/red]  "
            f"Target [green]{sig.target:,.1f}[/green]  "
            f"R:R [yellow]{sig.risk_reward:.1f}x[/yellow]"
        )

    console.print(Panel(
        "\n".join(lines),
        title=f"[bold]{sig.timeframe_label}[/bold]",
        border_style=color,
        expand=False,
    ))

    # ── Vote table ───────────────────────────────────────────────────────────
    if show_votes and sig.votes:
        tbl = Table(box=box.SIMPLE, show_header=True, header_style="bold dim")
        tbl.add_column("Indicator",  style="cyan",   no_wrap=True, min_width=14)
        tbl.add_column("Signal",     style="",       no_wrap=True, min_width=8)
        tbl.add_column("Strength",   style="",       no_wrap=True, min_width=8)
        tbl.add_column("Note",       style="dim",    no_wrap=False)

        for v in sig.votes:
            icon     = _DIRECTION_ICONS.get(v.direction, "─")
            dir_col  = "green" if v.direction == "BULL" else ("red" if v.direction == "BEAR" else "yellow")
            strength = f"[{dir_col}]{'█' * round(v.strength * 10):<10}[/{dir_col}] {v.strength * 100:.0f}%"
            tbl.add_row(v.name, f"{icon} [{dir_col}]{v.direction}[/{dir_col}]", strength, v.note)

        console.print(tbl)

    console.print()


def print_multi_timeframe_summary(signals: list[TradeSignal]):
    """Print a compact MTF overview table."""
    tbl = Table(
        title="[bold]Multi-Timeframe Summary[/bold]",
        box=box.ROUNDED,
        show_header=True,
        header_style="bold white",
    )
    tbl.add_column("Timeframe",   style="cyan",  no_wrap=True)
    tbl.add_column("Price",       style="white", no_wrap=True, justify="right")
    tbl.add_column("Signal",      style="",      no_wrap=True)
    tbl.add_column("Bull",        style="green", no_wrap=True, justify="right")
    tbl.add_column("Bear",        style="red",   no_wrap=True, justify="right")
    tbl.add_column("ATR",         style="dim",   no_wrap=True, justify="right")
    tbl.add_column("R:R",         style="yellow",no_wrap=True, justify="right")

    for sig in signals:
        color = _SIGNAL_COLORS.get(sig.signal, "white")
        tbl.add_row(
            sig.timeframe_label,
            f"{sig.price:,.1f}",
            f"[{color}]{sig.signal}[/{color}]",
            f"{sig.bull_score:.0f}",
            f"{sig.bear_score:.0f}",
            f"{sig.atr:,.1f}" if sig.atr else "—",
            f"{sig.risk_reward:.1f}x" if sig.risk_reward else "—",
        )

    console.print(tbl)
    console.print()
