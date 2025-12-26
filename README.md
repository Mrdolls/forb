# ForbCheck (forb)

**ForbCheck** is a Bash CLI tool designed to analyze a compiled C executable or library and detect the usage of **forbidden functions**, closely matching how projects are evaluated at 42.

It relies on `nm` to inspect unresolved symbols and reports **exact source locations** where forbidden functions are used.

---

## Features

- Detection of forbidden functions in a compiled binary
- Precise source locations (file and line)
- Designed for 42 projects (minishell, cub3d, so_long, etc.)
- __Smart Auto-Detection__: Automatically detects MiniLibX and applies appropriate filters.
- Library filtering:
  - MiniLibX (`-mlx` or auto-detected): Ignores internal calls like puts, exit, or X11 symbols.
  - Math library (`-lm`): Ignores internal math calls
- Customizable authorized functions list
- Context-aware colored output (automatically disabled when redirected)
- Proper exit codes (scriptable / CI-friendly)
- Standalone Bash tool with standard Unix utilities
  
---

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
forb minishell
```

<img width="353" height="199" alt="image" src="https://github.com/user-attachments/assets/f18cb25d-5eee-4cf5-b5ed-6e8db68fd0ff" />


### Show execution time:

```bash
forb -t minishell
```

<img width="376" height="200" alt="image" src="https://github.com/user-attachments/assets/256d012b-c6bb-4554-a6fc-b0bc528c935e" />


### Limit analysis to specific files:

```bash
forb minishell -f heredoc_utils.c
```

<img width="506" height="202" alt="image" src="https://github.com/user-attachments/assets/b1a8d004-ada1-41c5-80ec-a956f5188e3b" />


### Verbose mode:

```bash
forb -v minishell
```

<img width="541" height="206" alt="image" src="https://github.com/user-attachments/assets/03272465-6a3c-4402-b6bb-8065a377b215" />

---

## Authorized Functions

Authorized functions are defined in:

```text
~/.forb/authorize.txt
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








