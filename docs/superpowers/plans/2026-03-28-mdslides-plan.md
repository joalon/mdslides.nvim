# mdslides.nvim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Neovim plugin that presents Marp markdown files as slide decks with in-editor navigation.

**Architecture:** Single Lua module (`lua/mdslides/init.lua`) handles parsing, buffer management, navigation, and keymaps. A thin VimL bootstrap (`plugin/mdslides.vim`) registers the `:Slides` command. State lives in a module-level table.

**Tech Stack:** Lua (Neovim API), VimL (command registration), busted (testing)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lua/mdslides/init.lua` | All plugin logic: parsing, buffer/window management, navigation, rendering, keymaps, statusline |
| `plugin/mdslides.vim` | Register `:Slides` user command, delegate to Lua |
| `tests/mdslides_spec.lua` | Unit tests for parsing and navigation logic |

---

### Task 1: Marp Parsing

**Files:**
- Create: `tests/mdslides_spec.lua`
- Create: `lua/mdslides/init.lua`

- [ ] **Step 1: Write failing test — strip frontmatter and split slides**

```lua
-- tests/mdslides_spec.lua
local mdslides = require("mdslides")

describe("parse_slides", function()
  it("strips frontmatter and splits on ---", function()
    local lines = {
      "---",
      "marp: true",
      "theme: default",
      "---",
      "",
      "# Slide 1",
      "",
      "Content of slide 1",
      "",
      "---",
      "",
      "# Slide 2",
      "",
      "Content of slide 2",
    }
    local slides = mdslides.parse_slides(lines)
    assert.are.equal(2, #slides)
    assert.are.same({ "# Slide 1", "", "Content of slide 1" }, slides[1])
    assert.are.same({ "# Slide 2", "", "Content of slide 2" }, slides[2])
  end)

  it("handles file with no frontmatter", function()
    local lines = {
      "# Slide 1",
      "",
      "---",
      "",
      "# Slide 2",
    }
    local slides = mdslides.parse_slides(lines)
    assert.are.equal(2, #slides)
    assert.are.same({ "# Slide 1" }, slides[1])
    assert.are.same({ "# Slide 2" }, slides[2])
  end)

  it("trims leading and trailing blank lines per slide", function()
    local lines = {
      "---",
      "marp: true",
      "---",
      "",
      "",
      "# Slide 1",
      "",
      "",
      "---",
      "",
      "# Slide 2",
      "",
    }
    local slides = mdslides.parse_slides(lines)
    assert.are.same({ "# Slide 1" }, slides[1])
    assert.are.same({ "# Slide 2" }, slides[2])
  end)

  it("handles single slide with no separators", function()
    local lines = {
      "---",
      "marp: true",
      "---",
      "",
      "# Only slide",
    }
    local slides = mdslides.parse_slides(lines)
    assert.are.equal(1, #slides)
    assert.are.same({ "# Only slide" }, slides[1])
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `nvim --headless -c "lua require('busted.runner')({ standalone = false })" tests/mdslides_spec.lua` or if using a Makefile/luarocks busted: `busted tests/mdslides_spec.lua`

Expected: FAIL — module `mdslides` not found.

- [ ] **Step 3: Write minimal implementation of parse_slides**

```lua
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

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `busted tests/mdslides_spec.lua`

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/mdslides/init.lua tests/mdslides_spec.lua
git commit -m "feat: add Marp slide parser with tests"
```

---

### Task 2: Buffer & Window Management

**Files:**
- Modify: `lua/mdslides/init.lua`
- Modify: `tests/mdslides_spec.lua`

- [ ] **Step 1: Write failing test — start and stop presentation**

Add to `tests/mdslides_spec.lua`:

```lua
describe("presentation lifecycle", function()
  local source_buf

  before_each(function()
    -- Create a buffer with Marp content
    source_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(source_buf)
    vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, {
      "---",
      "marp: true",
      "---",
      "",
      "# Slide 1",
      "",
      "---",
      "",
      "# Slide 2",
    })
  end)

  after_each(function()
    if mdslides._state and mdslides._state.slide_buf then
      pcall(mdslides.stop)
    end
    pcall(vim.api.nvim_buf_delete, source_buf, { force = true })
  end)

  it("start creates a new buffer and shows slide 1", function()
    mdslides.start()
    local state = mdslides._state
    assert.is_not_nil(state)
    assert.are_not.equal(source_buf, state.slide_buf)
    assert.are.equal(state.slide_buf, vim.api.nvim_get_current_buf())
    assert.are.equal(1, state.current_index)
    local buf_lines = vim.api.nvim_buf_get_lines(state.slide_buf, 0, -1, false)
    assert.are.same({ "# Slide 1" }, buf_lines)
  end)

  it("stop restores the original buffer", function()
    mdslides.start()
    mdslides.stop()
    assert.are.equal(source_buf, vim.api.nvim_get_current_buf())
    assert.is_nil(mdslides._state)
  end)

  it("slide buffer has correct options", function()
    mdslides.start()
    local buf = mdslides._state.slide_buf
    assert.are.equal("nofile", vim.bo[buf].buftype)
    assert.are.equal("wipe", vim.bo[buf].bufhidden)
    assert.is_false(vim.bo[buf].swapfile)
    assert.are.equal("markdown", vim.bo[buf].filetype)
    assert.is_false(vim.bo[buf].modifiable)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({ standalone = false })" tests/mdslides_spec.lua`

Expected: FAIL — `mdslides.start` is nil.

- [ ] **Step 3: Implement start, stop, and render_slide**

Add to `lua/mdslides/init.lua` (before `return M`):

```lua
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

  M._state = {
    source_buf = source_buf,
    slide_buf = slide_buf,
    slides = slides,
    current_index = 1,
  }

  render_slide()
end

--- Stop presentation mode, restore original buffer.
function M.stop()
  local state = M._state
  if not state then return end
  M._state = nil
  vim.api.nvim_set_current_buf(state.source_buf)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({ standalone = false })" tests/mdslides_spec.lua`

Expected: All tests PASS (parsing + lifecycle).

- [ ] **Step 5: Commit**

```bash
git add lua/mdslides/init.lua tests/mdslides_spec.lua
git commit -m "feat: add presentation start/stop with buffer management"
```

---

### Task 3: Navigation

**Files:**
- Modify: `lua/mdslides/init.lua`
- Modify: `tests/mdslides_spec.lua`

- [ ] **Step 1: Write failing tests — next, prev, goto**

Add to `tests/mdslides_spec.lua`:

```lua
describe("navigation", function()
  local source_buf

  before_each(function()
    source_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(source_buf)
    vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, {
      "---",
      "marp: true",
      "---",
      "",
      "# Slide 1",
      "",
      "---",
      "",
      "# Slide 2",
      "",
      "---",
      "",
      "# Slide 3",
    })
    mdslides.start()
  end)

  after_each(function()
    if mdslides._state then pcall(mdslides.stop) end
    pcall(vim.api.nvim_buf_delete, source_buf, { force = true })
  end)

  it("next advances to slide 2", function()
    mdslides.next()
    assert.are.equal(2, mdslides._state.current_index)
    local lines = vim.api.nvim_buf_get_lines(mdslides._state.slide_buf, 0, -1, false)
    assert.are.same({ "# Slide 2" }, lines)
  end)

  it("next on last slide is a no-op", function()
    mdslides.next()
    mdslides.next()
    mdslides.next() -- already on slide 3
    assert.are.equal(3, mdslides._state.current_index)
  end)

  it("prev goes back to slide 1", function()
    mdslides.next()
    mdslides.prev()
    assert.are.equal(1, mdslides._state.current_index)
  end)

  it("prev on first slide is a no-op", function()
    mdslides.prev()
    assert.are.equal(1, mdslides._state.current_index)
  end)

  it("goto jumps to a specific slide", function()
    mdslides.goto_slide(3)
    assert.are.equal(3, mdslides._state.current_index)
    local lines = vim.api.nvim_buf_get_lines(mdslides._state.slide_buf, 0, -1, false)
    assert.are.same({ "# Slide 3" }, lines)
  end)

  it("goto clamps out-of-range values", function()
    mdslides.goto_slide(99)
    assert.are.equal(3, mdslides._state.current_index)
    mdslides.goto_slide(0)
    assert.are.equal(1, mdslides._state.current_index)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({ standalone = false })" tests/mdslides_spec.lua`

Expected: FAIL — `mdslides.next`, `mdslides.prev`, `mdslides.goto_slide` are nil.

- [ ] **Step 3: Implement next, prev, goto_slide**

Add to `lua/mdslides/init.lua` (before `return M`):

```lua
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({ standalone = false })" tests/mdslides_spec.lua`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/mdslides/init.lua tests/mdslides_spec.lua
git commit -m "feat: add slide navigation (next, prev, goto)"
```

---

### Task 4: Statusline

**Files:**
- Modify: `lua/mdslides/init.lua`

- [ ] **Step 1: Write failing test**

Add to `tests/mdslides_spec.lua`:

```lua
describe("statusline", function()
  local source_buf

  before_each(function()
    source_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(source_buf)
    vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, {
      "---",
      "marp: true",
      "---",
      "",
      "# Slide 1",
      "",
      "---",
      "",
      "# Slide 2",
    })
  end)

  after_each(function()
    if mdslides._state then pcall(mdslides.stop) end
    pcall(vim.api.nvim_buf_delete, source_buf, { force = true })
  end)

  it("returns slide position string", function()
    mdslides.start()
    assert.are.equal("Slide [1/2]", mdslides.statusline())
    mdslides.next()
    assert.are.equal("Slide [2/2]", mdslides.statusline())
  end)

  it("returns empty string when not presenting", function()
    assert.are.equal("", mdslides.statusline())
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — `mdslides.statusline` is nil.

- [ ] **Step 3: Implement statusline**

Add to `lua/mdslides/init.lua` (before `return M`):

```lua
--- Return a statusline string showing current slide position.
---@return string
function M.statusline()
  local state = M._state
  if not state then return "" end
  return string.format("Slide [%d/%d]", state.current_index, #state.slides)
end
```

Also update `M.start()` — after setting `filetype`, add:

```lua
  vim.wo[0].statusline = "%!v:lua.require('mdslides').statusline()"
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/mdslides/init.lua tests/mdslides_spec.lua
git commit -m "feat: add statusline showing slide position"
```

---

### Task 5: Keymaps

**Files:**
- Modify: `lua/mdslides/init.lua`

- [ ] **Step 1: Implement buffer-local keymaps in start()**

Add a helper function and call it from `M.start()` after `render_slide()`:

```lua
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
```

In `M.start()`, after the `render_slide()` call, add:

```lua
  set_keymaps(slide_buf)
```

- [ ] **Step 2: Manual verification**

Open Neovim with a test Marp file:

```bash
nvim --cmd "set rtp+=." test.md
```

With `test.md` containing a Marp presentation. Run `:Slides`, verify:
- `n`, `l`, `<Right>`, `<Down>` advance slides
- `p`, `h`, `<Left>`, `<Up>` go back
- `q` exits to original buffer

- [ ] **Step 3: Commit**

```bash
git add lua/mdslides/init.lua
git commit -m "feat: add default navigation keymaps"
```

---

### Task 6: :Slides Command with Completion

**Files:**
- Create: `plugin/mdslides.vim`
- Modify: `lua/mdslides/init.lua`

- [ ] **Step 1: Add command dispatch function to Lua module**

Add to `lua/mdslides/init.lua` (before `return M`):

```lua
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
```

- [ ] **Step 2: Create the VimL plugin file**

```vim
" plugin/mdslides.vim
if exists('g:loaded_mdslides')
  finish
endif
let g:loaded_mdslides = 1

command! -nargs=? -complete=customlist,MdslidesComplete Slides lua require('mdslides').command({ fargs = {<f-args>} })

function! MdslidesComplete(ArgLead, CmdLine, CursorPos) abort
  return luaeval("require('mdslides').complete()")
endfunction
```

- [ ] **Step 3: Manual verification**

```bash
nvim --cmd "set rtp+=." test.md
```

Verify:
- `:Slides` starts presentation
- `:Slides next` / `:Slides prev` navigate
- `:Slides 2` jumps to slide 2
- `:Slides stop` exits
- Tab after `:Slides ` completes `next`, `prev`, `stop`

- [ ] **Step 4: Commit**

```bash
git add plugin/mdslides.vim lua/mdslides/init.lua
git commit -m "feat: add :Slides command with tab completion"
```

---

### Task 7: Run All Tests and Final Verification

**Files:**
- No new files

- [ ] **Step 1: Run the full test suite**

Run: `nvim --headless -u NONE -c "set rtp+=." -c "lua require('busted.runner')({ standalone = false })" tests/mdslides_spec.lua`

Expected: All tests PASS.

- [ ] **Step 2: End-to-end manual test**

Create a test Marp file and run through the full workflow:

```bash
cat > /tmp/test-slides.md << 'EOF'
---
marp: true
theme: default
---

# Welcome

This is slide 1

---

# Middle

This is slide 2

---

# End

This is slide 3
EOF

nvim --cmd "set rtp+=." /tmp/test-slides.md
```

Verify:
- `:Slides` — shows "# Welcome" / slide 1 content
- Statusline shows `Slide [1/3]`
- `n` — advances to slide 2, statusline updates
- `p` — back to slide 1
- `:Slides 3` — jumps to slide 3
- `q` — returns to original markdown source
- `:Slides` then `:Slides stop` — also returns correctly

- [ ] **Step 3: Commit any fixes if needed, then tag**

```bash
git tag v0.1.0
```
