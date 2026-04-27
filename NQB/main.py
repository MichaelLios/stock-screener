#!/usr/bin/env python3
"""
NQB — Nasdaq-100 Futures Trading Bot
=====================================
Usage:
  python main.py              # single scan, all timeframes
  python main.py --loop       # continuous scan every SCAN_INTERVAL seconds
  python main.py --tf scalp   # single timeframe: scalp | swing | trend
  python main.py --no-votes   # hide per-indicator breakdown
  python main.py --loop --tf scalp --no-votes
"""

import argparse
import time
import sys
import traceback

import config as cfg
import data
import indicators
import signals
import display


def scan(timeframe_key: str, show_votes: bool) -> None:
    tf = cfg.TIMEFRAMES[timeframe_key]
    display.console.print(f"[dim]Fetching {cfg.TICKER} {tf['label']} …[/dim]")

    df = data.fetch(interval=tf["interval"], period=tf["period"])
    if df is None or df.empty:
        display.console.print(f"[red]No data for {tf['label']}[/red]\n")
        return

    df = indicators.add_all(df)
    sig = signals.evaluate(df, tf["label"])
    display.print_signal(sig, show_votes=show_votes)


def scan_all(show_votes: bool) -> list:
    sigs = []
    for key, tf in cfg.TIMEFRAMES.items():
        display.console.print(f"[dim]Fetching {cfg.TICKER} {tf['label']} …[/dim]")
        df = data.fetch(interval=tf["interval"], period=tf["period"])
        if df is None or df.empty:
            display.console.print(f"[red]No data for {tf['label']}[/red]")
            continue
        df = indicators.add_all(df)
        sig = signals.evaluate(df, tf["label"])
        sigs.append(sig)

    if sigs:
        display.print_multi_timeframe_summary(sigs)
        if show_votes:
            for sig in sigs:
                display.print_signal(sig, show_votes=True)

    return sigs


def main():
    parser = argparse.ArgumentParser(
        description="NQB — Nasdaq-100 Futures Trading Bot",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--loop",     action="store_true",
                        help=f"Repeat every {cfg.SCAN_INTERVAL}s")
    parser.add_argument("--tf",       choices=list(cfg.TIMEFRAMES.keys()), default=None,
                        help="Restrict to a single timeframe")
    parser.add_argument("--no-votes", action="store_true",
                        help="Hide per-indicator vote table")
    args = parser.parse_args()

    show_votes = not args.no_votes

    if args.loop:
        display.console.print(
            f"[cyan]Loop mode — scanning every {cfg.SCAN_INTERVAL}s. Press Ctrl+C to stop.[/cyan]\n"
        )
        while True:
            try:
                display.print_header()
                if args.tf:
                    scan(args.tf, show_votes)
                else:
                    scan_all(show_votes)
                display.console.print(
                    f"[dim]Next scan in {cfg.SCAN_INTERVAL // 60}m {cfg.SCAN_INTERVAL % 60}s …[/dim]\n"
                )
                time.sleep(cfg.SCAN_INTERVAL)
            except KeyboardInterrupt:
                display.console.print("\n[yellow]Stopped.[/yellow]")
                sys.exit(0)
            except Exception:
                display.console.print("[red]Error during scan:[/red]")
                traceback.print_exc()
                time.sleep(30)
    else:
        display.print_header()
        if args.tf:
            scan(args.tf, show_votes)
        else:
            scan_all(show_votes)


if __name__ == "__main__":
    main()
