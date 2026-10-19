#!/bin/zsh
# 把 repo/ 的站點檔案同步到 site/（發佈快照目錄）
#
# 為什麼要分兩個目錄：
#   repo/  是 git 倉庫，含 .git（內有提交者姓名與電郵）
#   site/  是純快照，只放要上傳的檔案
#   直接把 repo/ 丟給發佈工具，.git 會一起上傳，等於把姓名電郵公開。
#
# 用法：./sync-to-publish.sh

set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HERE/../site"

# 404.html 一定要帶：Pages 在沒有頂層 404.html 時會當作 SPA，任何不存在的路徑都回 200 首頁（soft 404）
# _worker.js 一定要帶：www → 根域的 301 靠它。Pages 的 _redirects 只匹配路徑，寫主機名不會生效
for f in index.html llms.txt robots.txt sitemap.xml 404.html _worker.js _headers CNAME .nojekyll; do
  if [ -f "$HERE/$f" ]; then
    cp "$HERE/$f" "$DEST/$f"
    echo "  synced  $f"
  else
    echo "  MISSING $f （跳過）"
  fi
done

echo ""
echo "site/ 現況："
ls -la "$DEST"
