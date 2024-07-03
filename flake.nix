{
  description = "Convert lazy.vim configurations to nix automagically";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        query-plugins =
          {
            configuration,
            lazy ? fetchGit {
              url = "https://github.com/folke/lazy.nvim";
              rev = "cea5920abb202753004440f94ec39bcf2927e02e";
            },
          }:
          let
            lua-script =
              pkgs.runCommand "query-plugins"
                {
                  LAZY = lazy;
                  buildInputs = with pkgs; [ git neovim-unwrapped ];
                }
                ''
                  cd ${configuration} 
                  nvim -l ${./lua/query-plugins.lua} 2>&1 | tee $out
                '';
          in
          with builtins;
          fromJSON (readFile "${lua-script}");
      }
    );
}
