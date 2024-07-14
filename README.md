# lazy2nix

> [!IMPORTANT]
> This is a very experimental repository. Use it at your own risk and be
> prepared for potential issues and breaking changes. Contributions and feedback 
> are welcome to help improve its stability and functionality.

**lazy2nix** converts your [`lazy.nvim`](https://github.com/folke/lazy.nvim)-based 
Neovim configuration into a Nix derivation without requiring any modifications. 
It achieves this by querying your configuration for enabled plugins and reading 
the `lazy-lock.json` file.
