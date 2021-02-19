local Layout = require('concertina').Layout
local M = {}

function M.goto_window(number)
  vim.api.nvim_exec(number .. 'wincmd w', false)
end

function M.heights()
  local heights = {}

  for i , info in pairs(vim.fn.getwininfo()) do
    heights[i] = info.height
  end

  return heights
end

function M.exec(commands)
  for _, c in ipairs(commands) do
    local bufnr = vim.fn.bufnr()
    vim.api.nvim_exec(c, false)
    vim.api.nvim_exec('doau WinEnter', false)
    if vim.fn.bufnr() ~= bufnr then
      vim.api.nvim_exec('doau BufEnter', false)
    end
  end
end

function M.stretched_windows()
  local result, layout = {}, Layout:new()

  for winnr = 1, vim.fn.winnr('$') do
    if layout:is_stretched(winnr) then
      table.insert(result, winnr)
    end
  end

  return result
end

return M
