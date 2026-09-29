---
name: portal-theme-deploy
description: Deploy or revert theming/template changes to the ec-esign Power Pages portal (enhanced data model, dev & test) via idempotent powerpagecomponent Web API upserts, with snapshot + surgical per-component backups. Use when changing the portal's theme, header/footer, landing, web templates, web files, or site settings, or when reverting such a change.
---

# ec-esign Power Pages portal — theme deploy & revert

The portal is an **enhanced data model** site: the runtime reads the `powerpagecomponent` table, not the legacy `mspp_*`/`adx_*` tables. All changes are `powerpagecomponent` upserts over the Dataverse Web API. dev and test share the same website + component GUIDs. See CLAUDE.md → "Power Pages Portal" for IDs, type codes, and rules.

## Before changing anything (backup)
1. Full snapshot (first run of a work item):
   - Dump all components: `GET powerpagecomponents?$filter=_powerpagesiteid_value eq <WSID>&$select=powerpagecomponentid,name,powerpagecomponenttype,content&$top=5000` → save under `power-pages/backups/e-sign-dev/<timestamp>/`.
   - Plus `pac pages download` to the same folder (full `pac pages upload` revert). Backups are gitignored.
2. The deploy helper additionally writes each mutated component's prior state to `…/deploy-*/…before.json` before every PATCH.

## Deploy
- Helper: `node power-pages/scripts/deploy-portal-theme.mjs <dev|test> <phase>`
  - phases: `core` (import EC-* theme web templates), `header-footer` (CS-header includes EC-Base-Styles, CS-footer includes EC-Scripts-Base), `logo` (upload `ec-logo.png` web file + point CS-header at `/ec-logo.png`), `classfix` (`pepp-`→`ppep-`), `all`.
- Creds come from `.env` (`EC_TENANT_ID`/`EC_CLIENT_ID`/`EC_CLIENT_SECRET`, System Admin across EC envs). The target env URL/site is set in the script's `TARGETS` map — do not rely on `.env`'s `EC_ENVIRONMENT_URL`/`EC_WEBSITE_ID` (they point elsewhere).
- Theme source of truth = COE portal (`Cloudstrucc/elections-canada`, `COE/` folder); copies live under `power-pages/theme/`.
- Web template `content` = `{"source": "<liquid>"}`; web file binary is PATCHed to `powerpagecomponents(<id>)/filecontent` (octet-stream, `x-ms-file-name`).

## After deploy (verify)
1. Re-validate every component's `content` parses as JSON (guard against the `%` corruption that breaks `pac`).
2. Restart the site: admin center → **Site Actions → Restart** (a Design Studio *Sync* does not reliably flush the cache).
3. Signed-in visual check on the private site (dev then test); smoke-test an e-sign flow (envelope list, editor).

## Revert
- **Surgical:** re-PATCH the component's `content` from its `*.before.json` backup — no full upload.
- **Full:** `pac pages upload` the snapshot folder.

## Rules
- Never write raw Liquid/CSS/JS as `content` without the `{"source": ...}` envelope — it corrupts the site.
- Never edit legacy `mspp_*` tables expecting a runtime effect.
- Use the `ppep-` class prefix, never `pepp-`.
- Never set `Webapi/<table>/fields` to `*` (removed 2026-09-14) — list explicit columns.
