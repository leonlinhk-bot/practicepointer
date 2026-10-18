#!/bin/zsh
# 站內域名的一致性校驗與更換
#
# 為什麼要有這個腳本：
#   域名寫在四個地方 —— index.html（canonical + JSON-LD + OG）、
#   sitemap.xml、llms.txt、robots.txt。改域名時漏改任何一處，
#   canonical 與 sitemap 就會互相打架，對搜尋引擎與 AI 都是壞信號。
#
# 用法：
#   ./set-domain.sh              ← 只校驗，不改
#   ./set-domain.sh new.org      ← 把 practicepointer.org 全換成 new.org，然後校驗

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
FILES=("$ROOT/index.html" "$ROOT/sitemap.xml" "$ROOT/llms.txt" "$ROOT/robots.txt")

NEW="${1:-}"
OLD="practicepointer.org"

echo "=== 站內域名校驗 ==="
echo ""

if [ -n "$NEW" ]; then
  echo "把 $OLD 換成 $NEW …"
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue
    sed -i '' "s|$OLD|$NEW|g" "$f"
    echo "  已替換  $(basename "$f")"
  done
  echo ""
fi

TARGET="${NEW:-$OLD}"

fail=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "  ⚠️  缺少 $(basename "$f")"; fail=$((fail+1)); continue; }
  # 注意：grep -c 無命中時退出碼為 1，若加 `|| echo 0` 會得到 "0\n0"，後面的數值比較會炸
  n=$(grep -ic "$TARGET" "$f" 2>/dev/null || true)
  n="${n:-0}"
  others=$(grep -oE 'https://[a-zA-Z0-9.-]+\.(org|hk|com|io)(/|$|[^a-zA-Z0-9.-])' "$f" 2>/dev/null \
           | sed 's|https://||;s|[/$].*||' | sort -u | grep -v "^$TARGET$" | grep -v "github.com" \
           | grep -v "elegislation.gov.hk" | grep -v "ia.org.hk" | grep -v "sfc.hk" \
           | grep -v "mpfa.org.hk" | grep -v "pcpd.org.hk" | grep -v "workbuddy.host" \
           | grep -v "creativecommons.org" | grep -v "schema.org" | tr '\n' ' ')
  if [ "$n" -eq 0 ]; then
    echo "  ❌ $(basename "$f")：找不到 $TARGET"
    fail=$((fail+1))
  else
    printf "  ✅ %-12s 命中 %2d 處   自域:%s\n" "$(basename "$f")" "$n" "${others:-無}"
    [ -n "$others" ] && fail=$((fail+1))
  fi
done

echo ""
if [ "$fail" -eq 0 ]; then
  echo "一致 ✅ —— 四個檔案都指向 ${TARGET}，沒有殘留別的域名。"
else
  echo "有 $fail 處需要處理。"
  exit 1
fi
