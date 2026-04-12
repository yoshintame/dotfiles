#!/usr/bin/env bash
# Extract archives via ouch into a uniquely-named directory per archive.
#
# For each archive passed as argument:
#   1. Compute target dir name from archive basename (strips .tar.* compounds).
#   2. If target exists, append -1, -2, ... until a free name is found.
#   3. Run `ouch decompress --yes --dir <target> <archive>`.
#
# This avoids collisions when an archive's top-level dir already exists in cwd.

set -uo pipefail

for archive in "$@"; do
    if [[ ! -f "$archive" ]]; then
        echo "extract.sh: not a file: $archive" >&2
        continue
    fi

    dir=$(dirname -- "$archive")
    base=$(basename -- "$archive")

    if [[ "$base" =~ \.tar\.(gz|xz|zst|bz2|lz4|br|lzma|lz|Z)$ ]]; then
        name="${base%.tar.*}"
    else
        name="${base%.*}"
    fi

    target="$dir/$name"
    i=1
    while [[ -e "$target" ]]; do
        target="$dir/$name-$i"
        ((i++))
    done

    if ! ouch decompress --yes --dir "$target" -- "$archive"; then
        rmdir "$target" 2>/dev/null || true
        exit_code=1
    fi
done

exit "${exit_code:-0}"
