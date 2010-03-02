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
" Version: 0.0.0
" Author:  tyru <tyru.exe@gmail.com>
" Last Change: 2010-03-02.
"
" Description:
"   Restart your gVim.
"
" Change Log: {{{
"   0.0.0: Initial upload
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
"   }}}
" }}}
" TODO: {{{
"   - Support vim (Is this possible...?)
" }}}
"==================================================
" }}}

" NOTE: THIS PLUGIN CAN'T WORK UNDER THE TERMINAL.
if !has('gui_running')
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

" Global Variables {{{
if !exists('g:restart_command')
    let g:restart_command = 'Restart'
endif
" }}}

" utility functions
" s:warn {{{
func! s:warn(msg)
    echohl WarningMsg
    echomsg a:msg
    echohl None
endfunc
" }}}
" s:warnf {{{
func! s:warnf(fmt, ...)
    call s:warn(call('printf', [a:fmt] + a:000))
endfunc
" }}}
" s:system {{{
func! s:system(command, ...)
    let args = [a:command] + map(copy(a:000), 'shellescape(v:val)')
    return system(join(args, ' '))
endfunc
" }}}
func! s:is_modified() "{{{
    try
        bmodified
        return 1
    catch
        return 0
    endtry
endfunc "}}}

" Function to restart {{{
func! s:restart(bang)
    let bangged = a:bang ==# '!'

    if s:is_modified()
        call s:warn("modified buffer(s) exist!")
        if !bangged
            return
        endif
    endif

    call s:system(
    \   'gvim',
    \   '-c', printf('set lines=%d', &lines),
    \   '-c', printf('set columns=%d', &columns),
    \   '-c', printf('winpos %s %s', getwinposx(), getwinposy()),
    \)
    execute 'qall'.a:bang
endfunc
" }}}
" Command to restart {{{
if g:restart_command != ''
    execute 'command! -bang' g:restart_command 'call s:restart("<bang>")'
endif
" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
