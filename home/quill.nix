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
          "$eww" open usage
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
  users.users."quill" = {
    isNormalUser = true;
    description = "Robert Brunson";
    extraGroups = [ "networkmanager" "wheel" ];
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
          qmenu-launch
          agent-usage
          agent-usage-popup
          pkgs.eww
        ];
      };

      programs.home-manager.enable = true;
      xdg.enable = true;

      programs.bash = {
        enable = true;
        shellAliases = {
          cc = "IS_SANDBOX=1 claude --dangerously-skip-permissions";
          sudo = "sudo ";
        };
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
        (defwindow usage
          :monitor 0
          :geometry (geometry :x "0px" :y "0px" :anchor "top right" :width "100%" :height "100%")
          :stacking "overlay"
          (eventbox :class "backdrop" :onclick "${agent-usage-popup}/bin/agent-usage-popup close"
            (box :orientation "v" :halign "end" :valign "start" :space-evenly false
              (eventbox :onclick "true" (usage-content)))))
      '';

      xdg.configFile."eww/eww.scss".text = ''
        * { all: unset; }

        .backdrop { background-color: transparent; }

        .popup {
          background-color: rgba(5, 5, 7, 0.97);
          border: 2px solid ${palette.pink};
          border-radius: 14px;
          padding: 16px 18px;
          /* top right bottom left: clear the bar, hug the right edge */
          margin: 40px 8px 0 0;
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
        $launcher = walker --nohints --hideqa

        monitor = , preferred, auto, 1

        exec-once = hyprpaper
        exec-once = ashell
        exec-once = mako
        exec-once = elephant
        exec-once = walker --gapplication-service
        exec-once = eww daemon

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
        bind = ALT, Space, exec, $launcher
        bind = SUPER, Space, exec, qmenu-launch  # qmenu launcher (pkgs/qmenu)
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

      # qmenu launcher theme — matches the desktop pink-on-near-black palette
      # (same base/accent as walker & fuzzel). Edit here, then rebuild.
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

      xdg.configFile."fuzzel/fuzzel.ini".text = ''
        [main]
        font=Inter:size=13
        prompt="> "
        terminal=ghostty
        hide-before-typing=yes
        width=42
        lines=10
        horizontal-pad=18
        vertical-pad=14
        inner-pad=8
        line-height=24
        layer=overlay

        [colors]
        background=050507f2
        text=f7eef5ff
        prompt=ff4fa3ff
        placeholder=cdbfcaff
        input=f7eef5ff
        match=ff79bdff
        selection=ff4fa3ff
        selection-text=050507ff
        selection-match=050507ff
        border=ff4fa3ff

        [border]
        width=2
        radius=14
        selection-radius=8
      '';

      xdg.configFile."walker/config.toml".text = ''
        theme = "quill"
        close_when_open = true
        force_keyboard_focus = true

        [keybinds]
        close = ["Escape"]

        [providers]
        empty = []
      '';

      xdg.configFile."walker/themes/quill/grid.xml".text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <interface>
          <requires lib="gtk" version="4.0"/>

          <object class="GtkBox" id="Keybind">
            <style><class name="keybind"/></style>
            <property name="orientation">horizontal</property>
            <property name="spacing">6</property>
            <child>
              <object class="GtkButton" id="KeybindButton">
                <style><class name="keybind-button"/></style>
                <child>
                  <object class="GtkLabel" id="KeybindBind">
                    <style><class name="keybind-bind"/></style>
                  </object>
                </child>
              </object>
            </child>
            <child>
              <object class="GtkLabel" id="KeybindLabel">
                <style><class name="keybind-label"/></style>
              </object>
            </child>
          </object>

          <object class="GtkBox" id="PreviewBox">
            <style><class name="preview-box"/></style>
            <property name="orientation">vertical</property>
          </object>

          <object class="GtkWindow" id="Window">
            <style><class name="window"/></style>
            <property name="resizable">false</property>
            <property name="decorated">false</property>
            <child>
              <object class="GtkBox" id="BoxWrapper">
                <style><class name="box-wrapper"/></style>
                <property name="orientation">vertical</property>
                <property name="halign">center</property>
                <property name="valign">center</property>
                <child>
                  <object class="GtkBox" id="Box">
                    <style><class name="box"/></style>
                    <property name="orientation">vertical</property>
                    <property name="hexpand">true</property>
                    <property name="hexpand-set">true</property>
                    <property name="spacing">4</property>
                    <property name="width-request">540</property>
                    <child>
                      <object class="GtkBox" id="SearchContainer">
                        <style><class name="search-container"/></style>
                        <property name="orientation">horizontal</property>
                        <property name="hexpand">true</property>
                        <child>
                          <object class="GtkEntry" id="Input">
                            <style><class name="input"/></style>
                            <property name="hexpand">true</property>
                            <property name="halign">fill</property>
                          </object>
                        </child>
                      </object>
                    </child>
                    <child>
                      <object class="GtkBox" id="ContentContainer">
                        <style><class name="content-container"/></style>
                        <property name="orientation">horizontal</property>
                        <property name="spacing">10</property>
                        <child>
                          <object class="GtkLabel" id="ElephantHint">
                            <style><class name="elephant-hint"/></style>
                            <property name="label">Waiting for elephant...</property>
                            <property name="visible">false</property>
                            <property name="hexpand">true</property>
                            <property name="vexpand">false</property>
                          </object>
                        </child>
                        <child>
                          <object class="GtkLabel" id="Placeholder">
                            <style><class name="placeholder"/></style>
                            <property name="label">No Results</property>
                            <property name="visible">false</property>
                            <property name="hexpand">true</property>
                            <property name="vexpand">false</property>
                          </object>
                        </child>
                        <child>
                          <object class="GtkScrolledWindow" id="Scroll">
                            <style><class name="scroll"/></style>
                            <property name="hexpand">true</property>
                            <property name="vexpand">false</property>
                            <property name="max-content-width">520</property>
                            <property name="min-content-width">520</property>
                            <property name="min-content-height">0</property>
                            <property name="max-content-height">320</property>
                            <property name="propagate-natural-height">true</property>
                            <property name="propagate-natural-width">true</property>
                            <property name="hscrollbar-policy">never</property>
                            <property name="vscrollbar-policy">automatic</property>
                            <child>
                              <object class="GtkGridView" id="List">
                                <style><class name="list"/></style>
                                <property name="max-columns">1</property>
                                <property name="min-columns">1</property>
                              </object>
                            </child>
                          </object>
                        </child>
                        <child>
                          <object class="GtkBox" id="Preview">
                            <style><class name="preview"/></style>
                          </object>
                        </child>
                      </object>
                    </child>
                    <child>
                      <object class="GtkBox" id="Keybinds">
                        <style><class name="keybinds"/></style>
                        <property name="hexpand">true</property>
                        <property name="visible">false</property>
                        <child>
                          <object class="GtkBox" id="GlobalKeybinds">
                            <style><class name="global-keybinds"/></style>
                            <property name="spacing">10</property>
                          </object>
                        </child>
                        <child>
                          <object class="GtkBox" id="ItemKeybinds">
                            <style><class name="item-keybinds"/></style>
                            <property name="hexpand">true</property>
                            <property name="halign">end</property>
                            <property name="spacing">10</property>
                          </object>
                        </child>
                      </object>
                    </child>
                    <child>
                      <object class="GtkLabel" id="Error">
                        <style><class name="error"/></style>
                        <property name="xalign">0</property>
                        <property name="visible">false</property>
                      </object>
                    </child>
                  </object>
                </child>
              </object>
            </child>
          </object>
        </interface>
      '';

      xdg.configFile."walker/themes/quill/item.xml".text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <interface>
          <requires lib="gtk" version="4.0"/>
          <object class="GtkBox" id="ItemBox">
            <style><class name="item-box"/></style>
            <property name="orientation">horizontal</property>
            <property name="spacing">10</property>
            <child>
              <object class="GtkImage" id="ItemImage">
                <style><class name="item-image"/></style>
                <property name="icon-size">normal</property>
                <property name="pixel-size">16</property>
              </object>
            </child>
            <child>
              <object class="GtkLabel" id="ItemImageFont">
                <style><class name="item-image-font"/></style>
                <property name="visible">false</property>
              </object>
            </child>
            <child>
              <object class="GtkBox" id="ItemTextBox">
                <style><class name="item-text-box"/></style>
                <property name="orientation">vertical</property>
                <property name="hexpand">true</property>
                <child>
                  <object class="GtkLabel" id="ItemText">
                    <style><class name="item-text"/></style>
                    <property name="xalign">0</property>
                    <property name="ellipsize">end</property>
                    <property name="hexpand">true</property>
                  </object>
                </child>
                <child>
                  <object class="GtkLabel" id="ItemSubtext">
                    <style><class name="item-subtext"/></style>
                    <property name="visible">false</property>
                  </object>
                </child>
              </object>
            </child>
            <child>
              <object class="GtkLabel" id="QuickActivation">
                <style><class name="item-quick-activation"/></style>
              </object>
            </child>
          </object>
        </interface>
      '';

      xdg.configFile."walker/themes/quill/style.css".text = ''
        @define-color base       #050507;
        @define-color surface    #0b0b10;
        @define-color elevated   #15121a;
        @define-color strong     #241827;
        @define-color text       #f7eef5;
        @define-color muted      #cdbfca;
        @define-color pink       #ff4fa3;
        @define-color pink-hi    #ff79bd;
        @define-color pink-lo    #b83275;

        * {
          font-family: "Inter";
          font-size: 13px;
          color: @text;
        }

        window.window {
          background: transparent;
        }

        .box-wrapper {
          background: transparent;
          padding: 0;
        }

        .box {
          background: alpha(@base, 0.95);
          border: 2px solid @pink;
          border-radius: 12px;
          padding: 8px 10px;
        }

        .search-container { padding: 0; }

        .input {
          background: @surface;
          border: 1px solid @elevated;
          border-radius: 6px;
          padding: 4px 10px;
          color: @text;
          caret-color: @pink;
          min-height: 20px;
        }
        .input:focus {
          border-color: @pink;
          outline: none;
          box-shadow: none;
        }
        .input placeholder { color: @muted; }

        .content-container { padding: 0; }

        .scroll, .scroll * {
          background: transparent;
          border: none;
        }
        scrollbar, scrollbar slider {
          background: transparent;
          border: none;
          min-width: 4px;
        }
        scrollbar slider { background: @elevated; border-radius: 4px; }

        .list { background: transparent; }

        .item-box {
          padding: 3px 8px;
          border-radius: 6px;
          background: transparent;
        }
        .item-box:hover { background: @elevated; }
        .list > child:selected .item-box,
        .item-box:selected {
          background: @pink;
          color: @base;
        }
        .list > child:selected .item-text,
        .list > child:selected .item-subtext,
        .list > child:selected .item-quick-activation {
          color: @base;
        }

        .item-image, .item-image-font {
          min-width: 14px;
          min-height: 14px;
          -gtk-icon-size: 14px;
        }
        .item-text { font-weight: 500; }
        .item-subtext {
          font-size: 0;
          min-height: 0;
          margin: 0;
          padding: 0;
          opacity: 0;
        }
        .item-quick-activation {
          min-width: 0;
          min-height: 0;
          padding: 0;
          margin: 0;
          opacity: 0;
        }

        .placeholder, .elephant-hint {
          color: @muted;
          font-style: italic;
        }

        .preview { background: transparent; }
        .preview-box {
          background: @surface;
          border-radius: 8px;
          padding: 10px;
        }

        .keybinds {
          min-height: 0;
          margin: 0;
          padding: 0;
          opacity: 0;
        }
        .keybind, .keybind-bind, .keybind-label {
          min-height: 0;
          padding: 0;
          margin: 0;
          font-size: 0;
        }

        .error {
          color: @pink-hi;
          font-style: italic;
        }
      '';

      xdg.configFile."hypr/hyprpaper.conf".text = ''
        wallpaper {
            monitor = eDP-1
            path = ${../assets/wallpapers/nako-room.png}
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
