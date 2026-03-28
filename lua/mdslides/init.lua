-- lua/mdslides/init.lua
local M = {}

--- Parse Marp markdown lines into a list of slides.
--- Each slide is a list of strings (lines).
---@param lines string[]
---@return string[][]
function M.parse_slides(lines)
  local body_start = 1

  -- Strip YAML frontmatter: if line 1 is "---", skip to the next "---"
  if lines[1] and lines[1]:match("^%s*---%s*$") then
    for i = 2, #lines do
      if lines[i]:match("^%s*---%s*$") then
        body_start = i + 1
        break
      end
    end
  end

  -- Split on "---" delimiters
  local slides = {}
  local current = {}
  for i = body_start, #lines do
    if lines[i]:match("^%s*---%s*$") then
      slides[#slides + 1] = current
      current = {}
    else
      current[#current + 1] = lines[i]
    end
  end
  if #current > 0 then
    slides[#slides + 1] = current
  end

  -- Trim leading/trailing blank lines per slide
  for i, slide in ipairs(slides) do
    local first, last = 1, #slide
    while first <= last and slide[first]:match("^%s*$") do
      first = first + 1
    end
    while last >= first and slide[last]:match("^%s*$") do
      last = last - 1
    end
    local trimmed = {}
    for j = first, last do
      trimmed[#trimmed + 1] = slide[j]
    end
    slides[i] = trimmed
  end

  return slides
end

-- Module-level state (nil when not presenting)
M._state = nil

--- Render the current slide into the slide buffer.
local function render_slide()
  local state = M._state
  if not state then return end
  vim.bo[state.slide_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.slide_buf, 0, -1, false, state.slides[state.current_index])
  vim.bo[state.slide_buf].modifiable = false
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

--- Set up buffer-local keymaps for the slide buffer.
local function set_keymaps(buf)
  local opts = { buffer = buf, nowait = true, silent = true }
  for _, key in ipairs({ "n", "l", "<Right>", "<Down>" }) do
    vim.keymap.set("n", key, function() M.next() end, opts)
  end
  for _, key in ipairs({ "p", "h", "<Left>", "<Up>" }) do
    vim.keymap.set("n", key, function() M.prev() end, opts)
  end
  vim.keymap.set("n", "q", function() M.stop() end, opts)
end

--- Start presentation mode from the current buffer.
function M.start()
  if M._state then return end

  local source_buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
  local slides = M.parse_slides(lines)

  if #slides == 0 then
    vim.notify("mdslides: no slides found", vim.log.levels.WARN)
    return
  end

  local slide_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[slide_buf].buftype = "nofile"
  vim.bo[slide_buf].bufhidden = "wipe"
  vim.bo[slide_buf].swapfile = false

  vim.api.nvim_set_current_buf(slide_buf)

  vim.bo[slide_buf].filetype = "markdown"
  vim.wo[0].statusline = "%!v:lua.require('mdslides').statusline()"

  M._state = {
    source_buf = source_buf,
    slide_buf = slide_buf,
    slides = slides,
    current_index = 1,
  }

  render_slide()
  set_keymaps(slide_buf)
end

--- Stop presentation mode, restore original buffer.
function M.stop()
  local state = M._state
  if not state then return end
  M._state = nil
  vim.api.nvim_set_current_buf(state.source_buf)
end

--- Advance to the next slide.
function M.next()
  local state = M._state
  if not state then return end
  if state.current_index < #state.slides then
    state.current_index = state.current_index + 1
    render_slide()
  end
end

--- Go back to the previous slide.
function M.prev()
  local state = M._state
  if not state then return end
  if state.current_index > 1 then
    state.current_index = state.current_index - 1
    render_slide()
  end
end

--- Jump to a specific slide number (clamped to valid range).
---@param n number
function M.goto_slide(n)
  local state = M._state
  if not state then return end
  n = math.max(1, math.min(n, #state.slides))
  state.current_index = n
  render_slide()
end

--- Return a statusline string showing current slide position.
---@return string
function M.statusline()
  local state = M._state
  if not state then return "" end
  return string.format("Slide [%d/%d]", state.current_index, #state.slides)
end

--- Dispatch :Slides subcommands.
---@param opts table  command callback opts from nvim_create_user_command
function M.command(opts)
  local arg = opts.fargs[1]
  if arg == nil or arg == "" then
    M.start()
  elseif arg == "next" then
    M.next()
  elseif arg == "prev" then
    M.prev()
  elseif arg == "stop" then
    M.stop()
  elseif tonumber(arg) then
    M.goto_slide(tonumber(arg))
  else
    vim.notify("mdslides: unknown command: " .. arg, vim.log.levels.ERROR)
  end
end

--- Tab completion for :Slides subcommands.
---@return string[]
function M.complete()
  return { "next", "prev", "stop" }
end

return M
