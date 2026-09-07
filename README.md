# Codex TerminalBar

Codex TerminalBar adds compact progress bars to the Codex CLI footer for context usage and the
five-hour and weekly account limits.

<img width="1231" height="108" alt="Screenshot 2026-09-06 195555" src="https://github.com/user-attachments/assets/06797c88-5cca-4612-885b-9d1320db47f3" />

Every bar fills as usage is consumed. The percentage remains visible, and account limits show the
time remaining next to the limit label in `HH:MM` form, such as `5h 02:34` or `weekly 121:07`.
Weekly countdowns use total hours, so they can exceed 24. Limits stay hidden until the account
provides rate-limit data, and the countdown is omitted when no reset timestamp is available.

## Compatibility

The current patch targets Codex CLI `0.153.4` exactly:

- Upstream tag: `rust-v0.153.4`
- Upstream commit: `3d2ee51ca2d5db578f328aa75e20aa22c0197c9a`
- Platform covered by the installer: Windows PowerShell

Codex changes quickly, so do not apply this patch to another version without reviewing and testing
the resulting diff.

## Prerequisites

Install these before running the setup script:

- [Git for Windows](https://git-scm.com/download/win)
- [Rust through rustup](https://rustup.rs/)
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) with the
  **Desktop development with C++** workload

The first build downloads the Codex Rust dependencies and can take several minutes.

## Install

Clone this repository and run the installer from PowerShell:

```powershell
git clone https://github.com/CaiCheng-Li/Codex-TerminalBar.git
cd Codex-TerminalBar
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

The installer:

1. Clones the matching OpenAI Codex source into `%LOCALAPPDATA%\Codex-TerminalBar`.
2. Applies [`patches/codex-terminal-bar-v0.153.4.patch`](patches/codex-terminal-bar-v0.153.4.patch).
3. Builds `codex.exe` and `codex-code-mode-host.exe` locally.
4. Places the build in a timestamped directory and puts that directory first on your user `PATH`.
5. Backs up `~/.codex/config.toml` and configures the three footer fields.

Close any existing Codex sessions and open a new terminal. Confirm which executable is active:

```powershell
Get-Command codex | Select-Object Source
codex --version
```

The source should point inside `%LOCALAPPDATA%\Codex-TerminalBar\bin-*`, and the version should be
`codex-cli 0.153.4`.

Start Codex normally:

```powershell
codex
```

Rate-limit bars appear after the account usage response arrives. The context bar begins at zero in
a new conversation and fills as the conversation consumes its context window.

## Configure the footer manually

The installer adds this to the user-level `~/.codex/config.toml`:

```toml
[tui]
status_line = ["context-used", "five-hour-limit", "weekly-limit"]
```

If `[tui]` already exists, keep that table and replace or add only its `status_line` entry. Codex can
also reorder footer fields interactively with `/statusline`; the selection is persisted to the same
configuration file. See the official [Codex developer commands](https://learn.chatgpt.com/docs/developer-commands?surface=cli#configure-footer-items-with-statusline)
and [configuration guide](https://learn.chatgpt.com/docs/config-file/config-basic).

## Restore the standard Codex CLI

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore.ps1
```

Open a new terminal afterward. The restore script removes TerminalBar build directories from the
user `PATH`; it leaves the build and source files in `%LOCALAPPDATA%\Codex-TerminalBar` so it does
not disrupt a running session. You can delete that directory after all Codex sessions have exited.

The status-line configuration remains valid in the standard CLI. Use `/statusline` if you want to
change or remove those fields.

## Build and test manually

Apply the patch to a clean checkout of the pinned upstream version:

```powershell
git clone --depth 1 --branch rust-v0.153.4 https://github.com/openai/codex.git codex
git -C codex apply ..\patches\codex-terminal-bar-v0.153.4.patch
cd codex\codex-rs
cargo build -p codex-cli --bin codex
cargo build -p codex-code-mode-host --bin codex-code-mode-host
```

The relevant TUI tests are included in the patch. The development build was verified with focused
tests covering bar rounding, percentage-used rendering, reset-countdown rendering, limit-window
selection, setup previews, and 80-column output.

## How it works

Codex already receives a `usedPercent` value and optional reset timestamp for each quota window. The
patch renders the percentage as a ten-cell bar and converts the reset timestamp into an `HH:MM`
countdown. Context uses the existing context-used calculation and the same bar renderer.
