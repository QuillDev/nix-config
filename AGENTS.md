# Agent Instructions

This machine is managed as a reproducible NixOS system. Treat configuration
changes as declarative infrastructure changes by default.

## NixOS Configuration

- Prefer editing the flake-based NixOS configuration in
  `/home/quill/nix-config`.
- This repository is the active source of truth. Do not redirect configuration
  work to a separate `nix-home` checkout.
- Keep the flake modular as it grows. Prefer small concern-based modules over a
  large `configuration.nix`: host/global basics in `configuration.nix`,
  machine-level desktop/services/packages in `modules/`, and user Home Manager
  configuration in `home/`.
- System packages, services, display-manager settings, fonts, desktop portals,
  drivers, and other machine-level configuration should be declared in the
  flake's NixOS modules.
- User-level application and desktop configuration should be declared through
  Home Manager from the same flake.
- Avoid hand-editing files under `~/.config` when the setting can reasonably be
  represented in Nix or Home Manager.
- If an imperative change is needed for quick testing, either move it into Nix
  before finishing or clearly report that it remains non-declarative.

## Rebuild Workflow

- Validate changes with:

  ```sh
  nixos-rebuild build --flake /home/quill/nix-config#nixos
  ```

- When the build succeeds and the user wants the change applied now, use:

  ```sh
  sudo nixos-rebuild switch --flake /home/quill/nix-config#nixos
  ```

- Use `boot` instead of `switch` when changing risky boot, graphics, or login
  behavior and the user has not explicitly asked to apply it live.

## General Principles

- Keep changes cloneable: a fresh checkout of the flake should be enough to
  reproduce the intended system and user environment.
- Preserve the currently working Hyprland-first desktop setup unless the user
  asks for a session or desktop change. Plasma may be present in the config, but
  do not treat it as a required fallback policy.
- Prefer small, reviewable Nix changes over ad hoc local state.

## Visual Style

- Prefer dark, close-to-black backgrounds for configurable UI surfaces.
- Use pink as the primary accent color. When a secondary/inverted treatment is
  needed, prefer a pink background with black foreground text or icons.
- Current palette:
  - `#050507` black/base background
  - `#0b0b10` surface background
  - `#15121a` weak/elevated surface
  - `#241827` strong/elevated surface
  - `#f7eef5` primary text
  - `#cdbfca` muted text
  - `#ff4fa3` primary pink accent
  - `#ff79bd` strong pink accent
  - `#b83275` weak pink accent
- Apply this palette declaratively through Nix/Home Manager whenever the app
  supports configuration.

## Secrets

- Never commit or declaratively store personal secrets, API keys, OAuth tokens,
  private keys, passwords, recovery codes, or other credentials in this
  repository.
- If a tool needs credentials, keep the secret material in an external secret
  store or user-managed local state, and only commit non-secret references,
  package installs, or documented setup steps.
- Before publishing or pushing changes that touch authentication, provider, or
  agent configuration, check the diff for accidental secrets.
