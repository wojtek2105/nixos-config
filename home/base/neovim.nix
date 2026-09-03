{ config, inputs, pkgs, ... }:

let
  nvim-kickstart = pkgs.writeShellApplication {
    name = "nvim-kickstart";
    runtimeInputs = [
      config.programs.neovim.finalPackage
      pkgs.coreutils
    ];
    text = ''
      config_root="''${XDG_CONFIG_HOME:-$HOME/.config}/nvim-kickstart"

      if [[ ! -f "$config_root/init.lua" ]]; then
        if [[ -e "$config_root" ]]; then
          printf 'nvim-kickstart: %s istnieje, ale nie zawiera init.lua\n' \
            "$config_root" >&2
          exit 1
        fi

        mkdir -p "$config_root"
        cp -R --no-preserve=mode,ownership ${inputs.kickstart-nvim}/. "$config_root/"
        chmod -R u+w "$config_root"
      fi

      # NVIM_APPNAME isolates config, plugins, state and cache from daily nvim.
      export NVIM_APPNAME=nvim-kickstart
      exec nvim "$@"
    '';
  };
in

{
  home.packages = with pkgs; [
    nvim-kickstart

    # External tools expected by the upstream Kickstart configuration.
    fd
    gcc
    git
    gnumake
    ripgrep
    tree-sitter
    unzip
    wl-clipboard
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    plugins = [
      {
        plugin = pkgs.vimUtils.buildVimPlugin {
          pname = "biscuit-nvim";
          version = "unstable-2026-08-23";
          src = inputs.biscuit-nvim;
        };
        config = "colorscheme biscuit";
      }
    ];
    initLua = ''
      vim.opt.termguicolors = true
      vim.opt.number = true
      vim.opt.cursorline = true
      vim.opt.signcolumn = "yes"
    '';
  };

  # The wrapper bootstraps a writable worktree from this flake-pinned source.
  # Home Manager must not own ~/.config/nvim-kickstart: vim.pack and the future
  # personal Git repository both need to write there. NVIM_APPNAME keeps its
  # config, plugins, state and cache separate from the daily Neovim profile.
}
