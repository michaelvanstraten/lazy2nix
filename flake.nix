{
  description = "Convert lazy.vim configurations to nix automagically";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    lazy = {
      url = "github:folke/lazy.nvim";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        queryPlugins =
          {
            config,
            lazy ? inputs.lazy,
          }:
          let
            query-script =
              pkgs.runCommand "query-plugins"
                {
                  LAZY = lazy;
                  buildInputs = with pkgs; [
                    git
                    neovim-unwrapped
                  ];
                }
                ''
                  cd ${config} 
                  XDG_STATE_HOME="$(mktemp -d)" nvim -l ${./lua/query-plugins.lua}
                '';
          in
          with builtins;
          fromJSON (readFile "${query-script}");

        buildPlugin =
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

        mkVimrc =
          {
            config,
            plugins,
            lazy ? inputs.lazy,
          }:
          pkgs.writeScript "init.lua" ''
            -- Set up environment for `lazy.nvim` source code location
            vim.env.LAZY = "${lazy}"

            -- Prepend the runtime path with the provided `lazy` module path
            vim.opt.rtp:prepend(vim.env.LAZY)

            -- Preload the real `lazy` module
            local lazy = require("lazy")
            local original_lazy_setup = lazy.setup

            -- Proxy the `lazy` setup function to customize plugin paths and options
            lazy.setup = function(spec, opts)
              -- Determine if `spec` is a table containing the `spec` key
              if type(spec) == "table" and spec.spec then
                opts = spec
              else
                opts = opts or {}
                opts.spec = spec
              end

              -- Set or overwrite the plugin directory with the provided setup plugins
              opts.root = "${plugins}/share/nvim/lazy"

              -- Set or overwrite the lockfile to the provided config lockfile
              opts.lockfile = vim.fn.fnamemodify("${config}", ":p") .. (opts.lockfile or "lock-lazy.json")

              -- Ensure an error is thrown by `lazy` for incorrect implementations
              opts.install = vim.tbl_deep_extend("force", opts.install or {}, { missing = true })

              -- Call the original setup function from `lazy`
              original_lazy_setup(opts)
            end

            -- Prepend the runtime path with the config modules path
            vim.opt.rtp:prepend("${config}")

            -- Execute the actual vimrc file
            local config_init_path = vim.fn.fnamemodify("${config}", ":p") .. "init.lua"
            dofile(config_init_path)
          '';
      in
      {
        inherit mkVimrc queryPlugins buildPlugin;
        mkLazyNeovimConfig =
          config:
          pkgs.stdenvNoCC.mkDerivation (
            let
              plugin-specs = queryPlugins { config = config; };
              plugins = pkgs.symlinkJoin {
                name = "plugins";
                paths = lib.attrValues (lib.mapAttrs buildPlugin plugin-specs);
              };
            in
            {
              name = "nvim-config";
              src = config;
              buildInputs = [ pkgs.makeWrapper ];
              postInstall = ''
                makeWrapper "${pkgs.neovim}/bin/nvim" \
                  $out/bin/nvim \
                  --add-flags "-u ${mkVimrc { inherit config plugins; }}"
              '';
            }
          );
      }
    );
}
