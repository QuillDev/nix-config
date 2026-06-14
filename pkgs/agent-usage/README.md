# agent-usage

A tiny, dependency-free reporter of **AI coding-agent usage limits** for a
status bar — how much of each provider's rate-limit windows (the rolling
5-hour window and the weekly/long window) you've burned through, so you can see
at a glance how close you are to being throttled without opening a dashboard.

Inspired by [CodexBar](https://github.com/steipete/CodexBar) (macOS menu bar),
reimplemented for Linux / Wayland and wired into the
[ashell](https://github.com/MalpenZibo/ashell) bar via a `CustomModule`.

## Providers

| Provider | Source | Auth | Notes |
|----------|--------|------|-------|
| **Codex** (`cx`) | `~/.codex/sessions/**/*.jsonl` | none | Reads the `rate_limits` object Codex writes into every `token_count` event. Fully local. |
| **Claude Code** (`cc`) | `GET https://api.anthropic.com/api/oauth/usage` | OAuth token from `~/.claude/.credentials.json` (`claudeAiOauth.accessToken`) | Reports `five_hour`, `seven_day`, and (if present) the Opus weekly cap. |
| **Kimi** (`km`) | `GET https://api.kimi.com/coding/v1/usages` | OAuth token from `~/.kimi-code/credentials/kimi-code.json` | The access token is short-lived (~15 min); it's refreshed via the `refresh_token` against `https://auth.kimi.com/api/oauth/token` and written back atomically (preserving file mode `600`), the same way the kimi-code CLI does. |

**Cursor is not implemented.** Cursor only exposes usage through an
authenticated browser session (cookies from `cursor.com`); there is no clean,
declarative, headless path for it on Linux. It can be added later by reading the
browser cookie store, but that's deliberately out of scope here.

No secrets are stored by this tool. It reads existing credential files at
runtime and never copies tokens anywhere.

## Usage

```sh
agent-usage              # one compact bar line, e.g.  cc 14%  ·  cx 6%  ·  km 5%
agent-usage --watch      # reprint the line every --interval seconds (for ashell)
agent-usage --interval 30
agent-usage --detail     # multi-line breakdown with reset ETAs
agent-usage --notify     # send the breakdown as a desktop notification
agent-usage --json       # structured output
```

The headline percentage per provider is the **most-constrained** window (the
max across that provider's windows) — the number that actually predicts a
throttle. A provider that isn't set up is omitted from the bar line; one whose
fetch fails shows `tag !` (e.g. `cc !` when the Claude token has expired and
needs a `claude` login to refresh).

## Bar integration (ashell)

In `~/.config/ashell/config.toml`:

```toml
[[CustomModule]]
name = "AgentUsage"
type = "Button"
listen_cmd = "agent-usage --watch --interval 60"
command = "agent-usage --notify"
alert = "8[0-9]%|9[0-9]%|100%|!"   # red dot at >=80% or on any error

[modules]
right = [ [ "AgentUsage", "Tempo", "Privacy", "Settings" ] ]
```

In this repo it's declared through Nix/Home Manager — see `home/quill.nix` and
`pkgs/agent-usage/` in the nix-config flake.

## Requirements

- Python 3 (stdlib only)
- `notify-send` (libnotify) for `--notify`
