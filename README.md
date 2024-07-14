# lazy2nix

**lazy2nix** converts your [`lazy.nvim`](https://github.com/folke/lazy.nvim)-based 
Neovim configuration into a Nix derivation without requiring any modifications. 
It achieves this by querying your configuration for enabled plugins and reading 
the `lazy-lock.json` file.
