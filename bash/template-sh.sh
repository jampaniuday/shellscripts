#!/usr/bin/env bash
#
# SCRIPT: template-sh.sh
# AUTHOR: Janos Gyerik <info@janosgyerik.com>
# DATE:   2005-08-11
#
# PLATFORM: Not platform dependent
#
# PURPOSE: Generate a Bash script template with a simple command line parser
#

usage() {
    test $# = 0 || echo "$@"
    echo "Usage: $0 [OPTION]... FILENAME"
    echo
    echo Generate a Bash script template with a simple argument parser
    echo
    echo Options:
    echo "  -a, --author AUTHOR     Name of the author, default = $author"
    echo "  -d, --description DESC  Description of the script, default = $description"
    echo "  -f, --flag FLAG         A parameter that takes no arguments"
    echo "  -p, --param PARAM       A parameter that takes one argument"
    echo
    echo "  -h, --help              Print this help"
    echo
    exit 1
}

set_longest() {
    len=${#1}
    test $len -gt $longest && longest=$len
}

set_padding() {
    len=${#1}
    padding=$(printf %$((width - len))s '')
}

if test "$AUTHOR"; then
    author=$AUTHOR
else
    username=$(id -un)
    author="$username <$username@$(hostname)>"
fi

ppattern='^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$'
is_valid_param() {
    [[ $1 =~ $ppattern ]]
}

longest=5
description='BRIEF DESCRIPTION OF THE SCRIPT'
# options starting with "f" are flags, "p" are parameters.
options=()
file=
flags=
params=
args=()
while test $# != 0; do
    case $1 in
    -h|--help) usage ;;
    -a|--author) shift; author=$1 ;;
    -d|--description) shift; description=$1 ;;
    -f|--flag)
        shift
        is_valid_param "$1" || usage "Invalid parameter name: '$1';\nparameter names should match the pattern: $ppattern"
        options+=("f$1")
        set_longest "$1"
        flags=1
        ;;
    -p|--param)
        shift
        is_valid_param "$1" || usage "Invalid parameter name: '$1'; parameter names should match the pattern: $ppattern"
        options+=("p$1")
        set_longest "$1"
        params=1
        ;;
    #--) shift; while test $# != 0; do args+=("$1"); shift; done; break ;;
    -|-?*) usage "Unknown option: $1" ;;
    #*) args+=("$1") ;;  # script that takes multiple arguments
    *) test "$file" && usage "Excess argument: $1" || file=$1 ;;
    esac
    shift
done

test "$file" || usage

#  -p, --param PARAM  A parameter that takes no arguments
#^^^^^^^^LLLLL^LLLLL^^
((width = 8 + longest + 3 + longest))
test $width -gt 40 && width=40

if test "$file" != "-"; then
    [[ "$file" == *.sh ]] || file=$file.sh
else
    file=/tmp/.template-sh.$$
    test=1
fi
echo "Creating '$file' ..."

trap 'rm -f "$file"; exit 1' 1 2 3 15

truncate() {
    > "$file"
}

append() {
    cat >> "$file"
}

truncate

cat << EOF | append
#!/usr/bin/env bash
#
# SCRIPT: $(basename "$file")
# AUTHOR: $author
# DATE:   $(date +%F)
#
# PLATFORM: Not platform dependent
# PLATFORM: Linux only
# PLATFORM: FreeBSD only
#
# PURPOSE: $description
#          Give a clear, and if necessary, long, description of the
#          purpose of the shell script. This will also help you stay
#          focused on the task at hand.
#

set -e

usage() {
    test \$# = 0 || echo "\$@"
    echo "Usage: \$0 [OPTION]... [ARG]..."
    echo
    echo $description
    echo
    echo Options:
EOF

for i in "${options[@]}"; do 
    f=${i:0:1}
    name=${i:1}
    vname=${name//-/_}
    oname=${name//_/-}
    first=${name:0:1}

    if test $f = f; then
        # this is a flag
        optionstring="  -$first, --$oname"
        echo Adding flag: $optionstring
        set_padding "$optionstring"
        echo "    echo \"$optionstring$padding default = \$$vname\"" | append
        optionstring="      --no-$oname"
        echo Adding flag: $optionstring
        set_padding "$optionstring"
        echo "    echo \"$optionstring$padding default = ! \$$vname\"" | append
    else
        # this is a param
        pname=$(tr a-z A-Z <<< "$oname")
        optionstring="  -$first, --$oname $pname"
        echo Adding param: $optionstring
        set_padding "$optionstring"
        echo "    echo \"$optionstring$padding default = \$$vname\"" | append
    fi
done

helpstring="  -h, --help"
set_padding "$helpstring"
cat << EOF | append
    echo
    echo "$helpstring$padding Print this help"
    echo
    exit 1
}

args=()
EOF

test "$flags" || echo '#flag=off' | append
test "$params" || echo '#param=' | append

for i in "${options[@]}"; do 
    f=${i:0:1}
    name=${i:1}
    vname=${name//-/_}
    oname=${name//_/-}
    test $f = f && echo "$vname=off" || echo "$vname="
done | append

cat << "EOF" | append
while test $# != 0; do
    case $1 in
    -h|--help) usage ;;
EOF

if ! test "$flags"; then
    # an example entry to illustrate parsing a flag
    echo "    #-f|--flag) flag=on ;;"
    echo "    #--no-flag) flag=off ;;"
fi | append

if ! test "$params"; then
    # an example entry to illustrate parsing a param
    echo "    #-p|--param) shift; param=\$1 ;;"
fi | append

for i in "${options[@]}"; do 
    f=${i:0:1}
    name=${i:1}
    vname=${name//-/_}
    oname=${name//_/-}
    first=${name:0:1}
    if test $f = f; then
        # this is a flag
        echo "    -$first|--$oname) $vname=on ;;"
        echo "    --no-$oname) $vname=off ;;"
    else
        # this is a param
        echo "    -$first|--$oname) shift; $vname=\$1 ;;"
    fi
done | append

cat << "EOF" | append
    #--) shift; while test $# != 0; do args+=("$1"); shift; done; break ;;
    -|-?*) usage "Unknown option: $1" ;;
    #*) args+=("$1") ;;  # script that takes multiple arguments
    esac
    shift
done

set -- "${args[@]}"  # save arguments in $@

test $# = 0 && usage
EOF

chmod +x "$file"
test "$test" && cat "$file"
