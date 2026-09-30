# Multi-Precision Arithmetic Sequence in x86-64 Assembly

An **x86-64 Assembly (NASM)** implementation of a C-callable function that computes the $k$-th term ($A_k$) of an arbitrary-precision arithmetic sequence given its first two terms ($A_0$ and $A_1$).

## Overview

Given two $64n$-bit signed integers $A_0$ and $A_1$ (where $n > 0$) and a 64-bit signed index $k \in \mathbb{Z}$ (including negative indices), the function calculates:

$$A_k = A_0 + k \cdot (A_1 - A_0)$$

All multi-word integers ($A_0$, $A_1$, and $A_k$) are represented in **two's complement** format using **little-endian** word ordering across arrays of $n$ 64-bit words (`uint64_t`). Because the result $A_k$ can exceed $64n$ bits due to multiplication by $k$ and subtraction/addition overflow, the function stores the lower $64n$ bits in the output buffer `Ak` and returns the upper 128 bits (`int128_t`) via registers `RAX` and `RDX`.

---

## Function Signature and ABI

```c
#include <stddef.h>
#include <stdint.h>

typedef struct {
  uint64_t lo;
  int64_t  hi;
} int128_t;

int128_t arithmetic_sequence(uint64_t const *A0, uint64_t const *A1, uint64_t *Ak, size_t n, int64_t k);