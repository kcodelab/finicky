# Native UI Phase 1 Regression Checklist

## Automated baseline
1. `cd /Users/kaaaaai/Documents/PersonalItems/finicky/apps/finicky/src && go build ./...`
2. `cd /Users/kaaaaai/Documents/PersonalItems/finicky/packages/config-api && npm test -- wildcard.test.ts`

## Manual checks (native Overview + Config)
1. Open Finicky window. Confirm native tabs `Overview`, `Config`, and `Web (Legacy)` exist.
2. In `Overview`, verify config state/options are visible and iCloud toggle is clickable.
3. In `Config`, verify draft backfill works (default browser + routes populated from existing config).
4. In `Config`, set a Chromium browser route and pick a profile path (`Default` / `Profile 1` style), then `Save and Activate`.
5. Click `Format` and confirm preview updates with generated config text.
6. Confirm route match behavior for `*.feishu.cn` still works by testing URLs that include root and subdomain forms.
7. Toggle iCloud sync enable/disable and confirm status text updates on both `Overview` and `Config`.
8. After repeated saves, verify backups are in `~/finicky/backups` and only latest 10 entries are kept for the same config path.
