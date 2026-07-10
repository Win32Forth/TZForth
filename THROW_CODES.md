# ANS Standard THROW Codes — Migration Plan for TZForth

This document maps TZForth’s internal `errorFlag` error path to ANS Forth 2012 standard `THROW` codes (Exception word set §9.3.1). It is the implementation guide for replacing `tell("? …")` + `errorFlag = true` with catchable `kernelThrow(code, message:)`.

**Status:** Phase 1 implemented (stack faults, division by zero, undefined word, compile-only misuse, `innerThread` throw propagation). ~120 `errorFlag` sites remain for Phases 2–4.

**Reference:** [ANS THROW](https://forth-standard.org/standard/exception/THROW), §9.3.1 throw codes, §9.3.5 exception handling.

---

## Two error mechanisms today

| Mechanism | Type | CATCH-able? | Typical recovery |
|-----------|------|-------------|------------------|
| **`errorFlag`** | Swift `Bool` on `TZForth` | **No** | `feedLine` → `recoverFromError()` |
| **`THROW` / `CATCH`** | Forth words | **Yes** | `deliverThrow` → restore `CATCH` frame |

`CATCH`, `THROW`, `ABORT`, and `ABORT"` are implemented and tested. Most kernel faults still bypass them.

### What `errorFlag` does

1. Kernel sets `errorFlag = true` (often after `tell("? …")`).
2. `runInterpreter` / `innerThread` stop looping.
3. `feedLine` calls `recoverFromError()` — drain input, reset stacks, handle open colon defs.
4. REPL continues on the next line (no Forth-level unwinding).

`errorFlag` is **not** a Forth word; the host reads it after `FLOAD` to decide whether to abort loading.

### Target behavior after migration

1. Kernel calls `kernelThrow(code, message:)`.
2. If a `CATCH` frame is active → unwind, push `code`, **no message**, stacks restored.
3. If uncaught → `handleUnhandledThrow` prints `message` (or standard text), resets like today, sets `errorFlag` for host/FLOAD bookkeeping.

**UX rule:** Uncaught errors keep today’s `? …` lines where tests and REPL habit expect them. Caught errors push only the numeric code (ANS §9.6.1.2275).

---

## Standard throw codes (ANS §9.3.1)

| Code | Condition |
|------|-----------|
| -1 | `ABORT` |
| -2 | `ABORT"` |
| -3 | Stack underflow |
| -4 | Stack overflow |
| -5 | Return stack underflow |
| -6 | Return stack overflow |
| -7 | Invalid memory address |
| -8 | Double-cell number expected |
| -9 | Division by zero |
| -10 | Attempt to use zero-length string as name |
| -11 | Attempt to use zero-length buffer as name |
| -12 | Address not aligned |
| -13 | Undefined word |
| -14 | Interpreting a compile-only word |
| -15 | Uncompleted IF / DO / CASE |
| -16 | Attempt to use non-existent execution token |
| -17 | Nesting limit exceeded |
| -18–-39 | *(reserved by standard)* |
| -40 | User-defined *(first of user range)* |
| -59 | *(reserved)* |
| -60–-65 | Floating-point *(Float word set)* |
| -66–-75 | File-access / block *(optional sets)* |

TZForth assigns **-40 and below** only where no standard code fits; prefer -3…-17 for kernel faults.

---

## `kernelThrow` API (Phase 1)

```swift
/// Raise a standard or implementation throw. Caught → CATCH gets code only.
/// Uncaught → handleUnhandledThrow prints message, resets, sets errorFlag.
private func kernelThrow(_ code: Cell, message: String? = nil)
```

- **`StdThrow`** enum in `TZForth.swift` — named constants for -1…-17.
- **`lastKernelThrowMessage`** — full REPL line for uncaught display (e.g. `"? Division by zero"`).
- **`innerThread`** — `if throwActive { break }` after each primitive (required for CATCH inside colon words).

### What stays on `errorFlag` (intentionally)

| Case | Reason |
|------|--------|
| Uncaught `THROW` | `handleUnhandledThrow` sets `errorFlag` for `feedLine` / FLOAD abort |
| FLOAD host failures | File not found — `ior`-style, not Forth execution |
| `recoverFromError` during FLOAD | `wasLoading` leaves `errorFlag` set to stop include |
| Soft notes (`DIR` failure, sandbox hints) | Not execution faults |

---

## Phase 1 — Done

| Site | Code | Message (uncaught) |
|------|------|-------------------|
| `pop()` underflow | -3 | `? Stack underflow` / `? Stack underflow while compiling` |
| `push()` overflow | -4 | `? Stack overflow` |
| `rpop()` underflow | -5 | `? Return stack underflow` (+ compiling variant) |
| `rpush()` overflow | -6 | `? Return stack overflow` |
| `/` `/MOD` `*/MOD` `M/` `M*/` `UM/MOD` etc. | -9 | `? Division by zero` |
| Outer interpreter unknown word | -13 | `? name` / `? name ? (while compiling)` |
| `'` / `[']` / `[COMPILE]` / `POSTPONE` not found | -13 | `? word ?` |
| Compile-only in interpret (`LITERAL`, `IF`, …) | -14 | `? word only while compiling` |
| Locals in interpret | -14 | `? (LOCAL) undefined in interpret state` etc. |

**FTEST additions:** CATCH on `/` div-by-zero, CATCH on undefined word, CATCH on stack underflow.

---

## Phase 2 — Memory, tokens, control flow

| TZForth message / site | Code | Notes |
|------------------------|------|-------|
| `readCell` / `writeCell` out of range | -7 | `? Memory read/write out of range` |
| `? Invalid executable token` | -16 | Bad threaded branch / literal as code |
| `? Bad threaded call target` / `? Bad colon definition target` | -16 | Corrupt CFA / IP |
| `? Bad branch target (ip=…)` | -16 | Unresolved `>MARK` / corrupt compile |
| `? [IF] unresolved conditional compilation` | -15 | |
| `? IF/DO/CASE only while compiling` (when STATE=0) | -14 | Same family as Phase 1 |
| `? THEN` with no matching `IF` | -15 | |
| `? Execution limit exceeded` | -17 or -40 | Deep recursion guard |
| `? SYNONYM chain too deep` | -17 | |
| `? Invalid search order count` / full / empty | -20 | Illegal argument |

**~35 sites** in `TZForth.swift` compile/control sections.

---

## Phase 3 — Defining words, dictionary, search order

| Message | Code |
|---------|------|
| `? : needs a name` / empty tick name | -10 |
| `? FORGET needs a name` | -10 |
| `? Cannot FORGET kernel word` | -20 |
| `? word ?` (SEE/FORGET/HELP) | -13 |
| `? SYNONYM ? oldname` | -13 |
| `? duplicate local` / `? too many locals` | -20 |
| `? RECURSE with no current definition` | -20 |
| `? DOES> without a preceding CREATE` | -20 |
| `? MARKER needs a name` | -10 |
| `ALLOCATE` / `FREE` / `RESIZE` failures | keep `ior` on stack (not THROW) |

**~40 sites.**

---

## Phase 4 — File I/O, host integration, edge cases

| Message | Code | Notes |
|---------|------|-------|
| `? INCLUDE-FILE: invalid fileid` | -66* | *File-access range if adopted |
| `? INCLUDED could not open` | Host / `ior` | May stay non-THROW |
| `? FLOAD could not read` | Host | Keep `errorFlag`; not in Forth execution model |
| `? GROWMEMORYMB already used` | -20 | |
| `? DUMP out of range` | -7 | |
| Corrupted SP/RSP auto-recover | -3/-5 after repair | Log repair note, then throw |

**~25 sites** plus host-only paths that may never THROW.

---

## Implementation checklist (per site)

When converting `errorFlag = true` → `kernelThrow`:

1. **Remove dummy stack pushes** on fault paths (`/` pushing `0` after div-by-zero).
2. **Do not `tell` before `kernelThrow`** — message goes through `lastKernelThrowMessage`.
3. **Check `throwActive`** after primitive returns in `innerThread` and `execute`.
4. **Outer interpreter** — `while` already tests `!throwActive`; verify no `errorFlag` needed when throw caught.
5. **Compile-time errors** — decide: stay `errorFlag` for “open definition” UX, or THROW -14/-15. Phase 2+.
6. **FTEST** — add CATCH test for each new code; keep uncaught tests expecting same `?` text.

### Compile-error special case

`recoverFromError()` deliberately **keeps colon definitions open** on interactive compile errors. If compile faults THROW -14/-15:

- **Caught:** definition may be left inconsistent — document or abort definition in `restoreExceptionFrame`.
- **Uncaught:** same open-def behavior as today.

Recommend: Phase 2+ for compile control; Phase 1 focuses on **interpret and run-time primitives**.

---

## Testing strategy

### Existing (unchanged expectations)

- `ABORT` / `ABORT"` / `CATCH` / `THROW` tests in `TestTZForth.swift` / `TZForthTests.swift`
- `? baz` from vocab isolation test (uncaught -13)
- `MARKER` test `? t7w1` (uncaught -13)

### New (Phase 1)

```forth
: t-div  ['] / catch ;
t-div 1 0 t-div .   → -9

: t-undef  ['] no-such-word-xyz catch ;
t-undef .            → -13

: t-under  ['] drop catch ;
t-under .            → -3
```

### Full migration exit criteria

- [ ] All §9.3.1 codes -3…-17 mapped or explicitly exempted
- [ ] `grep errorFlag = true` only host/FLOAD/uncaught-handler paths
- [ ] FTEST count updated; `ANS_COMPLIANCE.md` Exception section revised
- [ ] `ANS-VALIDATE` / Hayes-style exception suite (future)

---

## File touch list

| File | Changes |
|------|---------|
| `TZForth/TZForth.swift` | `StdThrow`, `kernelThrow`, `pop`/`push`/…, `innerThread`, fault sites |
| `TZForth/TestTZForth.swift` | New CATCH tests |
| `TZForth/TZForthTests.swift` | Mirror tests |
| `ANS_COMPLIANCE.md` | Phase status, CATCH on standard codes |
| `THROW_CODES.md` | This plan (living doc) |

---

## Estimated effort

| Phase | Sites | Risk | Time |
|-------|-------|------|------|
| 1 (done) | ~25 | Medium — stack/div0/undef | 2–3 h |
| 2 | ~35 | High — compile/control | 4–6 h |
| 3 | ~40 | Medium | 3–4 h |
| 4 | ~25 | Low–medium | 2–3 h |

**Total:** ~12–16 h for full migration; Phase 1 delivers the highest user value (CATCH on runtime faults).