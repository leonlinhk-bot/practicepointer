# RUNBOOK —— practicepointer.org 運維手冊

> 這份文件不會過期，因為它只寫「規則與動作」，不寫「某天的狀態」。
> 狀態類資訊（部署 hash、證書到期日、待辦）在 `DEPLOY.md`。

## 一、檔案與目錄

| 路徑 | 性質 | 誰可以改 |
| --- | --- | --- |
| `repo/` | **唯一編輯源** | 內容方改內容檔；機制檔由維運方改 |
| `site/` | 由 `sync-to-publish.sh` 從 `repo/` 生成的發佈快照 | **任何人都不手改** |
| `repo/tools/deploy.sh` | 唯一部署入口 | 維運方 |

`deploy.sh` 會擋三種情況：`site/` 內出現 `.git`／`*.md`／`tools` 等非部署檔案；`site/` 的檔案比
`repo/` 新且內容不同（疑似手改，需 `--force`）；憑證碰不到該 zone。

## 二、部署

```bash
cd ~/WorkBuddy/2026-10-15-11-31-42/repo
./tools/deploy.sh            # 同步 + 部署 + 部署方自檢
./tools/deploy.sh --no-sync  # 不同步
./tools/deploy.sh --force    # 已知 site/ 有手改痕跡，仍要覆蓋
```

退出碼：`0` 全綠；`1` 有真失敗；`2` 有項目因本機代理無法驗證（不算成功也不算失敗）。
`2` 的處理：換通道重驗，或請另一方獨立複驗那幾項。

憑證 = wrangler OAuth token（`pages:write` 足夠）。過期時：

```bash
npx --yes wrangler@4.151.1 login   # 瀏覽器按一次 Allow
```

憑證檔可能在 `~/.wrangler/config/default.toml` 或 `~/Library/Preferences/.wrangler/config/default.toml`；
讀到被輪替的舊檔會表現為 `Invalid API Token`，腳本會自動跳過。

## 三、部署後誰驗什麼

- **部署方**：跑 `deploy.sh` 的自檢（狀態碼、www 301、404、逐 byte 比對、`_headers`、無追蹤碼）。
- **另一方**：獨立對線上做一次只讀複驗。**部署方不能自證** —— 這個專案一小時內出現過
  6 次「假綠/假紅」（守衛掃到自己、空正則匹配所有行、清單漏檔、沒檢查退出碼、忘同步就部署）。
  分工的意義就在這道交叉。

## 四、DNS 與 DNSSEC（改動前必讀）

- 域名在 Cloudflare Registrar，權威 DNS 在 Cloudflare。**必須維持 full setup**，不能改用別家 DNS。
- **DNSSEC 已啟用，DS 已發布到 `.org` 父區**（keytag 2371 / alg 13 / digest type 2）。
  鏈驗證已通過：Google DoH 回 `AD=true`，RRSIG 存在。
- ⚠️ **若要更換 DNS 供應商，第一步必須先在 Cloudflare 撤掉 DNSSEC（移除 DS），等父區 DS 消失後才改 NS。**
  次序反了 = 全網解析失敗，且註冊商無法單方面補救。
- ⚠️ **不要改 registrant 的姓名／組織／電郵**：會觸發 Change of Registrant（新舊信箱雙批准、7 天無人處理自動作廢、批准後 60 天轉出鎖）。
- WHOIS redaction 保持開啟。

## 五、監控

- `practicepointer-health`（cron，每天 09:00，script-only，`no_agent`）：
  查 RDAP `hold`、NS 是否被換成 parking、DS 是否存在。
  異常立即輸出；**每週一 09:00 輸出一條綠燈**，用來證明監控本身還活著；其餘時間健康則沉默。
- RDAP：`https://rdap.publicinterestregistry.org/rdap/domain/practicepointer.org`
- 本機 `dig` 會超時、`openssl s_client` 拉不到 PEM —— 都是代理造成，不是域名或憑證問題。
  用 DoH（`https://cloudflare-dns.com/dns-query?name=…&type=…`，header `accept: application/dns-json`）
  或 `curl -sSv https://<domain>/ 2>&1 | grep -Ei 'subject:|issuer:|expire date'`。

## 六、常見故障對照

| 現象 | 真正原因 | 處理 |
| --- | --- | --- |
| 任何路徑都回 200 首頁 | 部署缺了頂層 `404.html`，Pages 當成 SPA | 補 `404.html` 重新部署 |
| `www` 回 200 且內容與根域相同 | `_worker.js` 被刪或主機名不在 `REDIRECT_HOSTS` | 恢復 `_worker.js` 並部署 |
| `www` 回 522 | Pages 尚未認領該主機名（CNAME 已 Proxied） | 到 Pages 專案確認 `domains` 清單含 `www` |
| `www` 回 502（只有本機） | 本機代理擋了這個主機名 | 換通道驗；用 `https://example.com/nope` 應得 404 作對照 |
| 部署報 `non-interactive` | 非互動 shell 沒把 token 傳成 `CLOUDFLARE_API_TOKEN` | 用 `deploy.sh`，它會處理 |
| DNS 查詢回空 array | 「沒有記錄」的意思，不是查詢失敗 | 用 DoH 的 `Status 0 + Answer 空` 判讀 |

## 七、不可刪除的檔案

`404.html`（否則全站 soft 404）、`_worker.js`（否則 www 重複內容）、`_headers`（安全標頭）、
`CNAME`、`.nojekyll`、`index.html`。刪任何一個，`deploy.sh` 的驗收會紅。
