#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ids=(silas morwenna mortlake azgorath fennick vyrmathrax grub aldric snowqueen bramwell godmother thing)
layers=(base mouth-small mouth-medium mouth-wide eyes-closed)
failed=0

check_png() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing $path"
    failed=1
    return
  fi
  local size alpha
  size=$(sips -g pixelWidth -g pixelHeight "$path" 2>/dev/null | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w"x"h}')
  alpha=$(sips -g hasAlpha "$path" 2>/dev/null | awk '/hasAlpha/ {print $2}')
  if [[ "$size" != "1024x1024" ]]; then
    echo "bad size $path ($size)"
    failed=1
  fi
  if [[ "$alpha" != "yes" ]]; then
    echo "no alpha $path"
    failed=1
  fi
}

for id in "${ids[@]}"; do
  if [[ -f "Resources/Characters/$id/cartoon.png" ]]; then
    check_png "Resources/Characters/$id/cartoon.png"
    if [[ -f "Resources/Characters/$id/face.json" ]]; then
      python3 -m json.tool "Resources/Characters/$id/face.json" >/dev/null || {
        echo "bad json Resources/Characters/$id/face.json"
        failed=1
      }
    else
      echo "note: $id has cartoon.png but no face.json (fallback face layout)"
    fi
  else
    for name in "${layers[@]}"; do
      check_png "Resources/Characters/$id/$name.png"
    done
  fi
done

if (( failed )); then
  echo "art check failed"
  exit 1
fi
echo "art check passed: ${#ids[@]} characters"
