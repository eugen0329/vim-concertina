local M =  {last_handled={}, toplines={}}
local command = function(cmd) return vim.api.nvim_exec(cmd, false) end
local MAX_HEIGHT = 999

local Win, Viewport, Layout, WinResizeObserver = {}, {}, {}, {}

function M.init()
  if vim.g.loaded_concertina then return end

  vim.g.loaded_concertina = '0.0.1'
  vim.o.winminheight = 0

  command([[
  aug concertina
    au!
    au WinEnter * lua require'concertina'.on_enter()
    au BufEnter * lua require'concertina'.on_enter('BufEnter')
    au FileType * lua vim.defer_fn(function() require'concertina'.on_enter('FileType') end, 0)
    au User concertina_on_enter lua require'concertina'.on_enter()
    au WinScrolled * lua require'concertina'.on_view()
    au CursorHold  * lua require'concertina'.on_view()
  aug END
  ]])

  if not vim.g.concertina_win_heights then
    vim.g.concertina_win_heights = {godebugstacktrace=10, godebugoutput=10, rst=20}
  end
  if not vim.g.concertina_stretched_win_heights then
    vim.g.concertina_stretched_win_heights = {quickfix=10, terminal=20, quickrun=20, godoc=20, pymoderun=20}
  end
  if not vim.g.concertina_ignore then -- WARN: can be overruled by win_heights and stretched_win_heights
    vim.g.concertina_ignore = {nofile=true, godebugvariables=true}
  end
end

function M.on_view()
  Viewport:new(vim.fn.winnr()):store()
end

function M.on_enter(event)
  local layout = Layout:new()
  local win = Win:new(layout)
  table.insert(layout.observers, WinResizeObserver:new(win))

  win:handle_enter(function(last_handled)
    -- Ignore if
    -- 1) is already handled by win enter
    -- 2) configured to be ignored and wasn't overruled by stretched_win_heights or win_heights
    -- 3) is floating
    if event == 'BufEnter' and last_handled.bufnr == win.bufnr
      or event == 'FileType' and last_handled.filetype == win.filetype
      or win.fixed_height == nil and win:is_ignoreable()
      or vim.api.nvim_win_get_config(vim.fn.win_getid()).relative ~= '' then
      return
    end

    -- If the only window, maximize it and restore the viewport
    if vim.fn.winnr('$') == 1 then
      command('resize' .. MAX_HEIGHT)
      return Viewport:new(win.winnr):restore()
    end

    win:keep_focused(function()
      command('1windo resize' .. MAX_HEIGHT)
      win:focus()

      command('resize' .. win.height)
      win:set_fixed_heights_of_siblings()

      if win.should_enforce_height then
        win:focus()
        command('resize' .. win.height)
      end
      win:each_sibling(function(winnr) Viewport:new(winnr):restore() end)
    end)

    Viewport:new(win.winnr):restore()
  end)
end

Win.__index = Win

function Win:new(layout)
  local win = setmetatable({
    layout   = layout,
    filetype = vim.bo.filetype,
    buftype  = vim.bo.buftype,
    bufnr    = vim.fn.bufnr(),
    winnr    = vim.fn.winnr(),
  }, self)
  win.fixed_height = layout:get_fixed_height(win.winnr, win.buftype, win.filetype)
  win.height = win.fixed_height or MAX_HEIGHT

  return win
end

function Win:each_sibling(callback)
  for winnr = 1, vim.fn.winnr('$') do
    if winnr ~= self.winnr then callback(winnr) end
  end
end

function Win:keep_focused(callback)
  local original_eventignore = vim.o.eventignore
  vim.o.eventignore = 'all'

  local ok, result = pcall(callback)
  if not ok then error(debug.traceback(result)) end

  self:focus()
  vim.o.eventignore = original_eventignore
end

function Win:focus()
  if vim.fn.winnr() ~= self.winnr then
    command(self.winnr .. 'wincmd w')
  end
end

function Win:is_ignoreable()
  return self.layout.ignore[self.buftype] or self.layout.ignore[self.filetype]
end

function Win:set_fixed_heights_of_siblings()
  local fixed_heights = {}

  self:each_sibling(function(winnr)
    fixed_heights[winnr] = self.layout:set_fixed_height(winnr)
  end)
  -- do the second walk on fixed height windows only
  self:each_sibling(function(winnr)
    if fixed_heights[winnr] and vim.fn.winheight(winnr) ~= fixed_heights[winnr] then
      self.layout:set_fixed_height(winnr)
    end
  end)
end

function Win:handle_enter(callback)
  local ok, result = pcall(callback, M.last_handled)
  if not ok then error(debug.traceback(result)) end
  M.last_handled = {bufnr=self.bufnr, filetype=self.filetype}
end

Viewport.__index = Viewport

function Viewport:new(winnr)
  return setmetatable({winnr=winnr}, self)
end

function Viewport:store()
  M.toplines[self.winnr] = vim.fn.winsaveview().topline
end

function Viewport:restore()
  local topline = M.toplines[self.winnr]
  if topline and vim.fn.winheight(self.winnr) > 0 then
    command(self.winnr .. "windo call winrestview({'topline':" .. topline .. "})")
  end
end

Layout.__index = Layout

function Layout:new()
  return setmetatable({
    tree                  = vim.fn.winlayout(),
    win_heights           = vim.g.concertina_win_heights,
    stretched_win_heights = vim.g.concertina_stretched_win_heights,
    ignore                = vim.g.concertina_ignore,
    observers             = {},
  }, self)
end

function Layout:set_fixed_height(winnr)
  local height = self:get_fixed_height(
    winnr, vim.fn.getwinvar(winnr, '&bt'), vim.fn.getwinvar(winnr, '&ft'))

  if height then
    command(winnr .. 'windo resize' .. height .. '|setl winfixheight')
    for _, observer in pairs(self.observers) do observer:on_resize(winnr, height) end
  end

  return height
end

function Layout:get_fixed_height(winnr, buftype, filetype)
  return self:is_stretched(winnr)
    and (self.stretched_win_heights[buftype] or self.stretched_win_heights[filetype])
    or (self.win_heights[buftype] or self.win_heights[filetype])
end

function Layout:is_stretched(winnr)
  local is_stretched = false

  local function recurse(root, winid)
    if root[1] == 'leaf' then return end

    for _, node in pairs(root[2]) do
      if node[1] == 'leaf' and node[2] == winid then
        is_stretched = root[1] == 'col'
        return
      end
      recurse(node, winid)
    end
  end

  recurse(self.tree, vim.fn.win_getid(winnr))
  return is_stretched
end

WinResizeObserver.__index = WinResizeObserver

function WinResizeObserver:new(win)
  return setmetatable({win = win}, self)
end

function WinResizeObserver:on_resize(_, height)
  -- Enforce the window height if the original height has changed and
  -- 1) if the iterable window has bigger height, as it looks more natural
  -- 2) if the focused window has fixed height
  if vim.fn.winheight(self.win.winnr) ~= self.win.height
    and (height > self.win.height or self.win.fixed_height) then
    self.win.should_enforce_height = true
  end
end

return M
