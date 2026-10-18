#!/bin/zsh
# 更換全站 GitHub 倉庫路徑
#
# 為什麼要有這支腳本：站上有 3 處「提交糾錯」按鈕、README / CONTRIBUTING
# 也會引用倉庫網址。手改一定會漏，漏一處就是一個死鏈。
#
# 用法：./tools/set-repo.sh <owner>/<repo>
#   例：./tools/set-repo.sh practicepointer/practicepointer
# 不帶參數時只做校驗，不改動任何檔案。

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."

OLD="practicepointer/practicepointer"
TARGET="${1:-}"

FILES=(index.html README.md CONTRIBUTING.md llms.txt DEPLOY.md)

echo "當前倉庫路徑：$OLD"
if [ -z "$TARGET" ]; then
  echo "（未提供參數，僅校驗不改動）"
else
  echo "目標倉庫路徑：$TARGET"
fi
echo ""

fail=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  # 只統計倉庫路徑形式的命中，避免把 github.com 首頁等其他連結算進來
  n=$(grep -o "$OLD" "$f" 2>/dev/null | wc -l | tr -d ' ')
  n=${n:-0}
  printf "  %-16s %s 處\n" "$f" "$n"
  if [ -n "$TARGET" ] && [ "$n" -gt 0 ]; then
    /usr/bin/sed -i '' "s|$OLD|$TARGET|g" "$f"
  fi
done

echo ""
# 檢查是否殘留「其他」GitHub 倉庫路徑（改域名式的漏改偵測）
others=$(grep -rhoE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "${FILES[@]}" 2>/dev/null \
         | sort -u | grep -v "^github.com/$TARGET$" || true)
if [ -n "$TARGET" ] && [ -n "$others" ]; then
  echo "⚠️  殘留其他倉庫路徑："
  echo "$others" | sed 's/^/     /'
  fail=1
elif [ -n "$TARGET" ]; then
  echo "✅ 全部統一為 github.com/$TARGET，無殘留"
fi

exit $fail
