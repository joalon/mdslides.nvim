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
