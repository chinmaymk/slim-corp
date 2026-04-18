#!/bin/sh
# Slim-Corp skill installer
# Detects slim-corp* skill directories and links (or copies) them to ~/.claude/skills/

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
TARGET_DIR="${HOME}/.claude/skills"
MODE="symlink"
FORCE=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --copy)  MODE="copy" ;;
    --force) FORCE=true ;;
    --help|-h)
      echo "Usage: ./install.sh [--copy] [--force]"
      echo ""
      echo "  --copy   Copy skills instead of symlinking"
      echo "  --force  Replace all existing skills without prompting"
      echo ""
      exit 0
      ;;
  esac
done

if [ ! -d "$SKILLS_SRC" ]; then
  echo "Error: skills/ directory not found in $REPO_DIR"
  exit 1
fi

# Create target if needed
mkdir -p "$TARGET_DIR"

installed=0
skipped=0
summary=""

for skill_dir in "$SKILLS_SRC"/slim-corp*; do
  [ -d "$skill_dir" ] || continue
  skill_name="$(basename "$skill_dir")"
  dest="$TARGET_DIR/$skill_name"

  # Check if already exists
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$FORCE" = true ]; then
      rm -rf "$dest"
    else
      printf "  %s already exists at %s. Overwrite? [y/N] " "$skill_name" "$dest"
      read -r answer
      case "$answer" in
        [yY]|[yY][eE][sS])
          rm -rf "$dest"
          ;;
        *)
          skipped=$((skipped + 1))
          continue
          ;;
      esac
    fi
  fi

  if [ "$MODE" = "copy" ]; then
    cp -R "$skill_dir" "$dest"
    summary="${summary}\n  [copied]  $skill_name -> $dest"
  else
    ln -s "$skill_dir" "$dest"
    summary="${summary}\n  [linked]  $skill_name -> $dest"
  fi
  installed=$((installed + 1))
done

echo ""
echo "=== Slim-Corp Install Summary ==="
if [ $installed -gt 0 ]; then
  printf "%b\n" "$summary"
fi
echo ""
echo "  Installed: $installed skill(s)"
if [ $skipped -gt 0 ]; then
  echo "  Skipped:   $skipped skill(s)"
fi
echo ""
echo "=== Next Steps ==="
echo "  Run /slim-corp init \"My Project\" to get started"
echo ""
