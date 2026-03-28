" plugin/mdslides.vim
if exists('g:loaded_mdslides')
  finish
endif
let g:loaded_mdslides = 1

command! -nargs=? -complete=customlist,MdslidesComplete Slides lua require('mdslides').command({ fargs = {<f-args>} })

function! MdslidesComplete(ArgLead, CmdLine, CursorPos) abort
  return luaeval("require('mdslides').complete()")
endfunction
