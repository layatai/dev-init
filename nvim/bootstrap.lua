-- Headless IDE bootstrap: plugins must already be restored by Lazy.
local homebrew_bin = "/opt/homebrew/bin"
if vim.fn.isdirectory(homebrew_bin) == 1 and not vim.env.PATH:find(homebrew_bin, 1, true) then
  vim.env.PATH = homebrew_bin .. ":" .. vim.env.PATH
end

local function load_plugins()
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    error "lazy.nvim is not available"
  end
  lazy.load {
    wait = true,
    plugins = { "mason.nvim", "mason-tool-installer.nvim", "nvim-treesitter" },
  }
end

local function install_mason_tools()
  if vim.fn.exists ":MasonToolsInstallSync" == 2 then
    vim.cmd.MasonToolsInstallSync()
    return
  end
  error "MasonToolsInstallSync is unavailable"
end

local parsers = {
  "bash",
  "css",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "rust",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
}

local function install_treesitter()
  local ok, ts = pcall(require, "nvim-treesitter")
  if ok and type(ts.install) == "function" then
    ts.install(parsers):wait(5 * 60 * 1000)
    return
  end
  if vim.fn.exists ":TSUpdateSync" == 2 then
    vim.cmd.TSUpdateSync()
    return
  end
  if vim.fn.exists ":TSInstallSync" == 2 then
    vim.cmd("TSInstallSync! " .. table.concat(parsers, " "))
  end
end

load_plugins()
install_mason_tools()
install_treesitter()
print "dev-init nvim bootstrap complete"
