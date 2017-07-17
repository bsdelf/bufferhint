# Buffer Hint

bufferhint is a handly buffer switcher for Vim.

With this plugin, you can browse all buffers in a popup side window.

In addition, this plugin provides a "hint key" for each buffer, just like what Vimperator/Vimium/VimFx does.

Therefore, you can switch among buffers quickly with a single key stroke in the best case.

## Installtion

### Manually

```bash
cp bufferhint.vim ~/.vim/plugin/
```

### Pathogen
```bash
cd ~/.vim/bundle
git clone https://github.com/bsdelf/bufferhint.git
```

### Configuration

Add following two lines in `~/.vimrc`:

```vim
nnoremap - :call bufferhint#Popup()
nnoremap \ :call bufferhint#LoadPrevious()
```

## Usage

### Basic usage

1. `vim foo.txt bar.txt doe.txt`.
2. Type `-` to popup bufferhint window.
3. Type `j`, `k`, `C-f`, `C-b`, `PGUP`, `PGDN` to navigate.
4. Type `ENTER` to load the buffer under cursor.

### Load buffer by hint

1. `vim foo.txt bar.txt doe.txt`.
2. Type `-` to popup bufferhint window.
3. Type `b` to load "bar.txt".
4. Type `\` to load the previous buffer namely "foo.txt".

### Switch sort mode

1. Type `-` to popup bufferhint window.
2. Type `SPACE` to switch sort mode.

### Delete buffers

1. `vim foo.txt bar.txt doe.txt`.
2. Type `-` to popup bufferhint window.
3. Type `dd` to delete the buffer under cursor.
4. Type `db` to delete a buffer by hint.

### Notes

- Yellow hints means the buffers are sorted by path, green hints means the buffers are sorted by LRU.
- You can also type `/` in bufferhint window and search what you want, then type `ENTER` to load it.
- Apparently `j/k/d/n/N` are excluded from the hint chars.

## Functions

- `bufferhint#Popup()`

    Toggle bufferhint window.

- `bufferhint#LoadPrevious()`

    Load the second item in LRU. It's very useful in the scene where you want to switch back and forth between two files.

- `bufferhint#Save()`

    Save current session to an external session file which can be restored by `vim -S` command in the future. The default session file name is "session.vim".
    
## Preference

- `g:bufferhint_SortMode`

    Default sort mode. 
    - 0: sort by path
    - 1: sort by LRU

- `g:bufferhint_MaxWidth`

    Maxmium window width.

- `g:bufferhint_PageStep`

    Page step, will affect `PGUP`, `PGDN`, `C-f`, `C-b`.

- `g:bufferhint_SessionFile`

    The default session file name.

- `g:bufferhint_KeepWindow`

    Set to `1` to keep window open after buffer deleting.
    
## Screenshot

![bufferhint](https://github.com/bsdelf/bufferhint/raw/master/screenshot_1.png)

## One More Thing

If you like this plugin, please rate it [here](http://www.vim.org/scripts/script.php?script_id=5272)!
