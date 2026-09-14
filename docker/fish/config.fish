set -g fish_greeting ""

function fish_prompt
    set_color brcyan
    echo -n "libasm"
    set_color normal
    echo -n " "
    set_color bryellow
    echo -n (basename (pwd))
    set_color normal
    echo -n " > "
end

alias ll "ls -lah --color=auto"
alias ls "ls --color=auto"

# assemble one file and show the symbols it exports
function nn --description "nasm one file to .o and list its symbols"
    nasm -f elf64 -g -F dwarf $argv[1] -o /tmp/(basename $argv[1] .s).o; or return 1
    nm /tmp/(basename $argv[1] .s).o
end

# disassemble a .o or .a member
function dis --description "objdump -d with intel syntax"
    objdump -d -M intel --no-show-raw-insn $argv
end

# valgrind with the strictness a 42 defense expects
function vg --description "valgrind, full strictness"
    valgrind --leak-check=full --show-leak-kinds=all \
             --track-origins=yes --track-fds=yes \
             --errors-for-leak-kinds=all --error-exitcode=42 $argv
end

function t --description "run the test suite"
    make -C /workspace/tests test
end

echo "libasm dev box — "(uname -m)"  |  nasm "(nasm -v | cut -d' ' -f3)"  gcc "(gcc -dumpversion)"  valgrind "(valgrind --version | cut -d- -f2)
echo "helpers: t (run tests) · vg CMD (valgrind) · nn file.s · dis file.o · check-env"
echo ""
