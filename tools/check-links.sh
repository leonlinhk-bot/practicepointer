#!/bin/zsh
# 條文與監管機構外鏈校驗
#
# 為什麼要有這個腳本：
#   合規站最怕死鏈 —— 連結失效等於把人引到空白頁，
#   比沒給連結更糟。建議每季跑一次。
#
# 用法：./tools/check-links.sh
# 只列非 200 的結果；全綠時輸出一行 OK。

HERE="$(cd "$(dirname "$0")" && pwd)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

URLS=$(grep -o 'href="https://[^"]*"' "$HERE/../index.html" | sed 's/href="//;s/"$//' | sort -u)

echo "檢查 $(echo "$URLS" | wc -l | tr -d ' ') 條外鏈…"
echo ""

fail=0
while read -r u; do
  [ -z "$u" ] && continue
  code=$(curl -s -o /dev/null -L -w "%{http_code}" -A "$UA" --max-time 25 "$u")
  case "$code" in
    200) printf "  ✅ %s  %s\n" "$code" "$u" ;;
    403) printf "  ⚠️  %s  %s   ← 可能是反爬，請用瀏覽器再確認一次\n" "$code" "$u"; fail=$((fail+1)) ;;
    *)   printf "  ❌ %s  %s\n" "$code" "$u"; fail=$((fail+1)) ;;
  esac
  sleep 0.3
done <<< "$URLS"

echo ""
if [ "$fail" -eq 0 ]; then
  echo "全部 200。"
else
  echo "有 $fail 條需要人工確認。"
fi
