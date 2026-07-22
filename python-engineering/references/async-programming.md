# Async Programming Patterns

Write Python concurrent code that picks the right tool for the workload — async/await for I/O,
threads/processes for CPU — and that cancels cleanly, never blocks the event loop, and holds up
under Python's evolving GIL model.

---

## Overview

Python offers three genuinely different concurrency tools — coroutines, threads, and processes —
and most bugs in this space come from reaching for the wrong one, not from misusing the one
chosen. The core philosophy: **classify the workload before picking a tool.** I/O-bound work
(network, disk, DB) wants `asyncio`, because the event loop can do other work while one coroutine
waits; CPU-bound work wants `multiprocessing` (or, on newer builds, threads — see below), because
the GIL serializes Python bytecode execution on a single thread regardless of how many threads you
spawn. Mixing the two without understanding the boundary — usually a blocking call sitting inside
a coroutine — is the single most common concurrency bug in Python services, and it manifests as
one slow request stalling every other in-flight request.

## Core Concepts

**Async is concurrency, not parallelism.** A single-threaded event loop runs one coroutine at a
time; `await` is the only point where it can switch to another. Nothing runs *simultaneously*
under plain `asyncio` — the win is that the loop stays busy with other coroutines while one is
waiting on I/O instead of the whole process sitting idle. True parallelism needs multiple OS
threads or processes.

**Blocking the event loop stalls everything.** `time.sleep()`, a synchronous DB driver call, or a
CPU-heavy loop inside a coroutine all block the one thread the event loop runs on — every other
coroutine, including ones with nothing to do with the slow request, stalls until it returns. This
is the root cause of "one slow endpoint takes down the whole service" reports. Offload blocking
calls to `loop.run_in_executor()` (thread pool for I/O-bound blocking libraries, process pool for
CPU-bound work) or replace them with an async-native driver (`asyncpg`, `aiosqlite`, `httpx`'s
async client).

**Structured concurrency over fire-and-forget.** `asyncio.TaskGroup` (3.11+) is the structured
form: every child task is awaited or cancelled when the `async with` block exits, and an
`ExceptionGroup` surfaces every failure instead of silently dropping siblings' errors the way
`asyncio.gather()`'s fail-fast default can. Prefer `TaskGroup` for new code; reach for `gather()`
only when you specifically want `return_exceptions=True`-style partial-failure collection, since
`TaskGroup` has no equivalent — a single child exception cancels the group.

**Cancellation is cooperative and must be re-raised.** Cancelling a task delivers
`asyncio.CancelledError` at the *next* suspension point inside it — nothing stops instantly.
Catching `CancelledError` to run cleanup is fine; swallowing it (not re-raising) is not — it turns
a cancelled task into one that silently keeps running, defeating timeouts and shutdown. CPU-bound
async generators and long loops need explicit checkpoints (an `await asyncio.sleep(0)` or a native
`await` inside the loop) or cancellation never gets a chance to land.

**Bound your concurrency.** An unbounded `gather()` over thousands of URLs opens thousands of
sockets at once — this is a self-inflicted denial-of-service against whatever you're calling, and
it OOMs your own process buffering all those responses. `asyncio.Semaphore` caps in-flight work
without abandoning concurrency altogether; a bounded `asyncio.Queue` does the same for
producer/consumer pipelines and gives you backpressure for free.

**Only lock what's actually shared and mutable.** Single-threaded async code touching its own
state needs no lock — there's exactly one coroutine running at any instant, so ordinary sequential
reasoning holds between `await` points. Locks (`asyncio.Lock`) matter only when a *check-then-act*
sequence has an `await` in the middle (another coroutine can interleave) or when you're mixing
async code with real OS threads that touch the same object.

**Python 3.13+ free-threading changes the CPU-bound calculus — but doesn't remove it.** Python
3.13 introduced an official (initially experimental) free-threaded build that can disable the GIL,
and each subsequent release has continued stabilizing it toward being a fully supported build
option. On a free-threaded interpreter, `threading` genuinely parallelizes CPU-bound Python
bytecode across cores — something that was never true under the standard GIL build, where threads
only helped with I/O and C-extension code that releases the GIL. This does **not** mean "switch
CPU-bound work to threads by default": free-threaded builds carry single-threaded performance
overhead relative to the GIL build, a chunk of the C-extension ecosystem still assumes GIL
protection and can crash or corrupt state without it, and most production deployments in 2026 are
still choosing the standard GIL build unless they've specifically evaluated free-threading for
their workload. Treat free-threading as a decision to make deliberately, verified against the
target interpreter build and the extension dependencies in use — not as a blanket "no more GIL"
assumption. Where you're not sure which build a project targets, check `sys._is_gil_enabled()` (or
`python -VV`) rather than assuming.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Workload waits on network/disk/DB? | `async`/`await` | The event loop does other work while this one waits; cheapest concurrency for I/O |
| Workload is CPU-bound (parsing, computation)? | `ProcessPoolExecutor`/`multiprocessing` (or threads on a verified free-threaded build) | The standard-build GIL serializes Python bytecode across threads; processes get real parallelism |
| Blocking/sync call needed inside a coroutine? | `loop.run_in_executor()` | Never call blocking code directly in a coroutine — it stalls the whole loop |
| Multiple independent async calls, need all results | `asyncio.TaskGroup` | Structured: guarantees cleanup, propagates all failures as an `ExceptionGroup` |
| Need partial results despite some failures | `asyncio.gather(..., return_exceptions=True)` | `TaskGroup` has no partial-failure mode; `gather` does |
| Fan-out size is data-dependent / unbounded | `asyncio.Semaphore` or bounded `asyncio.Queue` | Prevents self-inflicted overload and unbounded memory growth |
| Shared mutable state, single thread, no `await` between check and act | No lock needed | Only one coroutine runs at a time between suspension points |
| Shared mutable state with an `await` between check and act, or shared with real threads | `asyncio.Lock` / `threading.Lock` | Interleaving or true parallelism can otherwise corrupt state |
| Need a deadline on an external call | `asyncio.timeout()` (3.11+) | Structured, composable, and cancels the whole block cleanly on expiry |

## Workflow

1. **Classify the workload.** Read the code or requirement and determine: I/O-bound, CPU-bound,
   or mixed. Ask what's actually slow — waiting, or computing.
2. **Check the runtime target.** Python version (3.11+ for `TaskGroup`/`asyncio.timeout`, 3.13+
   free-threaded availability), whether an async driver exists for the I/O dependency in play
   (`asyncpg` vs a sync driver), and whether the project has already committed to a free-threaded
   build (rare in 2026 — verify, don't assume).
3. **Pick the tool per the Decision Framework** above, not by habit.
4. **Write the happy path first**: the coroutine or executor call, with proper `await`s and no
   blocking calls inside async functions.
5. **Add bounds**: semaphore or queue `maxsize` on any fan-out driven by external/variable-size
   input.
6. **Add cancellation and timeout handling**: wrap external calls in `asyncio.timeout()`; re-raise
   `CancelledError` after cleanup, never swallow it.
7. **Add locks only where the Decision Framework calls for one** — justify each lock with the
   specific race it prevents.
8. **Verify against the Quality Checklist** below, and if this is a performance question rather
   than a correctness one, hand off to `python-performance.md` for profiling before further tuning.

## Patterns

### Structured concurrency with TaskGroup

```python
import asyncio

async def fetch_dashboard_data() -> DashboardData:
    async with asyncio.TaskGroup() as tg:
        users_task = tg.create_task(fetch_json("/users"))
        orders_task = tg.create_task(fetch_json("/orders"))
        products_task = tg.create_task(fetch_json("/products"))
    # All three tasks are complete here, or an ExceptionGroup was raised
    # and every task was already cancelled/awaited for you.
    return DashboardData(
        users=users_task.result(),
        orders=orders_task.result(),
        products=products_task.result(),
    )
```

### Bounded concurrency with a semaphore

```python
import asyncio

async def fetch_all(urls: list[str], max_concurrent: int = 10) -> list[dict]:
    semaphore = asyncio.Semaphore(max_concurrent)

    async def fetch_one(url: str) -> dict:
        async with semaphore:            # blocks once max_concurrent are in flight
            return await fetch_json(url)

    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(fetch_one(url)) for url in urls]
    return [t.result() for t in tasks]
```

### Offloading blocking work

```python
import asyncio
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor

io_executor = ThreadPoolExecutor(max_workers=8)      # blocking I/O (legacy driver, file I/O)
cpu_executor = ProcessPoolExecutor()                 # CPU-bound, real parallelism

async def read_legacy_config(path: str) -> str:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(io_executor, Path(path).read_text)

async def score_document(doc: str) -> float:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(cpu_executor, heavy_nlp_score, doc)
```

### Timeouts that clean up properly

```python
import asyncio

async def fetch_with_deadline(url: str, seconds: float = 5.0) -> dict:
    try:
        async with asyncio.timeout(seconds):
            return await fetch_json(url)
    except TimeoutError:
        raise ServiceUnavailableError(f"Timeout fetching {url}") from None
```

### Cancellation that re-raises

```python
async def long_running_task() -> None:
    try:
        await asyncio.sleep(100)
    except asyncio.CancelledError:
        await flush_pending_writes()   # cleanup runs on cancellation
        raise                          # ALWAYS re-raise — never swallow

task = asyncio.create_task(long_running_task())
await asyncio.sleep(1)
task.cancel()
await task   # propagates CancelledError after cleanup ran
```

### Producer/consumer with backpressure

```python
import asyncio

async def producer(queue: asyncio.Queue) -> None:
    for item in data_source():
        await queue.put(item)          # blocks once queue.maxsize in-flight items
    await queue.put(None)              # sentinel

async def consumer(queue: asyncio.Queue) -> None:
    while (item := await queue.get()) is not None:
        await process(item)
        queue.task_done()

async def run_pipeline() -> None:
    queue: asyncio.Queue = asyncio.Queue(maxsize=100)   # bounded — backpressure
    async with asyncio.TaskGroup() as tg:
        tg.create_task(producer(queue))
        tg.create_task(consumer(queue))
```

### asyncio.Lock for check-then-act state

```python
import asyncio

class AsyncCache:
    def __init__(self) -> None:
        self._lock = asyncio.Lock()
        self._data: dict[str, str] = {}

    async def get_or_fetch(self, key: str) -> str:
        async with self._lock:                    # the fetch involves an await, so
            if key not in self._data:               # another coroutine could otherwise
                self._data[key] = await expensive_fetch(key)  # interleave here
            return self._data[key]
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| All requests stall together under load | A blocking call (sync DB driver, `time.sleep`, CPU loop) sits inside a coroutine | `run_in_executor` for blocking calls; switch to an async-native driver |
| "Coroutine was never awaited" warning, wrong result silently used | Missing `await` before a coroutine call | Always `await`; enable `-W error::RuntimeWarning` in dev/CI |
| Shutdown hangs, tasks never actually stop | `CancelledError` caught and not re-raised | Always `raise` after cleanup in the `except CancelledError` block |
| `RuntimeError: This event loop is already running` | Calling `asyncio.run()` from inside a running loop | Use `await` directly, or `asyncio.run_coroutine_threadsafe` from another thread |
| Tasks silently vanish mid-run | No reference held to a bare `asyncio.create_task()` result — it can be GC'd | Use `asyncio.TaskGroup`, or hold the task in a set until done |
| Event loop deadlocks or degrades under real load | Sync DB/HTTP client used inside async code | Use the async driver (`asyncpg`, `aiomysql`, `httpx.AsyncClient`) |
| Service OOMs or gets rate-limited during a bulk operation | Unbounded `gather()`/`TaskGroup` fan-out over large/variable input | `Semaphore` or bounded `Queue` to cap concurrency |
| Subtle, hard-to-reproduce data corruption in shared state | Mutating shared state across an `await` without a lock | `asyncio.Lock` around the check-then-act section, or make the state immutable |
| Threads added for a CPU-bound hot path with zero speedup | Standard GIL build serializes bytecode regardless of thread count | `ProcessPoolExecutor`, or verify + adopt a free-threaded build deliberately |
| Free-threaded build crashes or corrupts data under a C extension | Extension assumes GIL protection that free-threading removes | Verify every C-extension dependency's free-threading support before adopting the build |

## Quality Checklist

- [ ] No blocking calls (`time.sleep`, sync DB/HTTP clients, CPU-heavy loops) inside a coroutine
- [ ] Every coroutine call is `await`ed; `-W error::RuntimeWarning` catches missed ones in CI
- [ ] `CancelledError` is always re-raised after cleanup, never swallowed
- [ ] Unbounded fan-out is capped with a `Semaphore` or a bounded `Queue`
- [ ] External calls have a timeout (`asyncio.timeout()`), and the timeout path is handled, not swallowed
- [ ] `TaskGroup` used for structured fan-out; bare `create_task()` results are held or grouped, never dropped
- [ ] Locks appear only where an `await` sits between a check and its corresponding act, or where async code shares state with real threads
- [ ] CPU-bound work runs in `ProcessPoolExecutor`/`multiprocessing`, not in a coroutine, on the standard GIL build
- [ ] If a free-threaded build is in play, it was a deliberate choice — dependencies audited, not assumed safe
- [ ] Async context managers (`async with`) used for connection/resource lifecycle, not manual open/close
