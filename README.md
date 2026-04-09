# Parallel Computing: Sequential vs Concurrent List Summation

## Overview

This project demonstrates the concept of parallel overhead in computing. The goal was to compute the sum of a massive list using both **sequential** and **parallel** approaches in Racket, and to observe the performance differences. 

A key aspect of this project is discovering that naïvely adding threads to a simple task can actually **slow down** execution. This happens because Racket utilizes user-level **"Green Threads"** that do not execute on different CPU cores simultaneously.

## Implementation Details

In accordance with strict project constraints, no standard shortcut functions (`length`, `take`, `drop`, `map`, `fold`, etc.) were used. Every core list iteration and operation uses **explicit recursion**.

- **`sum-seq`**: A purely recursive sequential summation function.
- **`parallel-sum`**:
  - Recursively splits the list into `k` chunks using custom helper functions (`length-rec`, `take-rec`, `drop-rec`).
  - Spawns `k` threads where each thread calculates the partial sum of its chunk.
  - Joins all threads and recursively combining the results.
- Measures the execution time using Racket's `time-apply`.
- Generates a visual plot representing Thread Count vs Execution Time using Racket's `plot` library.

## Execution and Timings

A list of size **100,000** was generated for testing. 

| Mode | Threads (k) | Execution Time (ms) |
| :--- | :---: | :---: |
| **Sequential** | — | **6 ms** |
| Parallel | 1 | 12 ms |
| Parallel | 2 | 8 ms |
| Parallel | 4 | 11 ms |
| Parallel | 8 | 8 ms |
| Parallel | 16 | 7 ms |
| Parallel | 32 | 7 ms |
| Parallel | 64 | 7 ms |

![Plot Representation]

## Analysis & Findings

As observed, increasing the number of threads (*k*) never makes the parallel execution faster than the sequential version (6 ms vs 7-12 ms). In fact, performance degrades. This happens for several reasons:

1. **Green Threads (No True Parallelism):** Racket threads are user-level green threads managed by the runtime, not OS-level threads. They share a single OS thread and cannot inherently run simultaneously across multiple CPU cores. Increasing *k* introduces concurrency overhead without parallel speedup.
2. **Thread Management Overhead:** Constructing threads, scheduling them, and executing `thread-wait` creates a fixed cost. For a highly trivial arithmetic operation (like addition), the thread management latency severely outweighs the subdivided work time.
3. **List Splitting Cost:** Finding lengths and extracting chunks (custom `split-into-k`) necessitates multiple $O(n)$ traversals across the list—computations the sequential version never has to perform.
4. **Combination Cost:** Consolidating partial outputs adds an extra step that isn't required when calculating the sum linearly.

**Conclusion:** For a simple linear time complexity task, Racket's green threads inject pure overhead without rendering parallel optimization.

## How to Run

1. Open `parallel_sum.rkt` in DrRacket or run via terminal using `racket parallel_sum.rkt`.
2. The runtime script will automatically execute the sequential sum, followed by all thread-based variations. 
3. It outputs `timing_plot.png` to visually display the timings.
