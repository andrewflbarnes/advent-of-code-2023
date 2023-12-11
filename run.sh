#!/usr/bin/env bash
#!/usr/bin/env bash

template_file=template.zig
solution_file=soln.zig

run() {
    day=$1
    shift 1
    opts="$@"

    if [ -z "$day" ]
    then
        echo "Must provide day number" >&2
        return 1
    fi

    day="d$day"

    if ! [ -e "$day" ]
    then
        echo "Folder $day does not exist" >&2
        return 1
    fi

    local solution="$day/$solution_file"

    if ! [ -e "$solution" ]
    then
        echo "Solution file $solution does not exist" >&2
        return 2
    fi

    zig run "$solution" --main-pkg-path . $opts
}

run "$@"