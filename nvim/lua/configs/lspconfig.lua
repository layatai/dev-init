require("nvchad.configs.lspconfig").defaults()

local servers = {
  html = {},
  cssls = {},
  ts_ls = {},
  jsonls = {},
  taplo = {},
  bashls = {},
  marksman = {},
  eslint = {},
}

for name, opts in pairs(servers) do
  vim.lsp.config(name, opts)
end

vim.lsp.enable(vim.tbl_keys(servers))
