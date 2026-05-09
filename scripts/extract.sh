#!/bin/sh
find /d/steamapps/workshop/content/108600 -name mod.info -print0 2>/dev/null | while IFS= read -r -d '' f; do
  ws=$(echo "$f" | sed -n 's|.*/108600/\([0-9]*\)/.*|\1|p')
  mid=$(grep -E '^id=' "$f" 2>/dev/null | head -1 | sed 's/^id=//' | tr -d '\r ')
  if [ -n "$ws" ] && [ -n "$mid" ]; then
    echo "$ws|$mid|$f"
  fi
done > /out/pz-mods.txt
