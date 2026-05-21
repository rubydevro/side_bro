## [Unreleased]

## [0.2.2] - 2026-05-21

- Fix table cell overflow on retries/morgue/queues/busy/scheduled pages — removed `white-space: pre-line` override that defeated `.args` truncation
- Add `overflow: hidden` to `tbody td` and `thead th` so fixed-layout columns never bleed content into adjacent cells
- Move column widths to CSS (`col.w-xs/sm/md/lg`) so they are inspectable and overridable; add `col-compact` padding class for narrow columns
- Shorten retries table "Next Retry" → "Next" and "Retry Count" → "#" headers; tighten those column widths
- Fix refresh button broken by CSP nonce policy — moved `onclick` to `application.js`
- Remove spurious page auto-refresh on non-dashboard pages introduced by live toggle wiring
- Hide poll interval ("· 5s") from live toggle button on all pages except the dashboard
- Template caching now only active when `RACK_ENV=production` so ERB edits are live in development

## [0.2.1] - 2026-05-20

- Add `Content-Security-Policy` header with per-request nonce on all HTML responses
- Cache compiled ERB templates at class level to avoid re-reading files on every request
- Warn at startup when `SIDE_BRO_SESSION_SECRET` is not set
- Display flash messages (`notice`/`error`) in the layout below the topbar
- Wire up extension system: load extension locale files and mount extension routes/assets on `register_extension`
- Fix live toggle double-firing on dashboard (layout inline script removed; `application.js` now owns the button)
- Auto-refresh non-dashboard pages when live toggle is on; expose `window.SideBroLive` API for dashboard sync
- Queue job filter now uses substring match instead of exact match for both class name and args
- Redis memory usage bar now shows actual used/peak percentage instead of hardcoded 30%

## [0.2.0] - 2026-05-20

- Retries, morgue, scheduled, busy, and queue detail pages
- Sticky table headers and scrollable job tables
- Compact sidebar layout with brand mark
- Standardised `format_args_short` helper across all job list views
- Throughput chart tooltip smart positioning; dynamic time-window label
- Dashboard history chart with 1 week / 1 month / 3 month / 6 month range tabs

## [0.1.0] - 2026-05-09

- Initial release
