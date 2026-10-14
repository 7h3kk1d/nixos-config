"""Summarize /var/log/wifi-drop into real drops, separating out sleep and resume.

A drop is a run of missed pings (ping -O "no answer yet", unreachable errors, or ping
exiting) lasting at least --min-seconds while the machine was awake and not in the
first --grace seconds after resume/boot, when Wi-Fi is still reconnecting.
Gaps with no log lines at all (the ping process frozen or not running) are counted as
asleep when SLEEP/RESUME markers cover them, and reported as unlogged otherwise.
"""
import argparse
import glob
import gzip
import os
import re
import time
from datetime import datetime

LINE = re.compile(r"^\[(\d+(?:\.\d+)?)\] (.*)$")
OK = re.compile(r"bytes from .*time=")
NEUTRAL = re.compile(r"^PING ")


def read_lines(pattern):
    for path in sorted(glob.glob(pattern)):
        opener = gzip.open if path.endswith(".gz") else open
        with opener(path, "rt", errors="replace") as f:
            for raw in f:
                m = LINE.match(raw.rstrip("\n"))
                if m:
                    yield float(m.group(1)), m.group(2)


def fmt(ts):
    return datetime.fromtimestamp(ts).strftime("%a %Y-%m-%d %H:%M:%S")


def dur(seconds):
    seconds = int(round(seconds))
    if seconds < 60:
        return f"{seconds}s"
    if seconds < 3600:
        return f"{seconds // 60}m{seconds % 60:02d}s"
    return f"{seconds // 3600}h{seconds % 3600 // 60:02d}m"


def parse_since(value):
    if value.endswith("d"):
        return time.time() - float(value[:-1]) * 86400
    if value.endswith("h"):
        return time.time() - float(value[:-1]) * 3600
    return datetime.fromisoformat(value).timestamp()


def load_events(log_dir, since):
    events = sorted((ts, msg) for ts, msg in read_lines(os.path.join(log_dir, "events.log*")) if ts >= since)
    sleeps, wakes, links, nm = [], [], [], []
    asleep_at = None
    for ts, msg in events:
        kind = msg.split(" ", 1)[0]
        if kind == "SLEEP":
            asleep_at = ts
        elif kind == "RESUME":
            if asleep_at is not None:
                sleeps.append((asleep_at, ts))
            asleep_at = None
            wakes.append(ts)
        elif kind == "START":
            wakes.append(ts)
        elif kind == "LINK":
            links.append((ts, msg[5:]))
        elif kind == "NM":
            nm.append((ts, msg[3:]))
    if asleep_at is not None:
        sleeps.append((asleep_at, time.time()))
    return sleeps, wakes, links, nm


def load_target(log_dir, name, since):
    samples = []
    for ts, msg in read_lines(os.path.join(log_dir, f"{name}.log*")):
        if ts < since or NEUTRAL.match(msg):
            continue
        samples.append((ts, bool(OK.search(msg))))
    samples.sort()
    return samples


def covered(start, end, intervals, slack=5):
    return any(s - slack <= start and end <= e + slack for s, e in intervals)


def analyze_target(samples, sleeps, gap):
    """Return (miss runs as (start, end), unlogged gaps as (start, end))."""
    runs, gaps = [], []
    run_start = last_miss = None
    prev = None
    for ts, ok in samples:
        if prev is not None and ts - prev > gap and not covered(prev, ts, sleeps):
            gaps.append((prev, ts))
        if ok:
            if run_start is not None:
                runs.append((run_start, ts))
                run_start = None
        else:
            if run_start is not None and ts - last_miss > gap:
                runs.append((run_start, last_miss + 1))
                run_start = None
            if run_start is None:
                run_start = ts
            last_miss = ts
        prev = ts
    if run_start is not None:
        runs.append((run_start, last_miss + 1))
    return runs, gaps


def merge(intervals, slack=2):
    out = []
    for s, e, names in sorted(intervals):
        if out and s <= out[-1][1] + slack:
            ps, pe, pn = out[-1]
            out[-1] = (ps, max(pe, e), pn | names)
        else:
            out.append((s, e, set(names)))
    return out


def last_before(items, ts):
    best = None
    for t, v in items:
        if t > ts:
            break
        best = v
    return best


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dir", default="/var/log/wifi-drop")
    p.add_argument("--since", default="7d", help="e.g. 7d, 12h, or 2026-10-14[T08:00] (default 7d)")
    p.add_argument("--min-seconds", type=float, default=3, help="ignore shorter blips (default 3)")
    p.add_argument("--grace", type=float, default=60, help="seconds after resume/boot to ignore (default 60)")
    p.add_argument("--gap", type=float, default=10, help="silence longer than this is a gap, not a drop (default 10)")
    p.add_argument("--targets", default="gw,inet", help="log names, gateway first (default gw,inet)")
    args = p.parse_args()

    since = parse_since(args.since)
    sleeps, wakes, links, nm = load_events(args.dir, since)
    names = args.targets.split(",")
    gw = names[0]

    drops, after_resume, unlogged = [], [], []
    first = last = None
    for name in names:
        samples = load_target(args.dir, name, since)
        if not samples:
            continue
        first = min(first or samples[0][0], samples[0][0])
        last = max(last or samples[-1][0], samples[-1][0])
        runs, gaps = analyze_target(samples, sleeps, args.gap)
        unlogged += [(s, e, {name}) for s, e in gaps]
        for s, e in runs:
            if e - s < args.min_seconds:
                continue
            if any(w <= s <= w + args.grace for w in wakes):
                after_resume.append((s, e, {name}))
            else:
                drops.append((s, e, {name}))

    if first is None:
        print(f"No ping logs in {args.dir} since {fmt(since)}.")
        return

    asleep = sum(min(e, last) - max(s, first) for s, e in sleeps if e > first and s < last)
    print(f"Window     {fmt(first)}  ->  {fmt(last)}  ({dur(last - first)})")
    print(f"Asleep     {dur(asleep)} across {len(sleeps)} sleeps")
    gaps_merged = merge(unlogged)
    if gaps_merged:
        print(f"Unlogged   {dur(sum(e - s for s, e, _ in gaps_merged))} in {len(gaps_merged)} gaps with no SLEEP marker (off, crashed, or marker missed)")
    print()

    incidents = merge(drops)
    print(f"DROPS ({len(incidents)}): awake, >= {args.min_seconds:g}s, outside the {args.grace:g}s after resume/boot")
    if not incidents:
        print("  none")
    for s, e, hit in incidents:
        where = "Wi-Fi/LAN: gateway unreachable" if gw in hit else "upstream: gateway OK, internet unreachable"
        link = last_before(links, s) or "?"
        events = [f"{fmt(t)[-8:]} {m}" for t, m in nm if s - 15 <= t <= e + 15]
        print(f"  {fmt(s)}  {dur(e - s):>7}  {where}")
        print(f"      link before: {link}")
        for ev in events:
            print(f"      NM {ev}")

    if after_resume:
        reconnect = merge(after_resume)
        times = sorted(e - s for s, e, _ in reconnect)
        print()
        print(f"Reconnects after resume/boot (excluded): {len(reconnect)}, median {dur(times[len(times) // 2])}, max {dur(times[-1])}")

    if gaps_merged:
        print()
        print("UNLOGGED GAPS")
        for s, e, _ in gaps_merged:
            print(f"  {fmt(s)}  {dur(e - s):>7}")


if __name__ == "__main__":
    main()
