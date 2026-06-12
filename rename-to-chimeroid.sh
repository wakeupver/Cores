#!/usr/bin/env bash
# Run from the root of wakeupver/Cores checkout
set -e

CORES=(
  citra desmume dosbox_pure fbneo fceumm gambatte genesis_plus_gx handy
  mame2003_plus mednafen_ngp mednafen_pce_fast mednafen_wswan melonds mgba
  mupen64plus_next_gles3 pcsx_rearmed ppsspp prosystem snes9x stella
)

MV="mv"
if [ -d ".git" ]; then
  MV="git mv"
fi

for c in "${CORES[@]}"; do
  old="lemuroid_core_${c}"
  new="chimeroid_core_${c}"
  if [ -d "$old" ]; then
    $MV "$old" "$new"
    echo "renamed: $old -> $new"
  else
    echo "skip (not found): $old"
  fi
done

for c in "${CORES[@]}"; do
  f="chimeroid_core_${c}/build.gradle.kts"
  if [ -f "$f" ]; then
    sed -i \
      -e 's/com\.swordfish\.lemuroid/com.swordfish.chimeroid/g' \
      -e 's/:lemuroid-app/:chimeroid-app/g' \
      "$f"
  fi
done

echo ""
echo "Done. 20 modules renamed, namespace + project(:chimeroid-app) updated."
echo ""
echo "Verify:"
echo "  grep -rn lemuroid . --include=*.kts   (should be empty)"
