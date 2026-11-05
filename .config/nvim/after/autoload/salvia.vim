" =============================================================================
" URL: https://github.com/sainnhe/salvia
" Filename: autoload/salvia.vim
" Author: sainnhe
" Email: i@sainnhe.dev
" License: MIT License
" =============================================================================

function! salvia#get_configuration() "{{{
  let float_style = get(g:, 'salvia_float_style', 'bright')
  if float_style ==# 'none'
    let float_style = 'blend'
    echoerr "g:salvia_float_style='none' was renamed to 'blend'"
  endif

  return {
        \ 'background': get(g:, 'salvia_background', 'medium'),
        \ 'transparent_background': get(g:, 'salvia_transparent_background', 0),
        \ 'dim_inactive_windows': get(g:, 'salvia_dim_inactive_windows', 0),
        \ 'disable_italic_comment': get(g:, 'salvia_disable_italic_comment', 0),
        \ 'enable_italic': get(g:, 'salvia_enable_italic', 0),
        \ 'cursor': get(g:, 'salvia_cursor', ''),
        \ 'sign_column_background': get(g:, 'salvia_sign_column_background', 'none'),
        \ 'spell_foreground': get(g:, 'salvia_spell_foreground', 'none'),
        \ 'ui_contrast': get(g:, 'salvia_ui_contrast', 'low'),
        \ 'show_eob': get(g:, 'salvia_show_eob', 1),
        \ 'float_style': float_style,
        \ 'pmenu_style': get(g:, 'salvia_pmenu_style', 'bright'),
        \ 'current_word': get(g:, 'salvia_current_word', get(g:, 'salvia_transparent_background', 0) == 0 ? 'grey background' : 'bold'),
        \ 'inlay_hints_background': get(g:, 'salvia_inlay_hints_background', 'none'),
        \ 'lightline_disable_bold': get(g:, 'salvia_lightline_disable_bold', 0),
        \ 'diagnostic_text_highlight': get(g:, 'salvia_diagnostic_text_highlight', 0),
        \ 'diagnostic_line_highlight': get(g:, 'salvia_diagnostic_line_highlight', 0),
        \ 'diagnostic_virtual_text': get(g:, 'salvia_diagnostic_virtual_text', 'grey'),
        \ 'disable_terminal_colors': get(g:, 'salvia_disable_terminal_colors', 0),
        \ 'better_performance': get(g:, 'salvia_better_performance', 0),
        \ 'colors_override': get(g:, 'salvia_colors_override', {}),
        \ }
endfunction "}}}
function! salvia#get_palette(background, colors_override) "{{{
  if a:background ==# 'hard' "{{{
    if &background ==# 'dark'
      let palette1 = {
            \ 'bg_dim':     ['#121313',   'NONE'],
            \ 'bg0':        ['#1b1c1c',   'NONE'],
            \ 'bg1':        ['#242626',   'NONE'],
            \ 'bg2':        ['#303231',   'NONE'],
            \ 'bg3':        ['#3b3e3c',   'NONE'],
            \ 'bg4':        ['#2a2c2b',   'NONE'],
            \ 'bg5':        ['#767974',   'NONE'],
            \ 'bg_visual':  ['#2d302e',   'NONE'],
            \ 'bg_red':     ['#3a2625',   'NONE'],
            \ 'bg_yellow':  ['#3a3218',   'NONE'],
            \ 'bg_green':   ['#2a3028',   'NONE'],
            \ 'bg_blue':    ['#243036',   'NONE'],
            \ 'bg_purple':  ['#2e2836',   'NONE'],
            \ }
    else
      let palette1 = {
            \ 'bg_dim':     ['#f2efdf',   '223'],
            \ 'bg0':        ['#fffbef',   '230'],
            \ 'bg1':        ['#f8f5e4',   '228'],
            \ 'bg2':        ['#f2efdf',   '223'],
            \ 'bg3':        ['#edeada',   '223'],
            \ 'bg4':        ['#e8e5d5',   '223'],
            \ 'bg5':        ['#bec5b2',   '223'],
            \ 'bg_visual':  ['#f0f2d4',   '194'],
            \ 'bg_red':     ['#ffe7de',   '217'],
            \ 'bg_yellow':  ['#fef2d5',   '226'],
            \ 'bg_green':   ['#f3f5d9',   '194'],
            \ 'bg_blue':    ['#ecf5ed',   '117'],
            \ 'bg_purple':  ['#fceced',   '189'],
            \ }
    endif "}}}
  elseif a:background ==# 'medium' "{{{
    if &background ==# 'dark'
      let palette1 = {
            \ 'bg_dim':     ['#121313',   'NONE'],
            \ 'bg0':        ['#1b1c1c',   'NONE'],
            \ 'bg1':        ['#242626',   'NONE'],
            \ 'bg2':        ['#303231',   'NONE'],
            \ 'bg3':        ['#3b3e3c',   'NONE'],
            \ 'bg4':        ['#2a2c2b',   'NONE'],
            \ 'bg5':        ['#767974',   'NONE'],
            \ 'bg_visual':  ['#2d302e',   'NONE'],
            \ 'bg_red':     ['#3a2625',   'NONE'],
            \ 'bg_yellow':  ['#3a3218',   'NONE'],
            \ 'bg_green':   ['#2a3028',   'NONE'],
            \ 'bg_blue':    ['#243036',   'NONE'],
            \ 'bg_purple':  ['#2e2836',   'NONE'],
            \ }
    else
      let palette1 = {
            \ 'bg_dim':     ['#efebd4',   '223'],
            \ 'bg0':        ['#fdf6e3',   '230'],
            \ 'bg1':        ['#f4f0d9',   '228'],
            \ 'bg2':        ['#efebd4',   '223'],
            \ 'bg3':        ['#e6e2cc',   '223'],
            \ 'bg4':        ['#e0dcc7',   '223'],
            \ 'bg5':        ['#bdc3af',   '223'],
            \ 'bg_visual':  ['#eaedc8',   '194'],
            \ 'bg_red':     ['#fde3da',   '217'],
            \ 'bg_yellow':  ['#faedcd',   '226'],
            \ 'bg_green':   ['#f0f1d2',   '194'],
            \ 'bg_blue':    ['#e9f0e9',   '117'],
            \ 'bg_purple':  ['#fae8e2',   '189'],
            \ }
    endif "}}}
  else "{{{
    if &background ==# 'dark'
      let palette1 = {
            \ 'bg_dim':     ['#121313',   'NONE'],
            \ 'bg0':        ['#1b1c1c',   'NONE'],
            \ 'bg1':        ['#242626',   'NONE'],
            \ 'bg2':        ['#303231',   'NONE'],
            \ 'bg3':        ['#3b3e3c',   'NONE'],
            \ 'bg4':        ['#2a2c2b',   'NONE'],
            \ 'bg5':        ['#767974',   'NONE'],
            \ 'bg_visual':  ['#2d302e',   'NONE'],
            \ 'bg_red':     ['#3a2625',   'NONE'],
            \ 'bg_yellow':  ['#3a3218',   'NONE'],
            \ 'bg_green':   ['#2a3028',   'NONE'],
            \ 'bg_blue':    ['#243036',   'NONE'],
            \ 'bg_purple':  ['#2e2836',   'NONE'],
            \ }
    else
      let palette1 = {
            \ 'bg_dim':     ['#e5dfc5',   '223'],
            \ 'bg0':        ['#f3ead3',   '230'],
            \ 'bg1':        ['#eae4ca',   '228'],
            \ 'bg2':        ['#e5dfc5',   '223'],
            \ 'bg3':        ['#ddd8be',   '223'],
            \ 'bg4':        ['#d8d3ba',   '223'],
            \ 'bg5':        ['#b9c0ab',   '223'],
            \ 'bg_visual':  ['#e1e4bd',   '194'],
            \ 'bg_red':     ['#fadbd0',   '217'],
            \ 'bg_yellow':  ['#f1e4c5',   '226'],
            \ 'bg_green':   ['#e5e6c5',   '194'],
            \ 'bg_blue':    ['#e1e7dd',   '117'],
            \ 'bg_purple':  ['#f1ddd4',   '189'],
            \ }
    endif
  endif "}}}
  if &background ==# 'dark' "{{{
    let palette2 = {
          \ 'fg':         ['#e8e6dc',   'NONE'],
          \ 'red':        ['#cf6f63',   'NONE'],
          \ 'orange':     ['#d4806a',   'NONE'],
          \ 'yellow':     ['#dba53b',   'NONE'],
          \ 'green':      ['#a8bf9c',   'NONE'],
          \ 'aqua':       ['#8aa3ad',   'NONE'],
          \ 'blue':       ['#86a9c4',   'NONE'],
          \ 'purple':     ['#b09ac4',   'NONE'],
          \ 'grey0':      ['#979a94',   'NONE'],
          \ 'grey1':      ['#b9bbb3',   'NONE'],
          \ 'grey2':      ['#e8e6dc',   'NONE'],
          \ 'statusline1':['#a8bf9c',   'NONE'],
          \ 'statusline2':['#e8e6dc',   'NONE'],
          \ 'statusline3':['#cf6f63',   'NONE'],
          \ 'none':       ['NONE',      'NONE']
          \ } "}}}
  else "{{{
    let palette2 = {
          \ 'fg':         ['#5c6a72',   '242'],
          \ 'red':        ['#f85552',   '160'],
          \ 'orange':     ['#f57d26',   '116'],
          \ 'yellow':     ['#dfa000',   '136'],
          \ 'green':      ['#8da101',   '106'],
          \ 'aqua':       ['#35a77c',   '37'],
          \ 'blue':       ['#3a94c5',   '32'],
          \ 'purple':     ['#df69ba',   '162'],
          \ 'grey0':      ['#a6b0a0',   '247'],
          \ 'grey1':      ['#939f91',   '247'],
          \ 'grey2':      ['#829181',   '247'],
          \ 'statusline1':['#93b259',   '106'],
          \ 'statusline2':['#708089',   '242'],
          \ 'statusline3':['#e66868',   '160'],
          \ 'none':       ['NONE',      'NONE']
          \ }
  endif "}}}
  return extend(extend(palette1, palette2), a:colors_override)
endfunction "}}}
function! salvia#highlight(group, fg, bg, ...) "{{{
  execute 'highlight' a:group
        \ 'guifg=' . a:fg[0]
        \ 'guibg=' . a:bg[0]
        \ 'ctermfg=' . a:fg[1]
        \ 'ctermbg=' . a:bg[1]
        \ 'gui=' . (a:0 >= 1 ?
          \ a:1 :
          \ 'NONE')
        \ 'cterm=' . (a:0 >= 1 ?
          \ a:1 :
          \ 'NONE')
        \ 'guisp=' . (a:0 >= 2 ?
          \ a:2[0] :
          \ 'NONE')
endfunction "}}}
function! salvia#syn_gen(path, last_modified, msg) "{{{
  " Generate the `after/syntax` directory.
  let full_content = join(readfile(a:path), "\n") " Get the content of `colors/salvia.vim`
  let syn_conent = []
  let rootpath = salvia#syn_rootpath(a:path) " Get the path to place the `after/syntax` directory.
  call substitute(full_content, '" syn_begin.\{-}syn_end', '\=add(syn_conent, submatch(0))', 'g') " Search for 'syn_begin.\{-}syn_end' (non-greedy) and put all the search results into a list.
  for content in syn_conent
    let syn_list = []
    call substitute(matchstr(matchstr(content, 'syn_begin:.\{-}{{{'), ':.\{-}{{{'), '\(\w\|-\)\+', '\=add(syn_list, submatch(0))', 'g') " Get the file types. }}}}}}
    for syn in syn_list
      call salvia#syn_write(rootpath, syn, content) " Write the content.
    endfor
  endfor
  call salvia#syn_write(rootpath, 'text', "let g:salvia_last_modified = '" . a:last_modified . "'") " Write the last modified time to `after/syntax/text/salvia.vim`
  let syntax_relative_path = has('win32') ? '\after\syntax' : '/after/syntax'
  if a:msg ==# 'update'
    echohl WarningMsg | echom '[salvia] Updated ' . rootpath . syntax_relative_path | echohl None
    call salvia#ftplugin_detect(a:path)
  else
    echohl WarningMsg | echom '[salvia] Generated ' . rootpath . syntax_relative_path | echohl None
    execute 'set runtimepath+=' . fnameescape(fnamemodify(rootpath, ':p')) . 'after'
  endif
endfunction "}}}
function! salvia#syn_write(rootpath, syn, content) "{{{
  " Write the content.
  let syn_path = a:rootpath . '/after/syntax/' . a:syn . '/salvia.vim' " The path of a syntax file.
  " create a new file if it doesn't exist
  if !filereadable(syn_path)
    call mkdir(a:rootpath . '/after/syntax/' . a:syn, 'p')
    call writefile([
          \ "if !exists('g:colors_name') || g:colors_name !=# 'salvia'",
          \ '    finish',
          \ 'endif'
          \ ], syn_path, 'a') " Abort if the current color scheme is not salvia.
    call writefile([
          \ "if index(g:salvia_loaded_file_types, '" . a:syn . "') ==# -1",
          \ "    call add(g:salvia_loaded_file_types, '" . a:syn . "')",
          \ 'else',
          \ '    finish',
          \ 'endif'
          \ ], syn_path, 'a') " Abort if this file type has already been loaded.
  endif
  " If there is something like `call salvia#highlight()`, then add
  " code to initialize the palette and configuration.
  if matchstr(a:content, 'salvia#highlight') !=# ''
    call writefile([
          \ 'let s:configuration = salvia#get_configuration()',
          \ 'let s:palette = salvia#get_palette(s:configuration.background, s:configuration.colors_override)'
          \ ], syn_path, 'a')
  endif
  " Append the content.
  call writefile(split(a:content, "\n"), syn_path, 'a')
  " Add modeline.
  call writefile(['" vim: set sw=2 ts=2 sts=2 et tw=80 ft=vim fdm=marker fmr={{{,}}}:'], syn_path, 'a')
endfunction "}}}
function! salvia#syn_rootpath(path) "{{{
  let plugin_path = fnamemodify(a:path, ':p:h:h')
  " Get the directory where `after/syntax` is generated.
  if (matchstr(a:path, '^/usr/share') ==# '' && filewritable(plugin_path) == 2) " Return the plugin directory. The `after/syntax` directory should never be generated in `/usr/share`, even if you are a root user.
    return plugin_path
  else " Use vim home directory.
    if has('nvim')
      return stdpath('config')
    else
      return expand('~') . '/.vim'
    endif
  endif
endfunction "}}}
function! salvia#syn_newest(path, last_modified) "{{{
  " Determine whether the current syntax files are up to date by comparing the last modified time in `colors/salvia.vim` and `after/syntax/text/salvia.vim`.
  let rootpath = salvia#syn_rootpath(a:path)
  execute 'source ' . rootpath . '/after/syntax/text/salvia.vim'
  return a:last_modified ==# g:salvia_last_modified ? 1 : 0
endfunction "}}}
function! salvia#syn_clean(path, msg) "{{{
  " Clean the `after/syntax` directory.
  let rootpath = salvia#syn_rootpath(a:path)
  " Remove `after/syntax/**/salvia.vim`.
  let file_list = split(globpath(rootpath, 'after/syntax/**/salvia.vim'), "\n")
  for file in file_list
    call delete(file)
  endfor
  " Remove empty directories.
  let dir_list = split(globpath(rootpath, 'after/syntax/*'), "\n")
  for dir in dir_list
    if globpath(dir, '*') ==# ''
      call delete(dir, 'd')
    endif
  endfor
  if globpath(rootpath . '/after/syntax', '*') ==# ''
    call delete(rootpath . '/after/syntax', 'd')
  endif
  if globpath(rootpath . '/after', '*') ==# ''
    call delete(rootpath . '/after', 'd')
  endif
  if a:msg
    let syntax_relative_path = has('win32') ? '\after\syntax' : '/after/syntax'
    echohl WarningMsg | echom '[salvia] Cleaned ' . rootpath . syntax_relative_path | echohl None
  endif
endfunction "}}}
function! salvia#syn_exists(path) "{{{
  return filereadable(salvia#syn_rootpath(a:path) . '/after/syntax/text/salvia.vim')
endfunction "}}}
function! salvia#ftplugin_detect(path) "{{{
  " Check if /after/ftplugin exists.
  " This directory is generated in earlier versions, users may need to manually clean it.
  let rootpath = salvia#syn_rootpath(a:path)
  if filereadable(salvia#syn_rootpath(a:path) . '/after/ftplugin/text/salvia.vim')
    let ftplugin_relative_path = has('win32') ? '\after\ftplugin' : '/after/ftplugin'
    echohl WarningMsg | echom '[salvia] Detected ' . rootpath . ftplugin_relative_path | echohl None
    echohl WarningMsg | echom '[salvia] This directory is no longer used, you may need to manually delete it.' | echohl None
  endif
endfunction "}}}

" vim: set sw=2 ts=2 sts=2 et tw=80 ft=vim fdm=marker fmr={{{,}}}:
