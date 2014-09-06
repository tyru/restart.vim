" vim:foldmethod=marker:fen:
scriptencoding utf-8


if !has('gui_running')
    function! restart#restart(...)
        echohl ErrorMsg
        echomsg 'restart.vim does not work under the terminal.'
        echohl None

        augroup restart
            autocmd!

            " <sfile> is replaced by "function restart#restart"
            " on Vim 7.3.729 ...
            " autocmd GUIEnter * source <sfile>
            autocmd GUIEnter * runtime! autoload/restart.vim
        augroup END
    endfunction
    finish
endif

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

" Scope Variables {{{
let s:is_win = has('win16') || has('win32') || has('win64')
let s:is_macvim = has('gui_macvim')
" }}}



function! s:spawn(command) "{{{
    wviminfo
    if s:is_win
        " NOTE: If a:command is .bat file,
        " cmd.exe appears and won't close.
        execute printf('silent !start %s', a:command)
    elseif s:is_macvim
        " TODO: Support a:command
        macaction newWindow:
    else
        execute printf('silent !%s', a:command)
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

function! restart#restart(bang, args) abort "{{{
    let spawn_args = g:restart_vim_progname . ' ' . a:args . ' '
    for Fn in g:restart_save_fn
        let r = call(Fn, [])
        if type(r) !=# type([])
            echohl WarningMsg
            echomsg 'restart.vim: invalid value'
            \     . ' in g:restart_save_fn: ' + string(r)
            echohl None
            continue
        endif
        for ex in r
            let spawn_args .= '-c' . ' "' . ex . '" '
        endfor
        unlet r Fn
    endfor

    if g:restart_sessionoptions != ''
        call s:make_session_file()
    endif
    call s:delete_all_buffers(a:bang)
    let spawn_args = s:build_args_window_maximized(spawn_args)

    if g:restart_cd !=# ''
        cd `=g:restart_cd`
    endif
    call s:spawn(spawn_args)

    " NOTE: Need bang because surprisingly
    " ':silent! 1,$bwipeout' does not wipeout current unnamed buffer!
    execute 'qall' . (a:bang ? '!' : '')
endfunction "}}}

function! s:save_window_values() "{{{
    if s:check_window_maximized()
        return []
    endif
    return [
    \   printf('set lines=%d', &lines),
    \   printf('set columns=%d', &columns),
    \   printf('winpos %s %s', getwinposx(), getwinposy()),
    \]
endfunction "}}}

function! s:make_session_file()
    " The reason why not use tempname() is that
    " the created file will be removed by Vim at exit.
    let session_file = fnamemodify('restart_session.vim', ':p')
    let i = 0
    while filereadable(session_file)
        let session_file = fnamemodify('restart_session_' . i . '.vim', ':p')
        let i += 1
    endwhile
    let ssop = &sessionoptions
    try
        let &sessionoptions = g:restart_sessionoptions
        mksession `=session_file`
        let spawn_args .= join(['-S', '"' . session_file . '"',
        \                  '-c "', 'call delete(' . string(session_file) . ')"']) . ' '
    finally
        let &sessionoptions = ssop
    endtry
endfunction

" Delete all buffers to delete the swap files.
function! s:delete_all_buffers(bang)
    set nohidden
    if a:bang
        silent! 1,$bwipeout
    else
        try
            for buf in values(s:parse_buffers_info())
                execute 'confirm ' . buf.nr . 'bwipeout'
            endfor
        catch
            " 'Cancel' was selected.
            " (E517: No buffers were wiped out)
            return
        endtry
    endif
endfunction

if s:is_win
    function! s:check_window_maximized()
        return libcallnr('User32.dll', 'IsZoomed', v:windowid)
    endfunction

    function! s:build_args_window_maximized(spawn_args)
        let spawn_args = a:spawn_args
        if s:check_window_maximized() && s:is_win
            let spawn_args .= '-c "simalt ~x" '
        endif
        return spawn_args
    endfunction
else
    " TODO
    function! s:check_window_maximized()
        return 0
    endfunction

    " TODO
    function! s:build_args_window_maximized(spawn_args)
        return a:spawn_args
    endfunction
endif


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
