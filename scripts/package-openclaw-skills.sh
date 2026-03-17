#!/usr/bin/env bash
#
# package-openclaw-skills.sh — 将当前仓库中的 Skill 目录打包为 OpenClaw Skills zip
#
# 输出结构：
#   <bundle-root>/
#     skills/
#       <skill-slug>/
#         SKILL.md
#         ...
#
# 用法：
#   bash scripts/package-openclaw-skills.sh
#   bash scripts/package-openclaw-skills.sh --out dist
#   bash scripts/package-openclaw-skills.sh --name openclaw-skills.zip
#
# 说明：
# - 直接读取当前仓库里的 */SKILL.md 目录
# - 保留每个 Skill 目录下的现有文件结构
# - 默认生成适合解压到 OpenClaw workspace 根目录的 zip 包

set -euo pipefail

if [[ -t 1 ]]; then
  GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BOLD=''; RESET=''
fi

info()   { printf "${GREEN}[OK]${RESET}  %s\n" "$*"; }
warn()   { printf "${YELLOW}[!!]${RESET}  %s\n" "$*"; }
error()  { printf "${RED}[ERR]${RESET} %s\n" "$*" >&2; }
header() { printf "\n${BOLD}%s${RESET}\n" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAMP="$(date +%Y%m%d)"

OUT_DIR="$REPO_ROOT/dist"
BUNDLE_ROOT_NAME="openclaw-skills"
ZIP_NAME="${BUNDLE_ROOT_NAME}-${STAMP}.zip"
SEEN_FILE=""
CUSTOM_ZIP_NAME=0

SKILL_DIRS=(
  academic
  design
  engineering
  examples
  finance
  game-development
  hr
  legal
  marketing
  paid-media
  product
  project-management
  sales
  spatial-computing
  specialized
  supply-chain
  support
  testing
)

usage() {
  sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

cleanup() {
  if [[ -n "${SEEN_FILE:-}" && -f "${SEEN_FILE:-}" ]]; then
    rm -f "$SEEN_FILE"
  fi
}

copy_skill_dir() {
  local src_dir="$1" dest_dir="$2"
  mkdir -p "$dest_dir"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude '.DS_Store' \
      --exclude '.gitkeep' \
      "$src_dir/" "$dest_dir/"
    return 0
  fi

  cp -R "$src_dir/." "$dest_dir/"
  find "$dest_dir" -name '.DS_Store' -delete
}

create_zip() {
  local bundle_root="$1" zip_path="$2"

  rm -f "$zip_path"

  if command -v zip >/dev/null 2>&1; then
    (
      cd "$(dirname "$bundle_root")"
      zip -qr "$zip_path" "$(basename "$bundle_root")"
    )
    return 0
  fi

  if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --sequesterRsrc --keepParent "$bundle_root" "$zip_path"
    return 0
  fi

  error "未找到 zip 或 ditto，无法生成 zip 包。"
  exit 1
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out)
        OUT_DIR="${2:?'--out 需要一个值'}"
        shift 2
        ;;
      --name)
        ZIP_NAME="${2:?'--name 需要一个值'}"
        CUSTOM_ZIP_NAME=1
        shift 2
        ;;
      --root-name)
        BUNDLE_ROOT_NAME="${2:?'--root-name 需要一个值'}"
        shift 2
        ;;
      --help|-h)
        usage
        ;;
      *)
        error "未知选项: $1"
        usage
        ;;
    esac
  done

  if [[ "$CUSTOM_ZIP_NAME" -eq 0 ]]; then
    ZIP_NAME="${BUNDLE_ROOT_NAME}-${STAMP}.zip"
  fi

  local bundle_root="$OUT_DIR/$BUNDLE_ROOT_NAME"
  local skills_root="$bundle_root/skills"
  local zip_path="$OUT_DIR/$ZIP_NAME"
  local count=0

  SEEN_FILE="$(mktemp)"
  trap cleanup EXIT

  header "打包 OpenClaw Skills"
  echo "  仓库:   $REPO_ROOT"
  echo "  输出:   $OUT_DIR"
  echo "  根目录: $bundle_root"
  echo "  zip:    $zip_path"

  mkdir -p "$OUT_DIR"
  rm -rf "$bundle_root"
  mkdir -p "$skills_root"

  local dir
  for dir in "${SKILL_DIRS[@]}"; do
    [[ -d "$REPO_ROOT/$dir" ]] || continue

    while IFS= read -r -d '' skill_file; do
      local src_dir slug existing
      src_dir="$(dirname "$skill_file")"
      slug="$(basename "$src_dir")"

      existing="$(awk -F '\t' -v slug="$slug" '$1 == slug { print $2; exit }' "$SEEN_FILE")"
      if [[ -n "$existing" ]]; then
        error "发现重复 Skill slug: $slug"
        error "冲突目录: $existing 与 $src_dir"
        exit 1
      fi

      printf '%s\t%s\n' "$slug" "$src_dir" >> "$SEEN_FILE"
      copy_skill_dir "$src_dir" "$skills_root/$slug"
      (( count++ )) || true
    done < <(find "$REPO_ROOT/$dir" -type f -name SKILL.md -print0 | sort -z)
  done

  if [[ "$count" -eq 0 ]]; then
    error "没有找到可打包的 SKILL.md。"
    exit 1
  fi

  create_zip "$bundle_root" "$zip_path"

  info "已打包 $count 个 Skill"
  info "zip 包已写入: $zip_path"
}

main "$@"
