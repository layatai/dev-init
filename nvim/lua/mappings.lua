require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })

map("n", "<leader>ld", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Diagnostics (Trouble)" })
map("n", "<leader>ls", "<cmd>Trouble symbols toggle focus=false<CR>", { desc = "Symbols (Trouble)" })
map("n", "<leader>lr", "<cmd>Trouble lsp toggle focus=false win.position=right<CR>", { desc = "LSP refs (Trouble)" })

map("n", "<leader>tt", "<cmd>TodoTelescope<CR>", { desc = "Search TODOs" })

map("n", "<leader>db", function()
  require("dap").toggle_breakpoint()
end, { desc = "Debug: toggle breakpoint" })
map("n", "<leader>dc", function()
  require("dap").continue()
end, { desc = "Debug: continue" })
map("n", "<leader>do", function()
  require("dap").step_over()
end, { desc = "Debug: step over" })
map("n", "<leader>di", function()
  require("dap").step_into()
end, { desc = "Debug: step into" })
map("n", "<leader>du", function()
  require("dapui").toggle()
end, { desc = "Debug: toggle UI" })
