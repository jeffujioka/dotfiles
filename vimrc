" Showing Line Numbers:
" set number

" Enable Syntax Highlighting:
syntax on

" Setting Tab Size:
set tabstop=4

" Enabling Automatic Indentation:
set autoindent

" Replacing Tabs with White Spaces:
set expandtab

" Highlight the Current Line:
set cursorline

" Right Margin
set colorcolumn=72,75,100

highlight ColorColumn ctermbg=238

" https://stackoverflow.com/a/67890119
nnoremap Y "+y
vnoremap Y "+y
nnoremap yY ^"+y$

" https://vi.stackexchange.com/a/28284
if &term =~ "screen"
    let &t_BE = "\e[?2004h"
    let &t_BD = "\e[?2004l"
    exec "set t_PS=\e[200~"
    exec "set t_PE=\e[201~"
endif

" https://vi.stackexchange.com/a/18081
" esc in insert & visual mode
"nnoremap kj <esc>  " Remap in Normal mode
inoremap kj <esc>  " Remap in Insert and Replace mode
vnoremap kj <esc>  " Remap in Visual and Select mode
xnoremap kj <esc>  " Remap in Visual mode
snoremap kj <esc>  " Remap in Select mode
onoremap kj <esc>  " Remap in Operator pending mode
cnoremap kj <C-C>  " Remap in Command-line mode
" Note: In command mode mappings to esc run the command for some odd
" historical vi compatibility reason. We use the alternate method of
" existing which is Ctrl-C

nmap <C-s> :w<CR>
nmap <C-w> :q<CR>

"set timeoutlen=1000

