---
marp: true
theme: default
---

# mdslides.nvim

A slide presentation plugin for Neovim

---

## Getting Started

1. Open this file in Neovim
2. Run `:Slides`
3. Navigate with `n` and `p`

---

## Features

- **Marp** frontmatter support
- Treesitter-highlighted markdown
- Keyboard navigation
- Statusline with slide position

---

## Code Example

```lua
local mdslides = require("mdslides")

-- Start presenting
mdslides.start()

-- Navigate
mdslides.next()
mdslides.prev()
mdslides.goto_slide(3)
```

---

## Thanks

That's all. Press `q` to exit.
