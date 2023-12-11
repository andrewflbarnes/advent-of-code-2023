#!/usr/bin/env bash

template_file=template.zig
solution_file=soln.zig

setup() {
    day=$1

    if [ -z "$day" ]
    then
        echo "Must provide day number" >&2
        return 1
    fi

    day="d$day"

    if [ -e "$day" ]
    then
        echo "Folder $day already exists" >&2
    elif ! mkdir "$day"
    then
        echo "Failed to create folder $day" >&2
        return 2
    fi

    local template="$template_file"

    if ! [ -e "$template" ]
    then
        echo "Template file $template does not exist" >&2
        return 3
    fi

    local solution="$day/$solution_file"

    if [ -e "$solution" ]
    then
        echo "Solution file $solution already exists" >&2
    elif ! sed "s/DAY/$day/g" "$template" > "$solution"
    then
        echo "Failed to copy template file $template to $solution" >&2
        return 4
    fi

    touch "$day"/{test1,input}

    echo "Created $day:"
    ls "$day"
}

setup "$@"
