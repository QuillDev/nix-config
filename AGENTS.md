# Agent Instructions

This machine is managed as a reproducible NixOS system. Treat configuration
changes as declarative infrastructure changes by default.

## NixOS Configuration

- Prefer editing the flake-based NixOS configuration in
  `/home/quill/nix-config`.
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
- Keep Plasma available as a fallback unless the user explicitly asks to remove
  it.
- Prefer small, reviewable Nix changes over ad hoc local state.
