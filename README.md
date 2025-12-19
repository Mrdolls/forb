# ForbCheck

ForbCheck is a specialized binary analysis tool developed for students at 42 School. It automates the verification of external function calls within an executable, ensuring compliance with project-specific authorization lists.

By cross-referencing undefined symbols extracted via `nm` against a user-defined whitelist, ForbCheck helps developers identify forbidden function calls before final evaluation.

---

## Technical Features

* **Smart Symbol Filtering**: Automatically excludes standard compiler routines and system-level symbols (e.g., `_start`, `_stack_chk_fail`, `ITM_` routines) to focus only on developer-called functions.
* **Automated Compilation**: Detects if a target binary is missing and attempts to trigger a build via `make` automatically.
* **Intelligent Editor Detection**: The configuration interface prioritizes VS Code, falling back to Vim or Nano based on system availability.
* **Flexible Input Parsing**: Handles function lists separated by commas, spaces, or newlines, allowing for easy copy-pasting from project subjects.
* **Silent by Default**: Optimized for workflow integration by only reporting forbidden calls, with an optional verbose mode for full transparency.

---

## Installation

The installation script clones the repository into a hidden directory in your home folder and configures a global alias.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Mrdolls/forb/refs/heads/main/install.sh)"
```
Note: After installation, restart your shell or run source ~/.zshrc (or ~/.bashrc) to enable the command.

---

## Usage

### Basic Check
Run a silent check on your executable. It will only output forbidden functions if any are found.
```bash
forb <executable_name>
```
### Verbose Mode
Display all detected external functions, including those that are authorized.
```bash
forb -a <executable_name>
```
### Configuration
Open your master authorization list (~/.forb/authorize.txt) in your preferred editor.
```bash
forb -e
```
### Uninstallation
Completely remove the tool, its configuration, and its alias from your system.
```bash
forb -u
```
---

## OS Compatibility

- Linux: Optimized for Ubuntu and Debian-based distributions.
- macOS: Full support for Mach-O binaries and underscore-prefixed symbols.
