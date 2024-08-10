{
  description = "Convert lazy.nvim configurations to nix automagically";

  inputs = {
    lazy = {
      url = "github:folke/lazy.nvim";
      flake = false;
    };
  };

  outputs =
    { ... }:
    {
      lib = import ./lib.nix;
    };
}
