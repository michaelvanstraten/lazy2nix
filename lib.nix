{
  self ? ./.,
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
}:
rec {
  buildLazyPlugin =
    plugin-name: plugin-spec:
    pkgs.stdenvNoCC.mkDerivation (
      let
        plugin-directory = "share/nvim/lazy";
      in
      {
        name = plugin-name;
        src = fetchGit {
          name = plugin-name;
          rev = plugin-spec.commit;
          url = plugin-spec.url;
        };
        sourceRoot = ".";
        buildPhase = ''
          mkdir -p $out/${plugin-directory}
          mv "${plugin-name}" $out/${plugin-directory}
        '';
      }
    );

  mkNeovimConfiguration =
    {
      configDir,
      lazy ?
        let
          look-file = builtins.fromJSON (builtins.readFile ./flake.lock);
          look-info = look-file.nodes.lazy.locked;
        in
        fetchGit {
          url = "https://github.com/${look-info.owner}/${look-info.repo}";
          rev = look-info.rev;
        },
      lazy-lock ? "lazy-lock.json",
      neovim ? pkgs.neovim-unwrapped,
      additionalPackages ? [ pkgs.git ],
    }:
    rec {
      plugin-specs =
        let
          query-script =
            pkgs.runCommand "query-plugins"
              {
                LAZY = lazy;
                buildInputs = [ pkgs.neovim-unwrapped ];
              }
              ''
                nvim -l "${self}/lua/lazy2nix/query-plugins.lua" "${configDir}"
              '';
        in
        with builtins;
        fromJSON (readFile "${query-script}");

      plugins = pkgs.symlinkJoin {
        name = "plugins";
        paths = lib.attrValues (lib.mapAttrs buildLazyPlugin plugin-specs);
      };

      mkVimrc = pkgs.writeScript "init.lua" ''
        vim.opt.rtp:prepend("${self}")
        local lazy2nix = require("lazy2nix")

        -- Set up environment for `lazy.nvim` source code location
        vim.env.LAZY = "${lazy}"

        -- Prepend the runtime path with the provided `lazy` module path
        vim.opt.rtp:prepend(vim.env.LAZY)

        local vimrc_path = vim.fn.fnamemodify("${configDir}", ":p")

        -- Proxy the `lazy` setup function to customize plugin paths and options
        lazy2nix.proxy_lazy_setup(require("lazy"), function(opts, original_lazy_setup)
          -- Set or overwrite the plugin directory with the provided setup plugins
          opts.root = "${plugins}/share/nvim/lazy"

          -- Set or overwrite the lockfile to the provided config lockfile
          opts.lockfile = vimrc_path .. (opts.lockfile or "lock-lazy.json")

          -- Ensure an error is thrown by `lazy` for incorrect implementations
          opts.install = vim.tbl_deep_extend("force", opts.install or {}, { missing = true })
          opts.performance = vim.tbl_deep_extend("force", opts.performance or {}, { cache = { enabled = false } })

          -- Call the original setup function from `lazy`
          original_lazy_setup(opts)
        end)

        lazy2nix.proxy_fs_stat(vim.env.LAZY)

        lazy2nix.load_vimrc(vimrc_path)
      '';

      neovim = pkgs.stdenvNoCC.mkDerivation {
        name = "neovim-config";
        src = configDir;
        buildInputs = [ pkgs.makeWrapper ];
        postInstall = ''
          makeWrapper "${pkgs.neovim-unwrapped}/bin/nvim" \
            $out/bin/nvim \
            --add-flags "-u "${mkVimrc}"" \
            --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.git ]}
        '';
      };

      checks = {
        unlocked-plugisn = null;
        checkhealth = pkgs.runCommand "neovim-checkhealth" { buildInputs = [ neovim ]; } ''
          nvim --headless +source ${./lua/lazy2nix/checkhealth.lua} +qa
        '';
      };
    };
}
