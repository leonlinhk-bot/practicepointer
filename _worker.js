// www.practicepointer.org → practicepointer.org 的 301
//
// 為什麼寫在這裡：Cloudflare Pages 的 `_redirects` 只匹配**路徑**，
// 來源寫成 `https://www.example.org/*` 這種主機名形式不會生效（等同註解）。
// 主機層轉址有兩個正規做法：
//   1) zone 層 Redirect Rule（在到達 Pages 之前執行）—— 需要 Zone → Config → Edit
//   2) Pages 的 `_worker.js`（本檔案）—— 只需要 Pages 的部署權限
// 本專案走 (2)，因為手上沒有 zone 寫入權限。日後若加了 Redirect Rule，
// 這支 worker 可以直接刪掉，行為不變。
//
// 保留路徑與 query string：改寫 hostname 後整條 URL 一起轉。

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.hostname === "www.practicepointer.org") {
      url.hostname = "practicepointer.org";
      url.protocol = "https:";
      return Response.redirect(url.toString(), 301);
    }

    return env.ASSETS.fetch(request);
  },
};
