{ pkgs, inputs, ... }:

let
  palette = {
    black = "#050507";
    surface = "#0b0b10";
    surfaceWeak = "#15121a";
    surfaceStrong = "#241827";
    text = "#f7eef5";
    muted = "#cdbfca";
    pink = "#ff4fa3";
    pinkStrong = "#ff79bd";
    pinkWeak = "#b83275";
    danger = "#ff5c8a";
    warning = "#f5a524";
    success = "#66e3a1";
  };

  kimi-code = pkgs.callPackage ../pkgs/kimi-code { };
  qmenu = inputs.qmenu.packages.${pkgs.system}.default;
  agent-usage = inputs.agent-usage.packages.${pkgs.system}.default;

  # Toggle (or explicitly close) the eww agent-usage popup; polling only runs
  # while it is open (gated by the usage_open var in eww.yuck). The backdrop's
  # click handler calls this with `close`.
  agent-usage-popup = pkgs.writeShellScriptBin "agent-usage-popup" ''
    eww=${pkgs.eww}/bin/eww
    case "''${1:-toggle}" in
      close)
        "$eww" close usage
        "$eww" update usage_open=false
        ;;
      *)
        if "$eww" active-windows 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q usage; then
          "$eww" close usage
          "$eww" update usage_open=false
        else
          # Open on the monitor under the cursor, centred on the chip we just
          # clicked (cursor x relative to that monitor), clamped to it. Multi-
          # monitor aware; falls back to a single 1920px screen without Hyprland.
          # pw ~= min-width(304) + padding(36) + border(4).
          pw=344
          pos=$(hyprctl cursorpos 2>/dev/null | ${pkgs.coreutils}/bin/tr -dc '0-9,-')
          cx=$(printf '%s' "$pos" | ${pkgs.coreutils}/bin/cut -d, -f1)
          cy=$(printf '%s' "$pos" | ${pkgs.coreutils}/bin/cut -d, -f2)
          geo=$(hyprctl monitors -j 2>/dev/null | ${pkgs.jq}/bin/jq -r \
            --argjson cx "''${cx:-0}" --argjson cy "''${cy:-0}" \
            '(map(select($cx >= .x and $cx < (.x + .width/.scale) and $cy >= .y and $cy < (.y + .height/.scale))) | first)
             // (map(select(.focused)) | first) // .[0]
             | "\(.name)\t\((($cx - .x))|floor)\t\((.width/.scale)|floor)"' 2>/dev/null)
          mon=$(printf '%s' "$geo" | ${pkgs.coreutils}/bin/cut -f1)
          relx=$(printf '%s' "$geo" | ${pkgs.coreutils}/bin/cut -f2)
          lw=$(printf '%s' "$geo" | ${pkgs.coreutils}/bin/cut -f3)
          [ -n "$lw" ] || lw=1920
          [ -n "$relx" ] || relx=$((lw - 2))
          x=$((relx - pw / 2))
          [ "$x" -lt 6 ] && x=6
          max=$((lw - pw - 6)); [ "$x" -gt "$max" ] && x=$max
          if [ -n "$mon" ]; then
            "$eww" open usage --screen "$mon" --arg xpos="$x"
          else
            "$eww" open usage --arg xpos="$x"
          fi
          "$eww" update usage_open=true
        fi
        ;;
    esac
  '';

  kimi-yolo = pkgs.writeShellScriptBin "kimi" ''
    for arg in "$@"; do
      case "$arg" in
        -p|--prompt|--prompt=*|--auto|--plan|-h|--help|-V|--version|upgrade|acp)
          exec ${kimi-code}/bin/kimi "$@"
          ;;
      esac
    done

    exec ${kimi-code}/bin/kimi --yolo "$@"
  '';

  screenshot-selection = pkgs.writeShellScriptBin "screenshot-selection" ''
    set -euo pipefail

    geometry="$(${pkgs.slurp}/bin/slurp -d)"
    ${pkgs.grim}/bin/grim -g "$geometry" - | ${pkgs.wl-clipboard}/bin/wl-copy --type image/png
    ${pkgs.libnotify}/bin/notify-send -u low -i camera-photo "Screenshot copied" "Selection copied to clipboard."
  '';

  agent-mode-lib = ''
    uid="$(${pkgs.coreutils}/bin/id -u)"
    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$uid}"
    state_dir="$runtime_dir/agent-mode"
    pidfile="$state_dir/inhibit.pid"
    enabled_file="$state_dir/enabled"

    mkdir -p "$state_dir"

    is_active() {
      [ -s "$pidfile" ] || return 1
      pid="$(${pkgs.coreutils}/bin/cat "$pidfile" 2>/dev/null || true)"
      [ -n "$pid" ] && ${pkgs.procps}/bin/ps -p "$pid" -o args= 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q systemd-inhibit
    }

    lid_closed() {
      ${pkgs.gnugrep}/bin/grep -qi closed /proc/acpi/button/lid/*/state 2>/dev/null
    }

    internal_outputs() {
      ${pkgs.hyprland}/bin/hyprctl monitors -j 2>/dev/null \
        | ${pkgs.jq}/bin/jq -r '.[] | select(.name | test("^(eDP|LVDS|DSI)-")) | .name' 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -v '^$' || true
    }

    set_internal_power() {
      mode="$1"
      outputs="$(internal_outputs)"
      [ -n "$outputs" ] || outputs="eDP-1"

      printf '%s\n' "$outputs" | while IFS= read -r output; do
        [ -n "$output" ] || continue
        case "$mode" in
          off) ${pkgs.wlopm}/bin/wlopm --off "$output" >/dev/null 2>&1 || true ;;
          on)  ${pkgs.wlopm}/bin/wlopm --on "$output" >/dev/null 2>&1 || true ;;
        esac
      done
    }

    apply_lid_state() {
      if is_active && lid_closed; then
        set_internal_power off
      else
        set_internal_power on
      fi
    }
  '';

  agent-mode-toggle = pkgs.writeShellScriptBin "agent-mode-toggle" ''
    set -euo pipefail
    ${agent-mode-lib}

    if [ "''${1:-}" = "--status" ]; then
      is_active
      exit "$?"
    fi

    if is_active; then
      pid="$(${pkgs.coreutils}/bin/cat "$pidfile")"
      kill "$pid" 2>/dev/null || true
      rm -f "$pidfile" "$enabled_file"
      set_internal_power on
      ${pkgs.libnotify}/bin/notify-send -u low "Agent Mode off" "Lid close will use normal suspend behavior."
      exit 0
    fi

    ${pkgs.systemd}/bin/systemd-inhibit \
      --what=sleep:idle:handle-lid-switch \
      --who="Agent Mode" \
      --why="Keep AI agents and local processes running while the laptop lid is closed" \
      --mode=block \
      ${pkgs.coreutils}/bin/sleep infinity &

    pid="$!"
    printf '%s\n' "$pid" > "$pidfile"
    : > "$enabled_file"
    apply_lid_state
    ${pkgs.libnotify}/bin/notify-send -u low "Agent Mode on" "Sleep and lid suspend are blocked. Closing the lid will turn off the internal display."
  '';

  agent-mode-status = pkgs.writeShellScriptBin "agent-mode-status" ''
    set -euo pipefail
    ${agent-mode-lib}

    while true; do
      if is_active; then
        printf '{"text":"","alt":"active","tooltip":"Agent Mode active: lid sleep blocked"}\n'
      else
        printf '{"text":"","alt":"inactive","tooltip":"Agent Mode off"}\n'
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done
  '';

  agent-mode-lid-watch = pkgs.writeShellScriptBin "agent-mode-lid-watch" ''
    set -euo pipefail
    ${agent-mode-lib}

    last=""
    while true; do
      if is_active && lid_closed; then
        current="headless"
      else
        current="display"
      fi

      if [ "$current" != "$last" ]; then
        apply_lid_state
        last="$current"
      fi

      ${pkgs.coreutils}/bin/sleep 2
    done
  '';

  # App launcher: qmenu in drun mode reads XDG .desktop entries and prints the
  # chosen app's Exec line, which we run detached. Toggles: if qmenu is already
  # open, pressing the same hotkey again closes it instead of opening a second.
  qmenu-launch = pkgs.writeShellScriptBin "qmenu-launch" ''
    pidfile="''${XDG_RUNTIME_DIR:-/tmp}/qmenu.pid"

    # Already open? Close it and stop (this is the "toggle off" press).
    if [ -f "$pidfile" ]; then
      oldpid="$(${pkgs.coreutils}/bin/cat "$pidfile" 2>/dev/null)"
      if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
        kill "$oldpid" 2>/dev/null
        rm -f "$pidfile"
        exit 0
      fi
      rm -f "$pidfile"  # stale pidfile from a crashed instance
    fi

    out="$(${pkgs.coreutils}/bin/mktemp)"
    QMENU_TERMINAL=ghostty ${qmenu}/bin/qmenu --drun > "$out" &
    qpid=$!
    echo "$qpid" > "$pidfile"
    wait "$qpid"
    rm -f "$pidfile"

    choice="$(${pkgs.coreutils}/bin/cat "$out")"
    rm -f "$out"
    [ -n "$choice" ] && exec ${pkgs.util-linux}/bin/setsid -f ${pkgs.bash}/bin/bash -c "$choice"
  '';
in

{
  # Fish is enabled at the NixOS level so it is a registered login shell
  # (/etc/shells) and gets its system-wide completions wired up. Per-user
  # interactive config lives in the Home Manager block below.
  programs.fish.enable = true;

  users.users."quill" = {
    isNormalUser = true;
    description = "Robert Brunson";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";

    users."quill" = { ... }: {
      home = {
        username = "quill";
        homeDirectory = "/home/quill";
        stateVersion = "26.05";
        packages = [
          kimi-yolo
          screenshot-selection
          agent-mode-toggle
          agent-mode-status
          agent-mode-lid-watch
          qmenu-launch
          agent-usage
          agent-usage-popup
          inputs.wt.packages.${pkgs.stdenv.hostPlatform.system}.default
          pkgs.eww
        ];
      };

      programs.home-manager.enable = true;
      xdg.enable = true;

      systemd.user.services.hyprpaper = {
        Unit = {
          Description = "Hyprland wallpaper daemon";
          PartOf = [ "default.target" ];
        };

        Service = {
          ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
          Restart = "on-failure";
          RestartSec = 1;
        };
      };

      # Fish is the interactive shell. Bash stays enabled so that
      # `#!/usr/bin/env bash` scripts and `bash -lc` always have a sane
      # environment; its aliases only apply if you drop into bash manually.
      programs.bash = {
        enable = true;
        shellAliases = {
          cc = "IS_SANDBOX=1 claude --dangerously-skip-permissions";
          sudo = "sudo ";
        };
      };

      programs.fish = {
        enable = true;
        shellAliases = {
          # `sudo `-with-trailing-space is a bash alias-expansion hack and is
          # unnecessary in fish, so only the meaningful alias is ported.
          cc = "IS_SANDBOX=1 claude --dangerously-skip-permissions";
          # Default the nicer tools. `ll`/`la` keep the long/all views handy;
          # `cat` -> bat for syntax-highlighted paging.
          ls = "eza --git --icons=auto";
          ll = "eza --git --icons=auto -l";
          la = "eza --git --icons=auto -la";
          cat = "bat";
        };
        interactiveShellInit = ''
          # Quieter startup: drop the default fish greeting.
          set -g fish_greeting

          # Load wt as a fish function so `wt goto` can cd in this shell.
          ${inputs.wt.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/wt shell-init --shell fish | source
        '';
      };

      # Pink-on-black prompt (palette above). Home Manager auto-injects the
      # fish/bash init hooks for starship and the tools below.
      programs.starship = {
        enable = true;
        settings = {
          add_newline = false;
          character = {
            success_symbol = "[❯](bold #ff4fa3)";
            error_symbol = "[❯](bold #ff5c8a)";
            vimcmd_symbol = "[❮](bold #ff79bd)";
          };
          directory.style = "bold #ff79bd";
          git_branch.style = "#cdbfca";
          git_status.style = "#f5a524";
        };
      };

      # Interactive ergonomics, all declarative and Nix-managed.
      programs.fzf.enable = true; # ctrl-r history / ctrl-t file search
      programs.zoxide.enable = true; # smarter `cd` (use `z <dir>`)
      programs.eza = {
        enable = true;
        git = true;
        icons = "auto";
      };
      programs.bat = {
        enable = true;
        config.theme = "base16";
      };
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true; # fast, cached `.envrc` for Nix shells
      };

      xdg.configFile."ashell/config.toml".text = ''
        log_level = "warn"
        position = "Top"
        layer = "Top"

        [appearance]
        style = "Islands"
        font_name = "Inter"
        opacity = 0.96
        text_color = "${palette.text}"
        workspace_colors = [ "${palette.pink}", "${palette.pinkStrong}" ]
        special_workspace_colors = [ "${palette.pinkStrong}", "${palette.pink}" ]
        success_color = "${palette.success}"

        [appearance.primary_color]
        base = "${palette.pink}"
        strong = "${palette.pinkStrong}"
        weak = "${palette.pinkWeak}"
        text = "${palette.black}"

        [appearance.secondary_color]
        base = "${palette.pink}"
        strong = "${palette.pinkStrong}"
        weak = "${palette.pinkWeak}"
        text = "${palette.black}"

        [appearance.background_color]
        base = "${palette.surface}"
        weak = "${palette.surfaceWeak}"
        strong = "${palette.surfaceStrong}"

        [appearance.danger_color]
        base = "${palette.danger}"
        weak = "${palette.warning}"

        [appearance.menu]
        opacity = 0.98
        backdrop = 0.2

        [tempo]
        clock_format = "%a %d %b %-I:%M %p"

        # AI coding-agent usage limits (Claude Code / Codex / Kimi / Cursor). An icon-only
        # chip; listen_cmd streams Waybar-format JSON whose `alt` lights the alert
        # dot at >=80% or on error. Clicking toggles the eww popup with per-provider
        # logos and % bars. Icon is a Nerd Font gauge (U+F0E4) via symbols-only
        # fallback. Package: github:QuillDev/agent-usage (flake input); popup
        # config is the eww.yuck below.
        [[CustomModule]]
        name = "AgentUsage"
        type = "Button"
        icon = "${builtins.fromJSON ''""''}"
        listen_cmd = "${agent-usage}/bin/agent-usage --watch --interval 60 --providers cc,cx,km,cu --remaining"
        command = "${agent-usage-popup}/bin/agent-usage-popup"
        alert = "\"alt\":\"alert\""

        [settings]
        remove_idle_btn = true
        indicators = [ "PowerProfile", "Audio", "Microphone", "Bluetooth", "Network", "Vpn", "Battery", "Brightness" ]

        [[settings.CustomButton]]
        name = "Agent Mode"
        icon = "☕"
        command = "${agent-mode-toggle}/bin/agent-mode-toggle"
        status_command = "${pkgs.bash}/bin/bash -lc '${agent-mode-toggle}/bin/agent-mode-toggle --status'"
        tooltip = "Keep agents running with the lid closed"

        # Keep ashell's default left/center; add AgentUsage to the right island.
        [modules]
        left = [ "Workspaces" ]
        center = [ "WindowTitle" ]
        right = [ [ "AgentUsage", "Tempo", "Privacy", "Settings" ] ]
      '';

      # eww popup for the AgentUsage chip: per-provider logo + % bar + reset.
      # Polling (`agent-usage --eww`) only runs while the window is open, gated
      # by `usage_open`, which agent-usage-popup toggles. Note: eww's own string
      # interpolation would be `''${...}` here, so we use the `{expr}` form
      # instead and let Nix interpolate ${...} (store paths / palette).
      xdg.configFile."eww/eww.yuck".text = ''
        (defvar usage_open false)

        (defpoll usage
          :interval "30s"
          :run-while usage_open
          :initial "{\"cc\":{\"name\":\"Claude Code\",\"present\":true,\"shown\":true,\"error\":\"\",\"w1\":{\"label\":\"5h\",\"pct\":0,\"state\":\"ok\",\"reset\":\"\",\"present\":true},\"w2\":{\"label\":\"7d\",\"pct\":0,\"state\":\"ok\",\"reset\":\"\",\"present\":true}},\"cx\":{\"name\":\"Codex\",\"present\":true,\"shown\":true,\"error\":\"\",\"w1\":{\"label\":\"5h\",\"pct\":0,\"state\":\"ok\",\"reset\":\"\",\"present\":true},\"w2\":{\"label\":\"7d\",\"pct\":0,\"state\":\"ok\",\"reset\":\"\",\"present\":true}},\"km\":{\"name\":\"Kimi\",\"present\":true,\"shown\":true,\"error\":\"\",\"w1\":{\"label\":\"5h\",\"pct\":0,\"state\":\"ok\",\"reset\":\"\",\"present\":true},\"w2\":{\"label\":\"7d\",\"pct\":0,\"state\":\"ok\",\"reset\":\"\",\"present\":true}},\"cu\":{\"name\":\"Cursor\",\"present\":true,\"shown\":true,\"error\":\"\",\"w1\":{\"label\":\"auto\",\"pct\":0,\"state\":\"ok\",\"reset\":\"\",\"present\":true},\"w2\":{\"label\":\"api\",\"pct\":0,\"state\":\"ok\",\"reset\":\"\",\"present\":true}}}"
          "${agent-usage}/bin/agent-usage --eww --providers cc,cx,km,cu --remaining")

        ; one window's bar: short label, coloured progress, percent, reset ETA
        (defwidget barrow [label pct state reset visible]
          (box :class "barrow" :orientation "h" :space-evenly false :spacing 8 :visible visible
            (label :class "wlabel" :text label)
            (progress :class {"bar bar-" + state} :value pct :orientation "h" :hexpand true)
            (label :class "wpct" :text {pct + "%"})
            (label :class "reset" :text reset)))

        ; one provider: logo + name (+ error), then its 5h and weekly bars
        (defwidget prow [logo name error
                         w1l w1p w1s w1r w1v
                         w2l w2p w2s w2r w2v
                         visible]
          (box :class "row" :orientation "v" :space-evenly false :spacing 5 :visible visible
            (box :orientation "h" :space-evenly false :spacing 10
              (image :class "logo" :path logo :image-width 20 :image-height 20)
              (label :class "name" :halign "start" :hexpand true :text name)
              (label :class "err" :halign "end" :text error :visible {error != ""}))
            (barrow :label w1l :pct w1p :state w1s :reset w1r :visible w1v)
            (barrow :label w2l :pct w2p :state w2s :reset w2r :visible w2v)))

        (defwidget usage-content []
          (box :class "popup" :orientation "v" :space-evenly false :vexpand false :valign "start" :spacing 14
            (label :class "title" :halign "start" :text "USAGE REMAINING")
            (prow :logo "${agent-usage}/share/agent-usage/icons/claude.svg"
                  :name {usage.cc.name} :error {usage.cc.error} :visible {usage.cc.shown && usage.cc.present}
                  :w1l {usage.cc.w1.label} :w1p {usage.cc.w1.pct} :w1s {usage.cc.w1.state} :w1r {usage.cc.w1.reset} :w1v {usage.cc.w1.present}
                  :w2l {usage.cc.w2.label} :w2p {usage.cc.w2.pct} :w2s {usage.cc.w2.state} :w2r {usage.cc.w2.reset} :w2v {usage.cc.w2.present})
            (prow :logo "${agent-usage}/share/agent-usage/icons/codex.svg"
                  :name {usage.cx.name} :error {usage.cx.error} :visible {usage.cx.shown && usage.cx.present}
                  :w1l {usage.cx.w1.label} :w1p {usage.cx.w1.pct} :w1s {usage.cx.w1.state} :w1r {usage.cx.w1.reset} :w1v {usage.cx.w1.present}
                  :w2l {usage.cx.w2.label} :w2p {usage.cx.w2.pct} :w2s {usage.cx.w2.state} :w2r {usage.cx.w2.reset} :w2v {usage.cx.w2.present})
            (prow :logo "${agent-usage}/share/agent-usage/icons/kimi.svg"
                  :name {usage.km.name} :error {usage.km.error} :visible {usage.km.shown && usage.km.present}
                  :w1l {usage.km.w1.label} :w1p {usage.km.w1.pct} :w1s {usage.km.w1.state} :w1r {usage.km.w1.reset} :w1v {usage.km.w1.present}
                  :w2l {usage.km.w2.label} :w2p {usage.km.w2.pct} :w2s {usage.km.w2.state} :w2r {usage.km.w2.reset} :w2v {usage.km.w2.present})
            (prow :logo "${agent-usage}/share/agent-usage/icons/cursor.svg"
                  :name {usage.cu.name} :error {usage.cu.error} :visible {usage.cu.shown && usage.cu.present}
                  :w1l {usage.cu.w1.label} :w1p {usage.cu.w1.pct} :w1s {usage.cu.w1.state} :w1r {usage.cu.w1.reset} :w1v {usage.cu.w1.present}
                  :w2l {usage.cu.w2.label} :w2p {usage.cu.w2.pct} :w2s {usage.cu.w2.state} :w2r {usage.cu.w2.reset} :w2v {usage.cu.w2.present})))

        ; Full-screen transparent backdrop so a click anywhere outside the popup
        ; dismisses it (like the other bar menus). The popup itself is wrapped in
        ; an eventbox whose no-op onclick swallows clicks so they don't dismiss.
        ; `xpos` (px from the left edge) is computed at open time by
        ; agent-usage-popup to centre the popup under the clicked chip.
        (defwindow usage [xpos]
          :monitor 0
          :geometry (geometry :x "0px" :y "0px" :anchor "top left" :width "100%" :height "100%")
          :stacking "overlay"
          (eventbox :class "backdrop" :onclick "${agent-usage-popup}/bin/agent-usage-popup close"
            (box :orientation "v" :halign "start" :valign "start" :space-evenly false
              (box :class "anchor" :style {"margin-left: " + xpos + "px;"} :orientation "v" :space-evenly false
                (eventbox :onclick "true" (usage-content))))))
      '';

      xdg.configFile."eww/eww.scss".text = ''
        * { all: unset; }

        .backdrop { background-color: transparent; }

        .popup {
          background-color: rgba(5, 5, 7, 0.97);
          border: 2px solid ${palette.pink};
          border-radius: 14px;
          padding: 16px 18px;
          min-width: 304px;        /* keep width predictable for centering */
          margin-top: 36px;        /* drop just below the 34px-tall bar */
        }

        .title {
          color: ${palette.muted};
          font-family: "Inter";
          font-size: 11px;
          font-weight: 700;
        }

        .row { padding: 6px 0; }

        .name { color: ${palette.text}; font-family: "Inter"; font-size: 13px; font-weight: 600; }
        .err  { color: ${palette.warning}; font-family: "Inter"; font-size: 11px; }
        .barrow { padding: 1px 0; }
        .wlabel { color: ${palette.muted}; font-family: "Inter"; font-size: 11px; font-weight: 600; min-width: 22px; }
        .wpct   { color: ${palette.text}; font-family: "Inter"; font-size: 11px; font-weight: 700; min-width: 34px; }
        .reset  { color: ${palette.muted}; font-family: "Inter"; font-size: 10px; min-width: 30px; }

        .bar trough {
          background-color: ${palette.surfaceStrong};
          border-radius: 5px;
          min-height: 7px;
          min-width: 120px;
        }
        .bar progress { border-radius: 5px; min-height: 7px; }
        .bar-ok progress    { background-color: ${palette.pink}; }
        .bar-warn progress  { background-color: ${palette.warning}; }
        .bar-alert progress { background-color: ${palette.danger}; }
      '';

      xdg.configFile."ghostty/config.ghostty".text = ''
        theme =
        window-theme = ghostty
        window-titlebar-background = ${palette.black}
        window-titlebar-foreground = ${palette.text}
        gtk-titlebar-style = tabs
        gtk-single-instance = false

        background = ${palette.black}
        foreground = ${palette.text}
        selection-background = ${palette.pink}
        selection-foreground = ${palette.black}
        cursor-color = ${palette.pink}
        cursor-text = ${palette.black}
        unfocused-split-fill = ${palette.black}

        palette = 0=${palette.black}
        palette = 1=${palette.danger}
        palette = 2=${palette.success}
        palette = 3=${palette.warning}
        palette = 4=#8aadf4
        palette = 5=${palette.pink}
        palette = 6=#8bd5ca
        palette = 7=${palette.muted}
        palette = 8=#5b5360
        palette = 9=#ff7aa8
        palette = 10=#8ff0b3
        palette = 11=#ffd166
        palette = 12=#a6c8ff
        palette = 13=${palette.pinkStrong}
        palette = 14=#9bf6e5
        palette = 15=${palette.text}
      '';

      home.file.".claude/settings.json".text = builtins.toJSON {
        skipDangerousModePermissionPrompt = true;
        permissions.defaultMode = "bypassPermissions";
      };

      # ashell (cosmic-text/fontdb) only reliably discovers fonts from a few
      # standard dirs; linking the Nerd Font symbols here guarantees the gauge
      # glyph on the agent-usage chip resolves via fallback.
      home.file.".local/share/fonts/SymbolsNerdFont-Regular.ttf".source =
        "${pkgs.nerd-fonts.symbols-only}/share/fonts/truetype/NerdFonts/Symbols/SymbolsNerdFont-Regular.ttf";

      home.file.".codex/config.toml".text = ''
        approval_policy = "never"
        sandbox_mode = "danger-full-access"

        [projects."/home/quill"]
        trust_level = "trusted"

        [tui.model_availability_nux]
        "gpt-5.5" = 4
      '';

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          gtk-theme = "Adwaita-dark";
          icon-theme = "Adwaita";
        };
      };

      xdg.configFile."hypr/hyprland.conf".text = ''
        # Hyprland starts on the AMD iGPU because the internal display is connected
        # there. The NVIDIA dGPU can remain available for explicit game offload later.

        $terminal = ghostty

        monitor = , preferred, auto, 1

        exec-once = ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP DISPLAY && ${pkgs.systemd}/bin/systemctl --user restart hyprpaper.service
        exec-once = ashell
        exec-once = mako
        exec-once = eww daemon
        exec-once = agent-mode-lid-watch

        input {
            kb_layout = us
            follow_mouse = 1
            scroll_factor = 0.5
            touchpad {
                tap-to-click = true
                clickfinger_behavior = true
                natural_scroll = false
                middle_button_emulation = false
            }
        }

        general {
            gaps_in = 4
            gaps_out = 8
            border_size = 2
            layout = dwindle
        }

        decoration {
            rounding = 4
        }

        bind = ALT, Return, exec, $terminal
        bind = ALT, T, exec, $terminal
        bind = ALT, Space, exec, qmenu-launch    # qmenu launcher
        bind = SUPER, Space, exec, qmenu-launch  # qmenu launcher
        bind = ALT, Q, killactive
        bind = ALT, W, killactive
        bind = ALT SHIFT, Q, exit
        bind = ALT, F, fullscreen
        bind = CTRL SHIFT, 5, exec, screenshot-selection

        bindel = , XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
        bindel = , XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        bindl = , XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        bindl = , XF86AudioMicMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        bindel = , XF86MonBrightnessUp, exec, ${pkgs.brightnessctl}/bin/brightnessctl --quiet set 5%+
        bindel = , XF86MonBrightnessDown, exec, ${pkgs.brightnessctl}/bin/brightnessctl --quiet --min-value=1 set 5%-

        bind = ALT, I, movefocus, u
        bind = ALT, J, movefocus, l
        bind = ALT, K, movefocus, d
        bind = ALT, L, movefocus, r
        bind = ALT SHIFT, I, movewindow, u
        bind = ALT SHIFT, J, movewindow, l
        bind = ALT SHIFT, K, movewindow, d
        bind = ALT SHIFT, L, movewindow, r

        bind = ALT, 1, workspace, 1
        bind = ALT, 2, workspace, 2
        bind = ALT, 3, workspace, 3
        bind = ALT, 4, workspace, 4
        bind = ALT, 5, workspace, 5
        bind = ALT, 6, workspace, 6
        bind = ALT, 7, workspace, 7
        bind = ALT, 8, workspace, 8
        bind = ALT, 9, workspace, 9
        bind = ALT, 0, workspace, 10

        bind = ALT SHIFT, 1, movetoworkspace, 1
        bind = ALT SHIFT, 2, movetoworkspace, 2
        bind = ALT SHIFT, 3, movetoworkspace, 3
        bind = ALT SHIFT, 4, movetoworkspace, 4
        bind = ALT SHIFT, 5, movetoworkspace, 5
        bind = ALT SHIFT, 6, movetoworkspace, 6
        bind = ALT SHIFT, 7, movetoworkspace, 7
        bind = ALT SHIFT, 8, movetoworkspace, 8
        bind = ALT SHIFT, 9, movetoworkspace, 9
        bind = ALT SHIFT, 0, movetoworkspace, 10
      '';

      # qmenu launcher theme — matches the desktop pink-on-near-black palette.
      # Edit here, then rebuild.
      xdg.configFile."qmenu/config.toml".text = ''
        [colors]
        background           = "#f2050507"
        foreground           = "#f7eef5"
        prompt               = "#ff4fa3"
        selection_background = "#ff4fa3"
        selection_foreground = "#050507"
        muted                = "#cdbfca"
        border               = "#ff4fa3"

        [layout]
        anchor            = "center"
        width_fraction    = 0.42
        min_width         = 520
        margin_top        = 8
        max_visible_items = 12
        font_size         = 14.0
        line_height       = 32.0
        pad_x             = 16.0
        pad_y             = 12.0
        corner_radius     = 14.0
        border_width      = 2.0
        row_radius        = 8.0
        result_gap        = 8.0
        font_family       = "Inter"

        [icons]
        enabled = true
        size    = 22
        gap     = 12.0
        theme   = "Adwaita"

        [behavior]
        show_all_when_empty = false
        placeholder         = "Search…"
        terminal            = "ghostty"
      '';

      xdg.configFile."hypr/hyprpaper.conf".text = ''
        wallpaper {
            monitor = *
            path = ${../assets/wallpapers/thumb-1920-827218.png}
            fit_mode = cover
        }
        splash = false
      '';

      xdg.configFile."mako/config".text = ''
        font=Inter 11
        width=420
        height=140
        anchor=top-right
        layer=overlay
        outer-margin=12,14,0,0
        margin=8
        padding=12,14
        border-size=2
        border-radius=8
        icons=1
        max-icon-size=48
        icon-location=left
        icon-border-radius=6
        markup=1
        actions=1
        history=1
        max-history=20
        max-visible=4
        sort=-time
        default-timeout=6500
        ignore-timeout=1
        group-by=app-name,summary
        format=<b>%s</b>\n<span foreground="#cdbfca">%b</span>

        background-color=#0b0b10f2
        text-color=#f7eef5ff
        border-color=#ff4fa3ff
        progress-color=over #ff4fa3ff

        [urgency=low]
        background-color=#15121af0
        text-color=#cdbfcaff
        border-color=#5b5360ff
        default-timeout=4500

        [urgency=critical]
        background-color=#241827ff
        text-color=#f7eef5ff
        border-color=#ff5c8aff
        progress-color=over #ff5c8aff
        default-timeout=0

        [grouped]
        format=(%g) <b>%s</b>\n<span foreground="#cdbfca">%b</span>
      '';

      xdg.configFile."gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-theme-name=Adwaita-dark
        gtk-icon-theme-name=Adwaita
        gtk-application-prefer-dark-theme=1
      '';

      xdg.configFile."gtk-4.0/settings.ini".text = ''
        [Settings]
        gtk-theme-name=Adwaita-dark
        gtk-icon-theme-name=Adwaita
        gtk-application-prefer-dark-theme=1
      '';

      xdg.configFile."kdeglobals".text = ''
        [General]
        ColorScheme=BreezeDark
        Name=Breeze Dark

        [KDE]
        LookAndFeelPackage=org.kde.breezedark.desktop
      '';
    };
  };
}
