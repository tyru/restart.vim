" vim:foldmethod=marker:fen:
scriptencoding utf-8

" NEW BSD LICENSE {{{
"   Copyright (c) 2009, tyru
"   All rights reserved.
"
"   Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
"
"       * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
"       * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
"       * Neither the name of the tyru nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
"
"   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
" }}}
" Document {{{
"==================================================
" Name: restart.vim
" Version: 0.0.3
" Author:  tyru <tyru.exe@gmail.com>
" Last Change: 2010-06-26.
"
" Description:
"   Restart your gVim.
"
" Change Log: {{{
"   0.0.0: Initial upload
"   0.0.1:
"   - Do not restart if modified buffer(s) exist.
"   - etc.
"   0.0.2:
"   - Don't show 'modified buffer(s) ...' when banged.
"   - Add g:restart_save_window_values, g:restart_save_fn.
"   0.0.3:
"   - Add g:restart_vim_progname.
"   - Support MS Windows.
"   - Fix minor bugs.
" }}}
" Usage: {{{
"   Commands: {{{
"       :Restart
"           If modified buffer(s) exist, gVim won't restart.
"           If you want to quit anyway, add bang(:Restart!).
"   }}}
"   Global Variables: {{{
"       g:restart_command (default: 'Restart')
"           command name to restart gVim.
"
"       g:restart_save_window_values (default: 1)
"           Save window values when restarting gVim.
"           Saving values are as follows:
"           - &line
"           - &columns
"           - gVim window position (getwinposx(), getwinposy())
"           Before v0.0.1, restart.vim saves above values.
"           So this variable is for compatibility.
"
"       g:restart_save_fn (default: g:restart_save_fn is true: ['s:save_window_values'], false: [])
"           This variable saves functions returning ex command.
"           e.g., in your .vimrc:
"
"               function! Hello()
"                   return 'echomsg "hello"'
"               endfunction
"               let g:restart_save_fn = [function('Hello')]
"
"           This meaningless example shows "hello" in new starting up gVim.
"           When g:restart_save_window_values is true,
"           this variable is ['s:save_window_values'].
"
"               function! s:save_window_values()
"                   return join([
"                   \       printf('set lines=%d', &lines),
"                   \       printf('set columns=%d', &columns),
"                   \       printf('winpos %s %s', getwinposx(), getwinposy()),
"                   \   ],
"                   \   ' | '
"                   \)
"               endfunction
"
"          As you can see, this function saves current gVim's:
"          - &line
"          - &columns
"          - getwinposx()
"          - getwinposy()
"
"       g:restart_vim_progname (default: "gvim")
"          gVim program name to restart.
"
"          FIXME:
"          Under MS Windows, you must not assign .bat file path
"          to this variable. Because cmd.exe appears and won't close.
"   }}}
" }}}
" TODO: {{{
"   - Support vim (Is this possible...?)
" }}}
"==================================================
" }}}

if !has('gui_running')
    " NOTE: THIS PLUGIN CAN'T WORK UNDER THE TERMINAL.
    augroup restart
        autocmd!
        autocmd GUIEnter * source `=expand('<sfile>')`
    augroup END
    finish
endif

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

" Scope Variables {{{
let s:is_win = has('win16') || has('win32') || has('win64')
" }}}
" Global Variables {{{
if !exists('g:restart_command')
    let g:restart_command = 'Restart'
endif
if !exists('g:restart_save_window_values')
    let g:restart_save_window_values = 1
endif
if !exists('g:restart_save_fn')
    let g:restart_save_fn = []
endif
if !exists('g:restart_vim_progname')
    let g:restart_vim_progname = 'gvim'
endif

if g:restart_save_window_values
    call add(g:restart_save_fn, 's:save_window_values')
endif
" }}}



function! s:warn(msg) "{{{
    echohl WarningMsg
    echomsg a:msg
    echohl None
endfunction "}}}
function! s:warnf(fmt, ...) "{{{
    call s:warn(call('printf', [a:fmt] + a:000))
endfunction "}}}
function! s:shellescape(...) "{{{
    if s:is_win
        let save_shellslash = &shellslash
        let &l:shellslash = 0
        try
            return call('shellescape', a:000)
        finally
            let &l:shellslash = save_shellslash
        endtry
    else
        return call('shellescape', a:000)
    endif
endfunction "}}}
function! s:spawn(command, ...) "{{{
    let args = map(copy(a:000), 's:shellescape(v:val)')
    if s:is_win
        let command   = s:shellescape(a:command)
        let arguments = join(args, ' ')
        " NOTE: If a:command is .bat file,
        " cmd.exe appears and won't close.
        execute printf('silent !start %s %s', command, arguments)
    else
        let command   = s:shellescape(a:command)
        let arguments = join(args, ' ')
        execute printf('silent !%s %s', command, arguments)
    endif
endfunction "}}}
function! s:is_modified() "{{{
    try
        " TODO Boolean value to select whether user switches to modified buffer or not.
        bmodified
        return 1
    catch
        " Fall through.
    endtry

    for [bufnr, info] in items(s:parse_buffers_info())
        if info.is_modified
            return 1
        endif
    endfor

    return 0
endfunction "}}}
function! s:parse_buffers_info() "{{{
    " This function is from dumbbuf.vim :)


    " redirect output of :ls! to ls_out.
    redir => ls_out
    silent ls!
    redir END
    let buf_list = split(ls_out, "\n")

    " see ':help :ls' about regexp.
    let regex =
        \'^'.'\s*'.
        \'\(\d\+\)'.
        \'\([u ]\)'.
        \'\([%# ]\)'.
        \'\([ah ]\)'.
        \'\([-= ]\)'.
        \'\([\+x ]\)'

    let result = {}

    for line in buf_list
        let m = matchlist(line, regex)
        if empty(m) | continue | endif

        " bufnr:
        "   buffer number.
        "   this must NOT be -1.
        " unlisted:
        "   'u' or empty string.
        "   'u' means buffer is NOT listed.
        "   empty string means buffer is listed.
        " percent_numsign:
        "   '%' or '#' or empty string.
        "   '%' means current buffer.
        "   '#' means sub buffer.
        " a_h:
        "   'a' or 'h' or empty string.
        "   'a' means buffer is loaded and active(displayed).
        "   'h' means buffer is loaded but not active(hidden).
        " minus_equal:
        "   '-' or '=' or empty string.
        "   '-' means buffer is not modifiable.
        "   '=' means buffer is readonly.
        " plus_x:
        "   '+' or 'x' or empty string.
        "   '+' means buffer is modified.
        "   'x' means error occured while loading buffer.
        let [bufnr, unlisted, percent_numsign, a_h, minus_equal, plus_x; rest] = m[1:]

        let result[bufnr] = {
            \'nr': bufnr + 0,
            \'is_unlisted': unlisted ==# 'u',
            \'is_current': percent_numsign ==# '%',
            \'is_sub': percent_numsign ==# '#',
            \'is_active': a_h ==# 'a',
            \'is_hidden': a_h ==# 'h',
            \'is_modifiable': minus_equal !=# '-',
            \'is_readonly': minus_equal ==# '=',
            \'is_modified': plus_x ==# '+',
            \'is_err': plus_x ==# 'x',
            \'lnum': -1,
        \}
    endfor

    return result
endfunction "}}}

function! s:restart(bang) "{{{
    if s:is_modified() && !a:bang
        call s:warn("modified buffer(s) exist!")
        return
    endif

    let spawn_args = [g:restart_vim_progname]
    for Fn in g:restart_save_fn
        let r = call(Fn, [])
        for ex in type(r) == type([]) ? r : [r]
            let spawn_args += ['-c', ex]
        endfor
        unlet Fn
    endfor
    call call('s:spawn', spawn_args)

    execute 'qall' . (a:bang ? '!' : '')
endfunction "}}}

function! s:save_window_values() "{{{
    return [
    \   printf('set lines=%d', &lines),
    \   printf('set columns=%d', &columns),
    \   printf('winpos %s %s', getwinposx(), getwinposy()),
    \]
endfunction "}}}



" Command to restart {{{
if g:restart_command != ''
    execute 'command! -bar -bang' g:restart_command 'call s:restart(<bang>0)'
endif
" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
