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
