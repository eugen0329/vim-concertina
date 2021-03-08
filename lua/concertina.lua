local M = {Layout={}, last_handled={}, toplines={}, last_winid=0}
local MAX_HEIGHT = 999
local FIRST_WINNR = 1
local WITHOUT_EFFECTS = 'keepalt keepjumps '
local api, fn, g, o = vim.api, vim.fn, vim.g, vim.o
local command = function(cmd) return api.nvim_exec(cmd, false) end

local Win, Viewport, Layout, WinResizeObserver = {}, {}, M.Layout, {}

function M.init()
  if g.loaded_concertina then return end

  g.loaded_concertina = '0.0.6'
  o.winminheight = 0

  local au_win_scrolled = fn.exists('##WinScrolled') == 1 and
    "au WinScrolled * lua require'concertina'.on_view()\n" or ''
  command([[
  aug concertina
    au!
    au User concertina_on_enter lua require'concertina'.on_enter()
    au WinEnter * lua require'concertina'.on_enter()
    au BufEnter * lua require'concertina'.on_enter('BufEnter')
    au FileType * lua vim.defer_fn(function() require'concertina'.on_enter('FileType') end, 0)
    ]] .. au_win_scrolled .. [[
    au CursorHold * lua require'concertina'.on_view()
    au WinLeave * lua require'concertina'.on_leave()
  aug END]])

  if not g.concertina_win_heights then
    g.concertina_win_heights = {godebugstacktrace=10, godebugoutput=10, rst=20}
  end
  if not g.concertina_stretched_win_heights then
    g.concertina_stretched_win_heights = {quickfix=10, terminal=20, quickrun=20, godoc=20, pymoderun=20}
  end
  if not g.concertina_ignore then -- WARN: can be overruled by win_heights and stretched_win_heights
    g.concertina_ignore = {nofile=true, godebugvariables=true}
  end
end

function M.on_view()
  Viewport:new(fn.winnr()):store()
end

function M.on_leave()
  M.last_winid = fn.win_getid()
end

function M.on_enter(event)
  local layout = Layout:new()
  local win = Win:new(fn.winnr(), layout)
  table.insert(layout.observers, WinResizeObserver:new(win))

  win:handle_enter(function(last_handled)
    -- Ignore if
    -- 1) is already handled by win enter
    -- 2) configured to be ignored and wasn't overruled by stretched_win_heights or win_heights
    -- 3) is floating
    if event == 'BufEnter' and last_handled.bufnr == win.bufnr
      or event == 'FileType' and last_handled.filetype == win.filetype
      or win.fixed_height == nil and win:is_ignoreable()
      or api.nvim_win_get_config(fn.win_getid()).relative ~= '' then
      return
    end

    -- If the only window, maximize it and restore the viewport
    if fn.winnr('$') == FIRST_WINNR then
      return layout:maximize(FIRST_WINNR) and Viewport:new(win.winnr):restore()
    end

    win:keep_focused(function()
      -- Prevent topleft windows from collapsing when a sequence like
      -- `:rightbelow copen | rightbelow split | term` is used
      local last_winnr = fn.win_id2win(M.last_winid)
      if last_winnr == 0 then
        layout:maximize(FIRST_WINNR)
      else
        local last_win = Win:new(last_winnr, layout)
        if not last_win:is_ignoreable() and last_win.fixed_height then
          layout:maximize(FIRST_WINNR)
          layout:set_height(last_win)
        end
      end

      layout:set_height(win)
      win:set_fixed_heights_of_siblings()

      if win.should_enforce_height then
        layout:set_height(win)
      end
      win:each_sibling(function(winnr) Viewport:new(winnr):restore() end)
    end)

    Viewport:new(win.winnr):restore()
  end)
end

Win.__index = Win

function Win:new(winnr, layout)
  local win = setmetatable({
    layout   = layout,
    filetype = fn.getwinvar(winnr, '&ft'),
    buftype  = fn.getwinvar(winnr, '&bt'),
    winnr    = winnr,
  }, self)
  win.fixed_height = layout:get_fixed_height(win.winnr, win.buftype, win.filetype)
  win.height = win.fixed_height or MAX_HEIGHT

  return win
end

function Win:each_sibling(callback)
  for winnr = FIRST_WINNR, fn.winnr('$') do
    if winnr ~= self.winnr then callback(winnr) end
  end
end

function Win:keep_focused(callback)
  local original_eventignore = o.eventignore
  o.eventignore = 'all'

  local ok, result = pcall(callback)
  if not ok then error(debug.traceback(result)) end

  self:focus()
  o.eventignore = original_eventignore
end

function Win:focus()
  if fn.winnr() == self.winnr then return end
  command(WITHOUT_EFFECTS .. self.winnr .. 'wincmd w')
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
    if fixed_heights[winnr] and fn.winheight(winnr) ~= fixed_heights[winnr] then
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
  M.toplines[self.winnr] = fn.winsaveview().topline
end

function Viewport:restore()
  local topline = M.toplines[self.winnr]
  if topline and fn.winheight(self.winnr) > 0 then
    command(WITHOUT_EFFECTS .. self.winnr .. "windo call winrestview({'topline':" .. topline .. '})')
  end
end

Layout.__index = Layout

function Layout:new()
  return setmetatable({
    tree                  = fn.winlayout(),
    win_heights           = g.concertina_win_heights,
    stretched_win_heights = g.concertina_stretched_win_heights,
    ignore                = g.concertina_ignore,
    observers             = {},
  }, self)
end

function Layout:set_fixed_height(winnr)
  local height = self:get_fixed_height(
    winnr, fn.getwinvar(winnr, '&bt'), fn.getwinvar(winnr, '&ft'))

  if height then
    command(WITHOUT_EFFECTS .. winnr .. 'windo resize' .. height .. '|setl winfixheight')
    self:notify_resized(winnr, height)
  end

  return height
end

function Layout:set_height(win)
  local lock_height = win.fixed_height and '|setl winfixheight' or ''

  command(WITHOUT_EFFECTS .. win.winnr .. 'windo resize' .. win.height .. lock_height)
  self:notify_resized(win.winnr, win.height)

  return win.height
end

function Layout:maximize(winnr)
  command(WITHOUT_EFFECTS .. winnr .. 'windo resize' .. MAX_HEIGHT)
  self:notify_resized(winnr, MAX_HEIGHT)
end

function Layout:notify_resized(winnr, height)
  for _, observer in pairs(self.observers) do
    observer:on_resize(winnr, height)
  end
end

function Layout:get_fixed_height(winnr, buftype, filetype)
  return self:is_stretched(winnr)
    and (self.stretched_win_heights[buftype] or self.stretched_win_heights[filetype])
    or (self.win_heights[buftype] or self.win_heights[filetype])
end

function Layout:is_stretched(winnr)
  local is_stretched = false

  -- It's stretched unless 'row' is encountered after the first, but not the
  -- only node.
  local function recurse(parent, winid, depth)
    if parent[1] == 'leaf' then return end
    if parent[1] == 'row' and depth > 0 then
      is_stretched = false
      return
    end

    for _, child in pairs(parent[2]) do
      if child[1] == 'leaf' and child[2] == winid then
        is_stretched = parent[1] == 'col'
        return
      end

      recurse(child, winid, depth + 1)
    end
  end

  recurse(self.tree, fn.win_getid(winnr), 0)
  return is_stretched
end

WinResizeObserver.__index = WinResizeObserver

function WinResizeObserver:new(win)
  return setmetatable({win = win}, self)
end

function WinResizeObserver:on_resize(winnr, height)
  -- Enforce the window height if the original height has changed and
  -- 1) if the iterable window has bigger height, as it looks more natural
  -- 2) if the focused window has fixed height
  if self.winnr ~= winnr
    and fn.winheight(self.win.winnr) ~= self.win.height
    and (height > self.win.height or self.win.fixed_height) then
    self.win.should_enforce_height = true
  end
end

return M
