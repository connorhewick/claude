# Python Performance

Make Python code measurably faster and leaner — profiling first, then working down an
optimization hierarchy where higher levels dwarf the gains available at lower ones.

---

## Overview

Performance work fails most often not from picking the wrong fix, but from fixing the wrong thing
— optimizing code that was never the bottleneck, guided by intuition instead of a profiler. The
prime directive: **measure first, optimize second, measure again.** Gains cluster by level — an
algorithmic fix (O(n²) → O(n log n)) routinely dwarfs a micro-optimization by two or three orders
of magnitude, so work top-down through the hierarchy rather than reaching for the flashiest tool
first. Every optimization has a cost (readability, memory, a new dependency) — record the
trade-off, don't just ship the speedup silently.

## Core Concepts

**Profile before touching code.** `cProfile` for function-level hotspots, `line_profiler` for
line-level detail within a known-slow function, `tracemalloc`/`memory_profiler` for memory,
`py-spy` for sampling a running production process without instrumentation. Skipping this step
means optimizing based on a guess, which is wrong often enough to waste the effort.

**The optimization hierarchy — work top-down.** Algorithm and data-structure choice (10×–1000×
possible) dominates vectorization (10×–100×), which dominates caching (5×–50×), which dominates
native extensions and parallelism (2×–50×), which dominates micro-optimization (1.1×–3×). A
correctly-chosen data structure beats a cleverly-tuned loop over the wrong one every time.

**Data structure choice is often the whole fix.** `list` membership (`in`) is O(n); `set`/`dict`
membership is O(1). A `list.pop(0)` is O(n) (shifts everything); `collections.deque.popleft()` is
O(1). These are frequently the entire performance bug — no algorithm change needed, just the
right container for the access pattern actually used.

**Vectorize array-shaped work; never `iterrows()`.** NumPy/Pandas execute compiled, contiguous-
memory operations instead of per-element Python bytecode — 10×–100× on array-heavy code.
`DataFrame.iterrows()` is roughly 1000× slower than a vectorized column operation because it
materializes a Python object per row; `.apply()` with a Python lambda is similarly slow. Reach for
`np.where`/`np.select` for row-wise conditional logic instead of a loop.

**Memoize pure functions with a stated eviction policy.** `functools.lru_cache`/`cache` turn
repeated identical calls into O(1) lookups, but an unbounded cache is a memory leak in a long-lived
process — always set `maxsize` unless you've deliberately decided the input space is small and
finite.

**Generators trade materialization for streaming.** A generator expression or a `yield`-based
pipeline processes one item at a time, holding constant memory regardless of input size — the
right default for large files, streaming pipelines, or any data that doesn't need to be a list
twice. This is a memory-only win; it doesn't speed up total work, but it prevents OOMs and reduces
peak RSS.

**Parallelism means processes for CPU-bound work — or verified free-threading.** On a standard
(GIL) Python build, threads never parallelize CPU-bound bytecode — the GIL serializes it regardless
of thread count, so `ThreadPoolExecutor` on a CPU-bound function buys nothing. Use
`ProcessPoolExecutor`/`multiprocessing` for real parallelism there, paying the IPC/serialization
overhead consciously. Python 3.13 introduced an official free-threaded build option that has
continued stabilizing since, and on a *verified* free-threaded interpreter, threads genuinely
parallelize CPU-bound Python code — but that build still carries single-threaded overhead relative
to the standard build, and C extensions that assume GIL protection can misbehave without it. Don't
default to "use threads for CPU work now that free-threading exists" — confirm the interpreter
build (`sys._is_gil_enabled()`) and that every relevant extension supports it before choosing
threads over processes for CPU-bound code. This is the same trade-off `async-programming.md`
covers from the concurrency-model side; consult it for how free-threading interacts with `asyncio`.

**Memory reduction has a different lever set than speed.** `__slots__` removes the per-instance
`__dict__` (relevant at millions of instances), `array`/NumPy typed arrays beat lists of boxed
Python objects for homogeneous numeric data, and explicit `del` plus `gc.collect()` matters mainly
when circular references are suspected. None of these help wall-clock time directly — they exist
to avoid OOM and reduce baseline footprint.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Haven't measured yet | Profile first (`cProfile`/`line_profiler`/`py-spy`) | Optimizing a guess wastes effort; the actual bottleneck is often not where intuition points |
| Repeated `in` checks against a collection | `set`/`dict` | O(1) vs O(n) membership |
| FIFO/LIFO queue operations at scale | `collections.deque` | O(1) both ends vs O(n) for `list.pop(0)` |
| Element-wise loop over a NumPy array/DataFrame | Vectorized NumPy/Pandas operation | 10×–100× vs pure-Python iteration |
| Same pure-function call repeated with identical args | `functools.lru_cache(maxsize=...)` | O(1) lookup after first call; always bound the size |
| Large file/stream that doesn't need full materialization | Generator/`yield` pipeline | Constant memory regardless of input size |
| CPU-bound work, multi-core available, standard GIL build | `ProcessPoolExecutor`/`multiprocessing` | GIL prevents true thread parallelism for Python bytecode |
| CPU-bound work on a *verified* free-threaded build with GIL-safe extensions | Threads may now genuinely parallelize | Confirm the build and every extension first — don't assume |
| Numeric loop that resists vectorization | Numba `@njit` | Near-C speed for numeric kernels without hand-written C |
| Millions of small object instances | `__slots__` | Removes per-instance `__dict__` overhead |
| Repeated string concatenation in a loop | `"".join(parts)` | O(n) vs O(n²) for `+=` on immutable strings |

## Workflow

1. **Clarify the problem.** What's slow, how slow, what's the target? Identify input size/shape
   and whether this is a hot path (millions of calls) or cold (startup-only) — cold paths rarely
   justify the readability cost of optimization.
2. **Profile and establish a baseline.** `cProfile.run(...)` or `pstats` for function-level;
   `line_profiler` for line-level; `tracemalloc`/`memory_profiler` if memory is the complaint;
   `timeit`/`time.perf_counter()` for microbenchmarks. Record the number before touching anything.
3. **Classify the bottleneck**: CPU-bound, memory-bound, I/O-bound, wrong data structure, or a
   slow database query. If it's a query, hand off to `sqlalchemy-query-patterns.md`; if it's
   I/O-bound or concurrency-related, hand off to `async-programming.md`.
4. **Apply the highest-leverage fix available** from the hierarchy — algorithm/data-structure
   before vectorization before caching before native extensions/parallelism before
   micro-optimization.
5. **Benchmark before/after with the same input.** Run multiple times to account for variance;
   use `time.perf_counter()`, never wall-clock `time.time()`, for short operations.
6. **Verify correctness is preserved** — same output for the same input, edge cases included.
7. **Document the trade-off**: what was slow, what changed, the before/after numbers, and any
   readability/memory cost.
8. **Verify against the Quality Checklist** below before calling the optimization done.

## Patterns

### Profiling: function-level, line-level, memory

```python
import cProfile, pstats

profiler = cProfile.Profile()
profiler.enable()
result = slow_function()
profiler.disable()
pstats.Stats(profiler).sort_stats("cumulative").print_stats(20)

# Line-level (pip install line_profiler): decorate target with @profile, then
# kernprof -l -v script.py

import tracemalloc
tracemalloc.start()
# ... run code ...
for stat in tracemalloc.take_snapshot().statistics("lineno")[:10]:
    print(stat)
```

### Data structure swap

```python
# O(n) membership scan
if target in large_list:
    ...

# O(1) membership
large_set = set(large_list)
if target in large_set:
    ...

from collections import deque
queue = deque()
queue.append(item)
first = queue.popleft()          # O(1), vs list.pop(0)'s O(n)
```

### Vectorization over row-by-row iteration

```python
import numpy as np

# SLOW: 1000x slower than vectorized — materializes a Python object per row
for idx, row in df.iterrows():
    df.at[idx, "tax"] = row["price"] * 0.1

# FAST: vectorized
df["tax"] = df["price"] * 0.1
df["tier"] = np.select(
    [df["price"] > 500, df["price"] > 100],
    ["luxury", "premium"],
    default="standard",
)
```

### Bounded caching

```python
from functools import lru_cache

@lru_cache(maxsize=256)                # always bound it — unbounded is a memory leak
def expensive_lookup(key: str) -> dict:
    return fetch_from_database(key)
```

### Generator pipeline for constant-memory streaming

```python
def read_large_file(path: str):
    with open(path) as f:
        for line in f:
            yield line.strip()

def parse_records(lines):
    for line in lines:
        yield json.loads(line)

# Composes without materializing an intermediate list at any stage
for record in parse_records(read_large_file("data.jsonl")):
    process(record)
```

### Parallelism for CPU-bound work (standard GIL build)

```python
from concurrent.futures import ProcessPoolExecutor
import multiprocessing

def parallel_process(data: list, n_workers: int | None = None) -> list:
    n_workers = n_workers or multiprocessing.cpu_count()
    chunk_size = max(1, len(data) // n_workers)
    chunks = [data[i:i + chunk_size] for i in range(0, len(data), chunk_size)]
    with ProcessPoolExecutor(max_workers=n_workers) as executor:
        return list(executor.map(heavy_computation, chunks))
```

### Verifying the interpreter build before choosing threads for CPU work

```python
import sys

def cpu_parallel_strategy() -> str:
    if getattr(sys, "_is_gil_enabled", lambda: True)():
        return "process_pool"          # standard build: threads won't parallelize CPU work
    return "thread_pool"               # free-threaded build confirmed — verify extensions too
```

### Memory: `__slots__` for high object counts

```python
class Point:
    __slots__ = ("x", "y")             # ~56 bytes vs ~200+ with a per-instance __dict__
    def __init__(self, x: float, y: float) -> None:
        self.x, self.y = x, y
```

### Benchmarking before/after honestly

```python
import time
from contextlib import contextmanager

@contextmanager
def timer(label: str):
    start = time.perf_counter()        # never time.time() for short operations
    yield
    print(f"{label}: {time.perf_counter() - start:.4f}s")

with timer("before"):
    original_function(test_data)
with timer("after"):
    optimized_function(test_data)
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Optimized the wrong function; no measured improvement | Skipped profiling, optimized by intuition | Always profile first; confirm the fix targets the actual hotspot |
| `list` used for a hot membership check | Wrong data structure for the access pattern | `set`/`dict` for O(1) lookup |
| DataFrame transform 100x slower than expected | `.iterrows()` or `.apply()` with a Python lambda | Vectorize with column ops, `np.where`/`np.select` |
| Cache grows unbounded, eventually OOMs a long-lived process | `lru_cache`/manual dict cache with no `maxsize` | Always bound cache size explicitly |
| Threads added to a CPU-bound hot path, no speedup measured | GIL serializes bytecode on the standard build | `ProcessPoolExecutor`, or verify a free-threaded build + GIL-safe extensions before using threads |
| Large file processing OOMs | Entire file/result set materialized into a list | Generator pipeline — one item in memory at a time |
| Benchmark numbers don't reproduce | `time.time()` used for a short operation (OS scheduling jitter) | `time.perf_counter()`/`timeit`, run multiple times |
| Optimization ships but nobody remembers the trade-off | No documentation of the readability/memory cost | Record before/after numbers and the trade-off with the change |
| Vectorizing a tiny array made things slower | NumPy call overhead exceeds the gain below ~100 elements | Only vectorize where n is large enough to amortize overhead |
| Free-threaded build adopted, extension crashes under load | C extension assumed GIL protection that free-threading removed | Audit every C-extension dependency's free-threading support before adopting the build |

## Quality Checklist

- [ ] Profiled the original code and identified the actual bottleneck before changing anything
- [ ] Baseline measurement recorded with `timeit`/`time.perf_counter()`, not `time.time()`
- [ ] Same input data used for before/after comparison, run multiple times for variance
- [ ] Memory impact checked, not just wall-clock speed
- [ ] Correctness verified — same output for the same input, edge cases included
- [ ] The change targets a genuinely hot path, not dead or rarely-run code
- [ ] No new dependency added without justification (stdlib/existing deps considered first)
- [ ] Readability/memory trade-off documented alongside the before/after numbers
- [ ] Any thread-for-CPU-work choice is backed by a verified free-threaded build and audited extensions
- [ ] Concurrency-adjacent optimizations are thread/process-safe (cross-check `async-programming.md`)
