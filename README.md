# mdslides.nvim

Present [Marp](https://marp.app/) slide decks inside Neovim.

## Install

lazy.nvim (local):

```lua
{ dir = "~/Code/mdslides.nvim" }
```

## Usage

Open a Marp markdown file and run:

```
:Slides          " start presenting
:Slides next     " next slide
:Slides prev     " previous slide
:Slides 5        " jump to slide 5
:Slides stop     " exit presentation
```

### Keymaps (active during presentation)

| Key | Action |
|-----|--------|
| `n` `l` `<Right>` `<Down>` | Next slide |
| `p` `h` `<Left>` `<Up>` | Previous slide |
| `q` | Quit |

## Example

See [example/demo.md](example/demo.md) for a sample presentation.
