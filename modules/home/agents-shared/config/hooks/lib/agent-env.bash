_vtb_tz() {
  local tz
  tz=$(command git config --get vtb.tz 2>/dev/null)
  if [ -n "$tz" ]; then export TZ="$tz"; else unset TZ; fi
}

cd() { builtin cd "$@" && _vtb_tz; }

rm() { command gtrash put "$@"; }

_vtb_tz
