# Fast-Primes: Bare-Metal LLVM $n$-th Prime Calculator

**Fast-Primes** is a hyper-optimized, standalone $n$-th prime number calculator written entirely in bare-metal LLVM Intermediate Representation (IR).

Designed to compute massive primes without relying on standard libraries, this experiment bypasses `libc` completely. It issues direct x86-64 Linux system calls for memory management (`mmap`) and I/O, yielding maximum performance and total control over execution. Instead of relying on brute-force sieving, it implements an analytic number theory pipeline centered around **Lehmer's Formula** and the **Prime Number Theorem**.

---

## System Architecture

To achieve extreme sub-linear time complexity, the program avoids counting primes from zero. The execution pipeline is divided into distinct phases:

1. **The Fast-Path (Small $n$):** If $n \le 600{,}000$, the program instantly returns the result from the precomputed prime table built during the startup sieve, which covers all primes up to $10^7$.
2. **The Analytical Guess:** Uses the inverse Logarithmic Integral to estimate the numerical value of the $n$-th prime.
3. **The Exact Count:** Uses Lehmer's Formula to calculate exactly how many primes exist below a padded lower bound of the guess.
4. **The Localized Sieve:** Uses a dynamically allocated Sieve of Eratosthenes spanning the calculated error margin to scan forward to the exact target $n$.

---

## Algorithmic Complexity

Unlike traditional block-sieve implementations of Lehmer's algorithm bounded by $O\left(\frac{x}{\log^4 x}\right)$, this software evaluates the partial sieve function $\phi(x, a)$ using an iteratively unrolled sum and **recursive Dynamic Programming with a Hash Table (memoization)**.

* **Time Complexity:** The worst-case bound for the state space of $\phi(x, a)$ is $O\left(\frac{x^{3/4}}{\log x}\right)$. However, the heavy use of memoization via open-addressed hash tables prevents identical sub-states from being recomputed, bringing the practical performance closer to $O(x^{2/3})$ on average for massive inputs.
* **Space Complexity:** $O\left(\frac{x^{1/2}}{\log x}\right)$, dominated by the gigabytes of hash table cache dynamically allocated via `mmap` to store the $\phi(x,a)$ and $\pi(x)$ recursion branches.

---

## Mathematical Framework

### 1. The Estimate: Inverse Logarithmic Integral

By the Prime Number Theorem, $\pi(x) \sim \text{li}(x)$. The program computes the starting point by finding the root of $f(x) = \text{li}(x) - n = 0$ using the **Newton-Raphson method**:

$$x_{k+1} = x_k - (\text{li}(x_k) - n) \ln(x_k)$$

**Algorithmic nuances:**

* Instead of the classical integral definition of $\text{li}(x)$, the program computes the **asymptotic expansion series**:

$$\text{li}(x) \approx \frac{x}{\ln x} \sum_{k=0}^{14} \frac{k!}{(\ln x)^k}$$

  The series sum loop explicitly terminates when the absolute value of the current term drops below $10^{-14}$, or after exactly 14 terms, whichever comes first.

* The Newton iteration is capped at a maximum of **8 iterations**, with an early exit if the absolute value of the correction step is $< 0.5$.

### 2. Lehmer's Formula (The Exact Count)

Once the estimate $x_{\text{guess}}$ is found, the program calculates the exact prime count using Lehmer's Formula. First, three limits are computed based on the roots of $x$:

$$a = \pi(x^{1/4}), \quad b = \pi(x^{1/2}), \quad c = \pi(x^{1/3})$$

Mathematically, Lehmer's formula is written using 1-based prime indexing ($p_1 = 2$):

$$\pi(x) = \phi(x, a) + \frac{(b+a-2)(b-a+1)}{2} - \sum_{i=a+1}^{b} \pi\left(\frac{x}{p_i}\right) - \sum_{i=a+1}^{c} \sum_{j=i}^{\pi\left(\sqrt{x/p_i}\right)} \left( \pi\left(\frac{x}{p_i p_j}\right) - (j-1) \right)$$

> **Implementation Note (0-Based Array Translation):**
> The program stores primes in a 0-based memory array (`primes[0] = 2`). This means every 1-based mathematical index $k$ corresponds to the 0-based code variable `k - 1`. Concretely:
> * The outer sum's lower bound $i = a+1$ (1-based) maps to the loop initializer `%i = %a` in the code.
> * The inner sum's lower bound $j = i$ (1-based) maps to the loop initializer `%j = %i` in the code.
> * The subtracted term $(j-1)$ in the formula (1-based) maps to the code subtracting `%j` directly (0-based) — these are the same numerical value.
>
> In both loops, `primes[i]` (0-based) retrieves $p_{i+1}$ in 1-based notation, so the 0-based memory access and 1-based formula are fully consistent.

### 3. The Partial Sieve Iterative Sum ($\phi$)

The computational bottleneck is $\phi(x, a)$, the count of integers up to $x$ coprime to the first $a$ primes.

Instead of using the standard Legendre recursion $\phi(x, a) = \phi(x, a-1) - \phi(\lfloor x/p_a \rfloor, a-1)$, the code jumps past the trivial branches and computes an iteratively unrolled sum starting from a pre-computed base at $a = 6$:

$$\phi(x, a) = \phi(x, 6) - \sum_{i=6}^{a-1} \phi\!\left(\left\lfloor \frac{x}{p_{i+1}} \right\rfloor,\; i\right)$$

> **Implementation Note (0-Based Array Translation):**
> In the code, the loop variable `i` is 0-based and runs from `6` to `a - 1`. At each step, `primes[i]` (0-based) retrieves $p_{i+1}$ in 1-based notation, and the recursive call passes `i` as the second argument — corresponding to the 1-based index $i$ shown in the formula above. The formula and the code are therefore fully consistent.

To compute the base case $\phi(x, 6)$ in $O(1)$ time, the program uses a **Primorial Modulus Lookup**. Since the primorial $p_6\# = 2 \times 3 \times 5 \times 7 \times 11 \times 13 = 30030$, the coprimality pattern repeats every 30030 integers. The codebase precomputes a 2D table of 7 rows ($a = 0 \ldots 6$) and 30031 columns, holding $\phi(x, a)$ for $x \in [0, 30030]$ (total allocation: $7 \times 30031 \times 8 = 1{,}681{,}736$ bytes). Any base case is then evaluated in $O(1)$ as:

$$\phi(x, 6) = \left\lfloor \frac{x}{30030} \right\rfloor \phi(30030, 6) + \phi(x \bmod 30030, 6)$$

For $a > 6$, the computed result is memoized in a 1 GB open-addressed hash table (64M entries of 16 bytes each) to avoid recomputing identical sub-states across the recursion tree.

### 4. The Localized Sieve (The Gap)

Because $\text{li}(x)$ overestimates $\pi(x)$, the initial inverse estimate $\hat{x} \approx \text{li}^{-1}(n)$ is usually slightly larger than the actual $n$-th prime.

To guarantee the target prime is captured, the program:

1. Computes a safe margin: $\text{margin} = 25\sqrt{\hat{x}}$.
2. **Subtracts** this margin from the estimate to create a safe lower base: $\text{base} = \hat{x} - \text{margin} + 1$.
3. Calls Lehmer's formula to find the exact count $C = \pi(\text{base} - 1)$, and derives the remaining target $r = n - C$.
4. Allocates a byte-sieve spanning the interval $[\text{base},\; \text{base} + 3 \times \text{margin})$ and marks composites using the pre-cached base primes.
5. Scans linearly forward, decrementing $r$ for each unmarked (prime) byte. When $r = 0$, the $n$-th prime has been found.

---

## System-Level Optimization Tricks

Because this code is written in pure LLVM IR, it employs several low-level optimizations:

* **No `libc` / True Bare-Metal Entry:** The program defines a naked `_start` function (not `main`). It executes inline assembly to manually read `argc` and `argv` directly off the stack pointer `%rsp`. It terminates using a raw `syscall` (number `60` for `sys_exit`), skipping all standard `atexit` handlers entirely.
* **Knuth Multiplicative Hashing:** Both hash tables (for $\phi$ and for $\pi$) use open addressing with linear probing. The hash function uses Knuth's multiplicative constant `-7046029254386353131` — which is $2^{64} \times (\sqrt{5}-1)/2$ in unsigned two's complement — to scatter keys uniformly across the table.
* **The `fyl2x` x87 Trick:** To compute the natural logarithm required for the Logarithmic Integral, the program issues the x86 `fyl2x` floating-point instruction with $y = \ln(2) \approx 0.693147$. This computes $y \cdot \log_2(x) = \ln(x)$ in a single hardware step, avoiding the need for a software math library.
* **128-Bit Return Type:** The master `prime()` function returns an `i128` type. While the current memory allocation bounds the practical computation, the underlying pipeline is intrinsically capable of returning prime values beyond the 64-bit integer limit.
* **Input Validation:** The program rejects $n \le 0$ before allocating any memory, preventing unsigned integer underflow when converting the 1-based user input to the 0-based internal index. Any non-numeric or zero argument causes an early exit with a descriptive error message to `stderr`.




---

## Compilation and Usage

This experiment requires the LLVM toolchain (`llvm-link`, `opt`, `llc`, and `lld`).

**Build the executable:**

The Makefile exposes two build targets:

```bash
make generic   # Default. Compiles without -march tuning; maximally portable.
make native    # Compiles with -march=x86-64. Faster on x86-64 hosts.
make           # Alias for generic.
```

To target a specific microarchitecture, override `MARCH_FLAG` directly:

```bash
make native MARCH_FLAG=-march=znver4
```

**Run the calculator:**

Pass the target $n$ as a command-line argument. The program supports standard integer strings and allows underscores or commas as digit separators for readability.

```bash
./bin/fast-primes 1_000_000_000
```

The result is printed to `stdout` with underscore digit separators (e.g., `22_801_763_489`). Any usage error is printed to `stderr` and the program exits with code `1`.

---

## References

1. **Lehmer, D. H. (1959).** *On the exact number of primes less than a given limit.* Illinois Journal of Mathematics, 3(3), 381–388. [DOI: 10.1215/ijm/1255455259](https://doi.org/10.1215/ijm/1255455259)
2. **Lagarias, J. C., Miller, V. S., & Odlyzko, A. M. (1985).** *Computing $\pi(x)$: The Meissel-Lehmer method.* Mathematics of Computation, 44(170), 537–560. [DOI: 10.1090/S0025-5718-1985-0777285-5](https://doi.org/10.1090/S0025-5718-1985-0777285-5)
3. **Hadamard, J. & de la Vallée Poussin, C. J. (1896).** *The Prime Number Theorem.* [Wikipedia](https://en.wikipedia.org/wiki/Prime_number_theorem)
4. **Crandall, R., & Pomerance, C. (2005).** *Prime Numbers: A Computational Perspective.* Springer. [DOI: 10.1007/0-387-28979-8](https://doi.org/10.1007/0-387-28979-8)
5. **Forbes, T. (2002).** *Review: Prime numbers: A computational perspective, by Richard Crandall and Carl Pomerance.* The Mathematical Gazette, 86, 552–554. [DOI: 10.2307/3621190](https://doi.org/10.2307/3621190)
6. **[Sheafification of G](https://github.com/SheafificationOfG):** Inspiration for this project was drawn from the YouTube video [One second to find the BILLIONth PRIME](https://www.youtube.com/watch?v=uJkoI5TnKzA). The bare-metal x86-64 Linux system call wrappers (`src/sys/amd64_rt.ll`, `src/sys/amd64_sys.ll`) are from the GitHub repository [SheafificationOfG/QueenJewels](https://github.com/SheafificationOfG/QueenJewels).
7. **[haskallcurry/primes](https://github.com/haskallcurry/primes):** The implementation of the Meissel-Lehmer algorithm in the haskallcurry/primes repository served as a foundational reference for this experiment.