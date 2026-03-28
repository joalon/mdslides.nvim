# mdslides.nvim — Design Spec

A Neovim plugin for presenting Marp markdown slide decks inside the editor.

## Overview

The user opens a Marp markdown file, runs `:Slides`, and the plugin parses the
file into individual slides, opens a new scratch buffer on top of the original,
and renders each slide as treesitter-highlighted, concealed markdown. Navigation
is via commands and default keymaps.

## Plugin Structure

```
plugin/mdslides.vim     — register :Slides command (one-liner into Lua)
lua/mdslides/init.lua   — all logic: parsing, buffer management, navigation, keymaps
```

Single Lua module. State lives in a module-level table.

## Parsing

When `:Slides` is invoked:

1. Read all lines from the current buffer.
2. Strip YAML frontmatter — everything between the opening `---` (line 1) and
   the next `---` line. This includes the Marp `marp: true` directive.
3. Split remaining content on `---` delimiter lines. A delimiter is a line
   matching `^%s*---%s*$`.
4. Each chunk becomes one slide. Trim leading/trailing blank lines per slide.
5. Store slides as a Lua list of string arrays (one array of lines per slide).

Speaker notes (`<!-- notes -->` blocks) and Marp directives
(`<!-- _class: ... -->`) are left as-is in v1 — they display as HTML comments.

## Buffer & Window Management

### Entering presentation mode

1. Save a reference to the current buffer as `source_buf`.
2. Create a new scratch buffer `slide_buf` with options:
   - `buftype = "nofile"`
   - `bufhidden = "wipe"`
   - `swapfile = false`
3. Set `slide_buf` into the current window (replaces the view, no split).
4. Set buffer options: `filetype = "markdown"`, `modifiable = false`.
5. Store state in a module-level table:
   `{ source_buf, slide_buf, slides, current_index }`.

### Exiting presentation mode

Triggered by `:Slides stop` or `q` keymap:

1. Switch the current window back to `source_buf`.
2. The scratch buffer auto-wipes due to `bufhidden = "wipe"`.
3. Clear the module state table.

## Navigation & Rendering

### Rendering a slide

1. Set `modifiable = true` on `slide_buf`.
2. Replace all buffer lines with `slides[current_index]`.
3. Set `modifiable = false`.
4. Move cursor to line 1.

### `:Slides next` / `:Slides prev`

- Clamp to bounds: `next` on last slide is a no-op, `prev` on first is a no-op.
- Update `current_index`, then re-render.

### Statusline

- Set a buffer-local statusline on `slide_buf`:
  `%!v:lua.require('mdslides').statusline()`
- Displays: `Slide [3/12]`

## Default Keymaps

All keymaps are buffer-local to `slide_buf` with `nowait = true`.

| Key                          | Action     |
|------------------------------|------------|
| `n`, `l`, `<Right>`, `<Down>` | Next slide |
| `p`, `h`, `<Left>`, `<Up>`    | Prev slide |
| `q`                           | Quit       |

## Commands

Single user command `:Slides` with subcommand parsing on the first argument:

| Invocation      | Action                                    |
|-----------------|-------------------------------------------|
| `:Slides`       | Start presentation (parse buffer, show slide 1) |
| `:Slides next`  | Next slide                                |
| `:Slides prev`  | Previous slide                            |
| `:Slides stop`  | Exit presentation mode                    |
| `:Slides {n}`   | Jump to slide number `n`                  |

Tab completion provides: `next`, `prev`, `stop`.

## Out of Scope (v1)

- Marp themes and styling directives
- Image sizing / rendering
- Math / KaTeX rendering
- Speaker notes extraction or separate display
- Configurable keymaps via `setup()`
