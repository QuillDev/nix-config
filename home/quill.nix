{ pkgs, ... }:

let
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
        ];
      };

      programs.home-manager.enable = true;
      xdg.enable = true;

      programs.bash.enable = true;

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

        exec-once = ashell
        exec-once = mako

        input {
            kb_layout = us
            follow_mouse = 1
            scroll_factor = 0.5
            touchpad {
                natural_scroll = false
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

        bindel = , XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
        bindel = , XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        bindl = , XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        bindl = , XF86AudioMicMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

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
        width=42
        lines=10
        horizontal-pad=18
        vertical-pad=14
        inner-pad=8
        line-height=24
        layer=overlay

        [colors]
        background=1f2328f2
        text=e6edf3ff
        prompt=7dd3fcff
        placeholder=8b949eff
        input=e6edf3ff
        match=f9e2afff
        selection=2f363dff
        selection-text=ffffffff
        selection-match=f9e2afff
        border=7dd3fcff

        [border]
        width=2
        radius=6
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
