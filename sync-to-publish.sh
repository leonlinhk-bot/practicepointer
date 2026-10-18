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

for f in index.html llms.txt robots.txt sitemap.xml; do
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
