# forb
<img width="394" height="190" alt="image" src="https://github.com/user-attachments/assets/8b3ac2eb-bb1a-46fe-b255-83398cd89623" />

## Overview

**forb** (ForbCheck) is a static analysis command-line tool designed for 42 school projects. Its purpose is to detect **forbidden function calls** inside a compiled binary by analyzing unresolved symbols and tracing their real origin in the user's object files.

Unlike runtime testers, **forb** works directly on the executable and object files, making it reliable against hidden or indirect calls.

---

## Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mrdolls/forb/refs/heads/main/install.sh)"
```

---

## What forb Does

* Analyzes an executable using `nm`
* Lists all undefined symbols (external function calls)
* Compares them against an authorized function list
* Traces forbidden symbols back to the user's `.o` or `.a` files
* Ignores system, compiler-generated, and library-internal calls

This makes **forb** particularly suited for detecting:

* Hidden forbidden functions
* Indirect calls via wrappers
* Calls introduced through custom libraries

---

## Key Features

### Smart Symbol Tracing

* Uses `nm` on user object and archive files
* Confirms whether a forbidden function truly originates from user code
* Avoids false positives caused by system libraries

### Authorized Function List

* Configurable via `authorize.txt`
* Comma or space separated
* Easily editable through a dedicated command option

### Compiler Noise Filtering

* Ignores internal symbols (`__*`, `_start`, etc.)
* Detects common GCC builtins
* Provides hints when a function may be compiler-generated

### Project-Specific Filters

* MiniLibX filtering mode
* Math library filtering mode
* Designed to match real 42 evaluation constraints

### Clear and Actionable Output

* Explicit `FORBIDDEN` vs `OK` status
* Precise indication of which object file introduced the call
* Summary result with failure count

---

## Usage

```bash
forb [options] <executable>
```

### Common Options

* `-a`   Show all detected symbols (including allowed and skipped)
* `-mlx` Enable MiniLibX filter
* `-lm`  Enable math library filter
* `-e`   Edit the authorized function list
* `-u`   Uninstall forb

---

## Typical Workflow

1. Compile your project
2. Run `forb -e` for editing the allowed fonctions list
3. Run `forb` on the resulting executable
4. Inspect forbidden calls and their origin
5. Fix violations and recompile

---

## Why forb Exists

Some forbidden functions do not appear directly in source code but are introduced indirectly through helper functions, libraries, or optimizations. **forb** was created to catch those cases reliably and transparently.

It aims to behave as closely as possible to what an evaluator would detect, without relying on heuristics or assumptions.

---

## Requirements

* Bash
* GNU binutils (`nm`)
* Make (optional, for auto-compilation)

---

## Version

Current version: **2.0.0**

