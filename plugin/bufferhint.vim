"-------------------------------------------------------------------------------"
"   bufferhint 1.0, Copyright(c) 2015, Yanhui Shen <shen.elf@gmail.com>         "
"   * Inspired by Robert Lillack's BUFFER LIST                                  "
"   * Sort mode: Path & LRU                                                     "
"-------------------------------------------------------------------------------"

" SCRIPT RULE:
" row, col: start from 1
" index, idx: start from 0

""if exists('g:bufferhintLoaded')
""    finish
""endif
""let g:bufferhintLoaded = 1

" 0=path, 1=lru
if !exists("g:bufferhint_SortMode")
    let g:bufferhint_SortMode = 0
endif

if !exists('g:bufferhint_MaxWidth')
    let g:bufferhint_MaxWidth = 50
endif

if !exists('g:bufferhint_PageStep')
    let g:bufferhint_PageStep = 5
endif

if !exists('g:bufferhint_SessionFile')
    let g:bufferhint_SessionFile = 'session.vim'
endif

" if window height changed,
" we need to regenerate hits
let s:Width = 0
let s:Height = 0

" shortcut keys
let s:HintKeys = {}

" buffer ids for differet mode
let s:PathBids = []
let s:LRUBids = []

" buffer count
let s:LineCount = 0

" za__[path]_@~_
let s:ReservedSpace = 2+2+1+2+1

" current line
let s:CursorLine = line(".")

" buffer's name
let s:MyName = fnameescape("[buffers]")

" toggle buffer hint
fu! bufferhint#Popup()
    if bufloaded(bufnr(s:MyName))
        exe 'bwipeout ' . bufnr(s:MyName)
        return
    endif

    if g:bufferhint_MaxWidth > winwidth(0) || g:bufferhint_MaxWidth <= 0
        let g:bufferhint_MaxWidth = winwidth(0)
    endif

    if empty(s:HintKeys) || s:Height != winheight(0)
        call s:GenHintKeys()
        let s:Height = winheight(0)
    endif

    call s:UpdateLRU()

    " FIXME: 
    " SetupWidth() is implicitly called inside GetContent()
    " this is not good
    let bufcontent = s:GetContent()
    if empty(bufcontent)
        return
    endif
    
    " create buffer
    exe 'silent! ' . s:Width . 'vne ' . s:MyName

    setlocal noshowcmd
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal nowrap
    setlocal nonumber

    " syntax highlighting
    if has("syntax")
        sy clear
        sy match KeyHint /^../
        sy match AtHint /@/
        hi clear
        hi def AtHint ctermfg=red
        let mode = g:bufferhint_SortMode
        if mode == 0
            hi def KeyHint ctermfg=yellow
        elseif mode == 1
            hi def KeyHint ctermfg=green
        endif
    endif

    " set content
    setlocal modifiable
    put! = bufcontent
    setlocal nomodifiable

    " map keys for explorer
    map <silent> <buffer> q :bwipeout<CR> 
    map <silent> <buffer> <space> :call bufferhint#SwitchMode()<CR>

    " map keys for buffer
    call s:MapHintKeys()
    noremap <silent> <buffer> <CR> :call bufferhint#LoadByCursor()<CR>
    map <silent> <buffer> dd :call bufferhint#KillByCursor()<CR>

    " map keys for movement
    map <silent> <buffer> j :call bufferhint#Scroll("down")<CR>
    map <silent> <buffer> k :call bufferhint#Scroll("up")<CR>
    map <silent> <buffer> gg :call bufferhint#Scroll("top")<CR>
    map <silent> <buffer> G :call bufferhint#Scroll("bottom")<CR>
    map <silent> <buffer> <PageUp> :call bufferhint#Scroll("pgup")<CR>
    map <silent> <buffer> <PageDown> :call bufferhint#Scroll("pgdn")<CR>
    map <silent> <buffer> <C-b> :call bufferhint#Scroll("pgup")<CR>
    map <silent> <buffer> <C-f> :call bufferhint#Scroll("pgdn")<CR>
    map <silent> <buffer> <Down> j
    map <silent> <buffer> <Up> k
    map <silent> <buffer> <Home> gg
    map <silent> <buffer> <End> G

    map <buffer> <Left> <Nop>
    map <buffer> <Right> <Nop>
    map <buffer> I <Nop>
    map <buffer> A <Nop>
    map <buffer> O <Nop>

    " NOTE: These hooks should be work only for this buffer!!!
    autocmd! VimResized <buffer> call s:OnResized()
    autocmd! CursorMoved <buffer> call s:OnCursorMoved()

    call s:ModeReady()
endfu

fu! s:OnResized()
    bwipeout
    call bufferhint#Popup()
    call s:DrawHints()
endfu

fu! s:OnCursorMoved()
    call s:DrawHints()
    if g:bufferhint_SortMode == 0
        let s:CursorLine = line(".")
    endif
endfu

fu! bufferhint#SwitchMode()
    let mode = g:bufferhint_SortMode
    let mode = (mode + 1) % 2
    let g:bufferhint_SortMode = mode
    bwipeout
    call bufferhint#Popup()
endfu

fu! s:ModeReady()
    let mode = g:bufferhint_SortMode
    if mode == 0
        call s:Goto(s:CursorLine)
    elseif mode == 1
        call bufferhint#Scroll("top")
    endif
endfu

fu! s:GetModeBids()
    let mode = g:bufferhint_SortMode
    if mode == 0
        return s:PathBids
    elseif mode == 1
        return s:LRUBids
    else
        return []
    endif
endfu

fu! s:GetContent()
    let mode = g:bufferhint_SortMode
    if mode == 0
        return s:SortedByPath()
    elseif mode == 1
        return s:SortedByLRU()
    else
        let mode = 0
        return s:SortedByPath()
    endif
endfu

fu! s:GenHintKeys()
    let hint1 = "abcefhilmoprstuvwxyz"
    let hint2 = "abcdefghijklmnopqrstuvwxyz"

    let nhint1 = (strlen(hint1)*strlen(hint2) - winheight(0)) / (strlen(hint2)-1)
    let nhint2 = strlen(hint2)
    let ihint1 = nhint1
    let ihint2 = 0
    let hintkeys = {}

    for idx in range(0, winheight(0)-1)
        " build hint key and map it
        if idx < nhint1
            let hint = hint1[idx]
        else
            let hint = hint1[ihint1] . hint2[ihint2]
            let ihint2 = ihint2 + 1
            if ihint2 >= nhint2
                let ihint2 = 0
                let ihint1 = ihint1 + 1
            endif
        endif
        let hintkeys[hint] = idx
    endfor

    let s:HintKeys = hintkeys
endfu

fu! s:MapHintKeys()
    let hintkeys = s:HintKeys
    if empty(hintkeys)
        echo "Need HintKeys!"
        return
    endif
    setlocal modifiable
    for hint in keys(hintkeys)
        exe 'map <silent> <buffer> ' . hint . ' :call bufferhint#LoadByHint("' . hint . '")<CR>'
        exe 'map <silent> <buffer> d' . hint . ' :call bufferhint#KillByHint("' . hint . '")<CR>'
    endfor
    setlocal nomodifiable
endfu

fu! s:DrawHints()
    let hintkeys = s:HintKeys
    if empty(hintkeys)
        echo "Need HintKeys!"
        return
    endif
    setlocal modifiable
    for hint in keys(hintkeys)
        let row = line("w0") + hintkeys[hint]
        if row > s:LineCount
            continue
        endif
        if strlen(hint) < 2
            let hint = hint . " "
        endif
        let str = hint . strpart(getline(row), 2)
        call setline(row, str)
    endfor
    setlocal nomodifiable
endfu

fu! s:FormatPath(bid, path)
    let bid = a:bid
    let path = a:path
    let maxw = s:Width

    if strlen(path) <= 0
        \|| !getbufvar(bid, '&modifiable')
        \|| !getbufvar(bid, '&buflisted')
        return ""
    endif

    " adapt the length of path
    let len = strlen(path) + s:ReservedSpace
    if len > maxw
        let path = '...' . strpart(path, len - maxw + 3)
    "elseif len < maxw
    "    if (bufwinnr(bid) == -1)
    "        let path = path . repeat(' ', maxw - len)
    "    endif
    endif

    let path = path . ' '
    " buffer stats hint
    if bufwinnr(bid) != -1
        let path = path . '@'
    endif
    if getbufvar(bid, '&modified')
        let path = path . '~'
    endif

    return path
endfu

fu! s:SortedByPath()
    let crntbuf = bufnr('')
    let lastbuf = bufnr('$')

    let content = ""
    let pathbids = []

    " build path-bid map
    let pathidmap = {}
    let maxpath = 0
    for bid in range(1, lastbuf)
        if !buflisted(bid) | continue | endif
        let path = s:RelativeFilePath(bufname(bid))
        let pathidmap[path] = bid
        let len = strlen(path)
        if (len > maxpath)
            let maxpath = len
        endif
    endfor
    if empty(pathidmap)
        return
    endif

    call s:SetupWidth(maxpath)
    
    " iterate through the buffers
    let nline = 0
    for key in sort(keys(pathidmap))
        let bid = pathidmap[key]
        let path = key

        let line = s:FormatPath(bid, path)
        if empty(line) | continue | endif

        " remember buffer numbers
        call add(pathbids, bid)

        " add newline, reserve 4 spaces for hint key
        let content = content . "    " . line . "\n"
        let nline = nline + 1
    endfor

    let s:PathBids = pathbids
    let s:LineCount = nline

    return content
endfu

fu! s:SortedByLRU()
    let lrulst = s:LRUBids
    let content = ""

    let idpathmap = {}
    let maxpath = 0
    for bid in lrulst
        if !buflisted(bid) | continue | endif
        let path = s:RelativeFilePath(bufname(bid))
        let idpathmap[bid] = path
        let len = strlen(path)
        if (len > maxpath)
            let maxpath = len
        endif
    endfor
    if empty(idpathmap)
        return
    endif

    call s:SetupWidth(maxpath)

    " iterate through buffers
    let nline = 0
    for bid in lrulst
        let path = idpathmap[bid]

        let line = s:FormatPath(bid, path)
        if empty(line) | continue | endif

        " add newline, reserve 4 spaces for hint key
        let content = content . "    " . line . "\n"
        let nline = nline + 1
    endfor

    let s:LineCount = nline

    return content
endfu

fu! s:UpdateLRU()
    let lrulst = s:LRUBids
    let lastbuf = bufnr('$')
    " initialize
    if empty(lrulst)
        for bid in range(1, lastbuf)
            " this may happen
            if buflisted(bid)
                call add(lrulst, bid)
            endif
        endfor
        " simply sort by path will obey LRU
        "fu! s:bufcmp(bida, bidb)
        "    let stra = bufname(a:bida)
        "    let strb = bufname(a:bidb)
        "    return stra < strb ? -1 : (stra > strb ? 1 : 0)
        "endfu
        "call sort(lrulst, "s:bufcmp")
    endif
    " track new buffers
    for bid in range(1, lastbuf)
        if buflisted(bid) && index(lrulst, bid) < 0
            call insert(lrulst, bid, 0)
        endif
    endfor
endfu

fu! s:SetupWidth(pathlen)
    " decide max window width
    let width = a:pathlen + s:ReservedSpace
    if width > g:bufferhint_MaxWidth
        let width = g:bufferhint_MaxWidth
    endif
    let s:Width = width
endfu

fu! bufferhint#Scroll(where)
    let pagestep = g:bufferhint_PageStep
    if a:where == "up"
        call s:Goto(line(".")-1)
    elseif a:where == "down"
        call s:Goto(line(".")+1)
    elseif a:where == "pgup"
        call s:Goto(line(".")-pagestep)
    elseif a:where == "pgdn"
        call s:Goto(line(".")+pagestep)
    elseif a:where == "top"
        call s:Goto(1)
    elseif a:where == "bottom"
        call s:Goto(s:LineCount)
    endif
endfu

fu! s:Goto(line)
    let nline = s:LineCount
    if nline < 1 | return | endif

    let xoff = 4
    setlocal modifiable
    if a:line < 1
        call cursor(1, xoff)
    elseif a:line > nline
        call cursor(nline, xoff)
    else
        call cursor(a:line, xoff)
    endif
    setlocal nomodifiable
endfu

"--------------------------------------------

fu! bufferhint#LoadByHint(hint)
    let hintkeys = s:HintKeys
    if !has_key(hintkeys, a:hint)
        echo "No such key: " . a:hint
        return
    endif
    let idx = line("w0") + hintkeys[a:hint] - 1
    call s:LoadByIndex(idx)
endfu

fu! bufferhint#LoadByCursor()
    let idx = line(".") - 1
    call s:LoadByIndex(idx)
endfu

fu bufferhint#LoadPrevious()
    let curmode = g:bufferhint_SortMode
    let g:bufferhint_SortMode = 1
    call s:UpdateLRU()
    call s:LoadByIndex(1)
    let g:bufferhint_SortMode = curmode
endfu

fu! s:LoadByIndex(idx)
    let bids = s:GetModeBids()
    if a:idx >= len(bids) || a:idx < 0
        echo "Out of range!"
        return
    endif
    let bid = bids[a:idx]

    " update LRU
    let lruidx = index(s:LRUBids, bid)
    call remove(s:LRUBids, lruidx)
    call insert(s:LRUBids, bid, 0)

    " load buffer
    if bufexists(bufnr(s:MyName))
        exe 'bwipeout ' . bufnr(s:MyName)
    endif
    exe "b " . bid
endfu

"--------------------------------------------

fu! bufferhint#KillByHint(hint)
    let hintkeys = s:HintKeys
    if !has_key(hintkeys, a:hint)
        echo "No such key: " . a:hint
        return
    endif
    let idx = line("w0") + hintkeys[a:hint] - 1
    call s:KillByIndex(idx)
endfu

fu! bufferhint#KillByCursor()
    let idx = line(".") - 1
    call s:KillByIndex(idx)
endfu

fu! s:KillByIndex(idx)
    let bids = s:GetModeBids()
    if a:idx >= len(bids) || a:idx < 0
        echo "Out of range!"
        return
    endif
    let bid = bids[a:idx]

    bwipeout

    " kill buffer
    exe "silent bdelete " . bid
    call remove(bids, a:idx)

    " update LRU
    let lruidx = index(s:LRUBids, bid)
    call remove(s:LRUBids, lruidx)

    call bufferhint#Popup()
endfu

"--------------------------------------------

fu! bufferhint#Save()
    let name = g:bufferhint_SessionFile
    let path = fnamemodify(getcwd(), ":p")
    call s:DoSaveAs(name, path)
endfu

fu! bufferhint#SaveAs()
    let name = input("Name: ")
    if empty(name)
        echo "\r"
        echo "Abort to save."
        return
    endif
    let path = input("Path: ")
    let path = fnamemodify(expand(path), ":p")
    echo "\r"
    call s:DoSaveAs(name, path)
endfu

fu! s:DoSaveAs(name, path)
    let ss = a:path . a:name

    let dir = getcwd()
    let files = s:GetLRUFiles()
    let current = bufname(bufnr(""))

    let content = []
    call add(content, "chdir " . dir)
    call add(content, "args " . files)
    call add(content, "edit " . current)

    call writefile(content, ss)
    echo "Saved: " . ss
endfu

fu! s:GetLRUFiles()
    let files = ""
    let bids = s:LRUBids
    if empty(bids)
        let crntbuf = bufnr('')
        let lastbuf = bufnr('$')
        let bids = range(1, lastbuf)
    endif

    for bid in bids
        if !buflisted(bid) | continue | endif
        let path = bufname(bid)
        let files .= path . " " 
    endfor

    return l:files
endfu

"--------------------------------------------

fu! s:RelativeFilePath(bname)
    if !filereadable(a:bname)
        return "#" . a:bname . "#"
    endif
    let fullpath = fnamemodify(a:bname, ":p") 
    let workpath = fnamemodify(getcwd(), ":p") 
    let relpath = strpart(fullpath, strlen(matchstr(fullpath, workpath, 0)))
    return relpath
endfu

