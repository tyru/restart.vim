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
        if executable(g:restart_vim_progname)
            execute printf('silent !%s', a:command)
        else
            " Fallback.
            macaction newWindow:
        endif
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
    let spawn_args = g:restart_vim_progname . ' ' . a:args
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
            let spawn_args .= ' -c' . ' "silent ' . ex . '"'
        endfor
        unlet r Fn
    endfor

    if g:restart_sessionoptions != ''
        let spawn_args = s:add_session_args(spawn_args)
    endif
    let spawn_args = s:add_window_maximized_args(spawn_args)
    let new_servername = s:generate_unique_servername()
    let spawn_args .= ' --servername ' . new_servername

    call s:delete_all_buffers(a:bang)

    if g:restart_cd !=# ''
        cd `=g:restart_cd`
    endif
    call s:spawn(spawn_args)

    " Wait until a new instance starts.
    while index(split(serverlist(), '\n'), new_servername) < 0
        sleep 250m
    endwhile
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

function! s:add_session_args(spawn_args)
    let spawn_args = a:spawn_args
    let basename = tempname()
    let session_file = fnamemodify(basename . '.vim', ':p')
    let i = 0
    while filereadable(session_file)
        let session_file = fnamemodify(basename . '_' . i . '.vim', ':p')
        let i += 1
    endwhile
    let ssop = &sessionoptions
    try
        let &sessionoptions = g:restart_sessionoptions
        mksession `=session_file`
        let spawn_args .= ' ' . join(['-S', '"' . session_file . '"',
        \                  '-c "', 'silent call delete(' . string(session_file) . ')"'])
    finally
        let &sessionoptions = ssop
    endtry
    return spawn_args
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
        return g:restart_check_window_maximized ?
        \   libcallnr('User32.dll', 'IsZoomed', v:windowid) : 0
    endfunction

    function! s:add_window_maximized_args(spawn_args)
        if !g:restart_check_window_maximized
            return a:spawn_args
        endif
        let spawn_args = a:spawn_args
        if s:check_window_maximized()
            let spawn_args .= ' -c "simalt ~x"'
        endif
        return spawn_args
    endfunction
else
    " TODO
    function! s:check_window_maximized()
        return 0
    endfunction

    " TODO
    function! s:add_window_maximized_args(spawn_args)
        return a:spawn_args
    endfunction
endif

function! s:generate_unique_servername()
    let n = 1
    while index(split(serverlist(), '\n'), 'GVIM' . n) >= 0
        let n += 1
    endwhile
    return 'GVIM' . n
endfunction


" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
