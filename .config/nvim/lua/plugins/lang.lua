-- Language setup, kept minimal on purpose.
--
-- Treesitter: "c" and "bash" parsers are already in LazyVim's default
-- ensure_installed list, so nothing to add here.
--
-- LSP: enabling LazyVim's official clangd extra gives us:
--   * clangd auto-installed via Mason on first open of a C file
--   * Makefile / compile_flags.txt / compile_commands.json as root markers
--     (both ~/src projects are Makefile-based)
--   * <leader>ch to switch between source and header
-- Add more languages later via :LazyExtras (e.g. lang.go, lang.python).
return {
  { import = "lazyvim.plugins.extras.lang.clangd" },
}
