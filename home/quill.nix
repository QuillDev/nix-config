{ pkgs, ... }:

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
        ];
      };

      programs.home-manager.enable = true;
      xdg.enable = true;

      programs.bash = {
        enable = true;
        shellAliases.cc = "claude";
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
      '';

      xdg.configFile."ghostty/config.ghostty".text = ''
        theme =
        window-theme = dark

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
        permissions.defaultMode = "bypassPermissions";
      };

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
        $launcher = fuzzel

        monitor = , preferred, auto, 1

        exec-once = hyprpaper
        exec-once = ashell
        exec-once = mako

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

      xdg.configFile."hypr/hyprpaper.conf".text = ''
        wallpaper {
            monitor = eDP-1
            path = ${../assets/wallpapers/chatgpt-wallpaper.png}
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
