# Lukas Sequence Solver

A parallel solver for finding subsequences in the Lukas sequence, optimized with adjustable work unit sizes for performance.

## Input Format

To run the program, use the following format:

```
lukas n k
```

Replace `n` and `k` with the desired values.
For example:

```
lukas 10000 24
```

For setup instructions, please see the [README](../README.md).

## Runtime Measurements

When measuring runtimes, the input is **hardcoded** to avoid time overhead from manual input.
The program also prints its execution time, which reflects the actual runtime of the computation.

## Work Unit Size

The chosen work unit size is **1024 sequences per worker**.  
This value was determined by testing various unit sizes and evaluating performance.

- Smaller work units introduced significant overhead.
- Larger work units reduced the ability to balance load effectively among workers.
- A unit size of **1024** provided the best trade-off between task execution efficiency and parallelism.

### Performance Comparison

| Work Unit Size | Real Time (s) | CPU Utilization |
| -------------- | ------------- | --------------- |
| 32             | 4.506         | 137%            |
| 64             | 1.129         | 213%            |
| 128            | 0.703         | 302%            |
| 256            | 0.784         | 407%            |
| 512            | 0.798         | 421%            |
| 1024           | 0.814         | 476%            |
| 2048           | 0.899         | 484%            |
| 4096           | 0.964         | 485%            |

## Results

The following results are for the input `lukas 1000000 4`

```
2.30s user 2.26s system 473% cpu 0.964 total
```

- **Outcome:** No subsequences were found that satisfy the requirement.
- **Execution Time (REAL TIME):** 0.964 seconds
- **CPU Time:** 2.30s user, 2.26s system
- **CPU/REAL TIME Ratio:** 473%

The CPU/REAL TIME ratio indicates that the computation effectively utilized approximately 4.78 cores, which is consistent with the parallel execution using 4-5 workers.

## Largest Problem Solved

The largest input successfully computed was:

```
lukas 30000000 24
```

- **Execution Time** ~ 66.50 seconds
- This was the practical upper limit tested, constrained by the hardware used. Larger inputs may be possible on more capable systems.
