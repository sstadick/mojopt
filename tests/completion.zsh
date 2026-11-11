# Complete the installed options example in a real interactive zsh.
emulate -R zsh
setopt errexit
zmodload zsh/zpty
binary=${1:A}
shell=${2:A}
record=$(mktemp)
trap 'zpty -d cli 2>/dev/null; rm -f "$record"' EXIT
zpty -b cli "$shell" -f
zpty -w cli "module_path=(${(j: :)${(@q)module_path}}); fpath=(${(j: :)${(@q)fpath}})"
zpty -w cli "autoload -Uz compinit; compinit -i -D; compdef _gnu_generic ${(q)binary}"
zpty -w cli "record=${(q)record}"
zpty -w cli '_record() { print -r -- "$BUFFER" >> "$record"; BUFFER=; zle redisplay; }'
zpty -w cli "zle -N _record; bindkey '^X' _record"

integer count=0
for prefix expected in \
    --na --name= \
    --cou --count= \
    --for --format= \
    --inc --include= \
    --ver '--verbose ' \
    --he '--help ' \
    -n '-n ' \
    -c '-c ' \
    -f '-f ' \
    -I '-I ' \
    -v '-v ' \
    --inp --inp
do
    (( ++count ))
    zpty -w -n cli "$binary $prefix"$'\t\030'
    local -a lines
    for attempt in {1..500}; do
        while zpty -r cli chunk; do :; done
        lines=("${(@f)$(<"$record")}")
        [[ -s $record ]] && (( $#lines >= count )) && break
        sleep 0.01
    done
    if [[ ${lines[count]} != "$binary $expected" ]]; then
        print -u2 -r -- "completion of $prefix: expected '$binary $expected', got '${lines[count]}'"
        exit 1
    fi
done
print 'PASS GNU completion'
