" vim:foldmethod=marker:fen:
scriptencoding utf-8


" Load Once {{{
if exists('g:loaded_restart') && g:loaded_restart
    finish
endif
let g:loaded_restart = 1
" }}}
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

" Global Variables {{{
if !exists('g:restart_save_window_values')
    let g:restart_save_window_values = 1
endif
if !exists('g:restart_save_fn')
    let g:restart_save_fn = []
endif
if !exists('g:restart_vim_progname')
    let g:restart_vim_progname = 'gvim'
endif
if !exists('g:restart_sessionoptions')
    let g:restart_sessionoptions = ''
endif
if !exists('g:restart_cd')
    let g:restart_cd = ''
endif

if g:restart_save_window_values
    call add(g:restart_save_fn, 's:save_window_values')
endif
" }}}

" Command to restart {{{
if !exists('g:restart_command')
    let g:restart_command = 'Restart'
endif

if g:restart_command != ''
    execute 'command! -bang -nargs=*' g:restart_command 'call restart#restart(<bang>0, <q-args>)'
endif
" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
