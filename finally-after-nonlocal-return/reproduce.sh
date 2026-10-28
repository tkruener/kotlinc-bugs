#!/usr/bin/env bash
# Reproduces the inline-`finally` miscompile with official kotlinc releases.
# Usage: ./reproduce.sh [VERSION ...]      (default: 2.4.21)
# Downloads kotlin-compiler-<VERSION>.zip from github.com/JetBrains/kotlin/releases into ./.kotlinc/.
# Needs: bash, curl, unzip, a JDK (java on PATH).
set -uo pipefail
cd "$(dirname "$0")"
VERSIONS=("$@"); [ ${#VERSIONS[@]} -eq 0 ] && VERSIONS=(2.4.21)

fetch() { # version -> ./.kotlinc/<version>/kotlinc
  local v=$1 d=.kotlinc/$1
  [ -x "$d/kotlinc/bin/kotlinc" ] && return 0
  mkdir -p "$d"
  echo "downloading kotlinc $v ..." >&2
  curl -fsSL -o "$d/kotlinc.zip" "https://github.com/JetBrains/kotlin/releases/download/v$v/kotlin-compiler-$v.zip" || { echo "no release v$v" >&2; return 1; }
  if curl -fsSL -o "$d/kotlinc.zip.sha256" "https://github.com/JetBrains/kotlin/releases/download/v$v/kotlin-compiler-$v.zip.sha256" 2>/dev/null; then
    [ "$(cut -d' ' -f1 "$d/kotlinc.zip.sha256")" = "$(sha256sum "$d/kotlinc.zip" | cut -d' ' -f1)" ] || { echo "SHA-256 mismatch for $v" >&2; return 1; }
  fi
  unzip -q -o "$d/kotlinc.zip" -d "$d"
}

run_case() { # kotlinc-dir out-dir lib-flags app-file -> prints program output
  local k=$1 o=$2 lf=$3 app=$4 main
  main=$(basename "$app" .kt)Kt
  "$k/bin/kotlinc" lib/*.kt $lf -d "$o/lib.jar" 2>/dev/null || { echo "lib compile failed"; return; }
  "$k/bin/kotlinc" -cp "$o/lib.jar" "$app" -d "$o/app.jar" 2>/dev/null || { echo "app compile failed"; return; }
  java -cp "$o/lib.jar:$o/app.jar:$k/lib/kotlin-stdlib.jar" "$main" 2>&1 | tail -1
}

printf "%-12s %-17s %-24s %-24s %s\n" kotlinc case "two modules (default)" "lib -Xno-optimize" "one module"
for v in "${VERSIONS[@]}"; do
  fetch "$v" || continue
  k=.kotlinc/$v/kotlinc
  for app in app/Main.kt app/MainBreak.kt app/MainNull.kt; do
    o=out/$v/$(basename "$app" .kt); mkdir -p "$o/a" "$o/b" "$o/c"
    two=$(run_case "$k" "$o/a" "" "$app")
    noopt=$(run_case "$k" "$o/b" "-Xno-optimize" "$app")
    "$k/bin/kotlinc" lib/*.kt "$app" -d "$o/c/one.jar" 2>/dev/null
    one=$(java -cp "$o/c/one.jar:$k/lib/kotlin-stdlib.jar" "$(basename "$app" .kt)Kt" 2>&1 | tail -1)
    printf "%-12s %-17s %-24s %-24s %s\n" "$v" "$(basename "$app" .kt)" "$two" "$noopt" "$one"
  done
done
echo
echo "Expected in every column: begin abort"
