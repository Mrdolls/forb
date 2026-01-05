# ForbCheck (forb)

**ForbCheck** is a Bash CLI tool designed to analyze a compiled C executable or library and detect the usage of **forbidden functions**, closely matching how projects are evaluated at 42.

It relies on `nm` to inspect unresolved symbols and reports **exact source locations** where forbidden functions are used.

---

## What's New in v1.5.1!

### Smart Sync Detection
- Desync Warning: If you modify your .c files but forget to recompile (make), ForbCheck will warn you that the results might be outdated.

- Intelligent Cache: It tracks the "state" of your project (line count and file size).

- Undo-Friendly: If you modify a file and then undo your changes (Ctrl+Z), the warning disappears automatically—no false positives for simple formatting or accidental saves.

### Enhanced CLI Experience
- Reorganized Help: A cleaner `--help` menu for better readability during intense coding sessions.

- Hybrid List Command: Use `-l` to view all authorized functions, or `forb -l <func>` to quickly check specific ones.

- Global Awareness: The script now recognizes when you switch between different projects (e.g., from `minishell` to `cub3d`) and updates its internal reference accordingly.

### Performance & Accuracy
- Blazing Fast: Under 0.2s for most projects (benchmarked on mid-to-high-end hardware).

- Optimized: Even on standard school lab machines, the overhead remains negligible, ensuring your workflow is never interrupted.

## Requirements

- `bash`
- `nm` (GNU binutils)
- `grep`, `awk`, `sed`
- `bc` (optional, for execution time display)

---

## Installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mrdolls/forb/refs/heads/main/install.sh)"
```

---

## Usage

```bash
forb [options] <target> [-f <files...>]
```

### Argument

- `<target>`: Executable or library to analyze

---

## Options

### General
| Option | Description |
|------|-------------|
| `-h`, `--help` | Display help message |
| `-l`, `--list` `[<funcs...>]` | Show list or check specific functions |
| `-e`, `--edit` | Edit authorized functions list |

### Scan Options

| Option | Description |
|------|-------------|
| `-v`, `--verbose` | Show source code context |
| `-f <files...>` | Limit analysis to specific files |
| `-p`, `--full-path` | Show full paths |
| `-a`, `--all` | Show authorized functions during scan |
| `--no-auto` | Disable automatic library detection |

### Library Filters

| Option | Description |
|------|-------------|
| `-mlx` | Force ignore MiniLibX internal calls |
| `-lm` | Force Ignore Math library internal calls |

### Maintenance

| Option | Description |
|------|-------------|
| `-t`, `--time` | Show execution duration |
| `-up`, `--update` | Update ForbCheck |
| `--remove` | Uninstall ForbCheck |

---

## Examples

### Basic analysis:

```bash
forb minishell (no forbidden fonctions)
```

<img width="405" height="173" alt="image" src="https://github.com/user-attachments/assets/0ee6b142-d969-4ca9-8f46-d16e9d606420" />


### Show execution time:

```bash
forb -t minishell (with forbidden fonctions)
```

<img width="532" height="320" alt="image" src="https://github.com/user-attachments/assets/383a258a-ce57-4c07-98f8-2e5d0cc2eac3" />


### Limit analysis to specific files:

```bash
forb minishell -f heredoc_utils.c
```

<img width="538" height="202" alt="image" src="https://github.com/user-attachments/assets/7ae6c24a-7452-45ee-aaaf-00f5ffdfcda4" />


### Verbose mode:

```bash
forb -v minishell
```
<img width="545" height="196" alt="image" src="https://github.com/user-attachments/assets/81af8b99-552e-47d7-92e0-83916e4a9bec" />

---

## Authorized Functions

Authorized functions are defined in:

```text
$HOME/.forb/authorize.txt
```

Functions may be separated by new lines, spaces, or commas.

Quick edit:

```bash
forb -e
```

Example:

```text
read
write
malloc
free
```

or

```text
read, write, malloc, free
```

---

## Exit Codes

| Code | Meaning |
|----|---------|
| `0` | No forbidden functions detected |
| `1` | Forbidden functions detected or error occurred |

---

## Design Philosophy

ForbCheck is designed to be:

- Simple
- Readable
- Useful before project evaluations
- Explicit rather than permissive

It is an assistance tool, not a substitute for understanding project requirements.

---

## License

Open-source project intended for educational use.

---

## Author

Mrdolls













