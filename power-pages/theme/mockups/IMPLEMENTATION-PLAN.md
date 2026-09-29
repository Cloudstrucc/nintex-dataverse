# EC-PPEP dashboard + notification centre → ec-esign (implementation plan)

## Goal
Bring the EC-PPEP (`dev-ppep-fp-01`, backend `coe-dev`/PERS) design to the ec-esign portal:
authenticated home becomes a **"My Workspace" dashboard** with EC-PPEP-style tiles; a **notification
centre** (bell icon in the header → `/notifications` page) with the same filter pills + table + View/Archive;
modern **rounded pill/tile/list/subgrid** styling; and the **EC-PPEP loading indicator**. Colours: **burgundy
(#6a0032) + navy (#1e384b) primary only** — no PERS per-area dynamic colours.

Reference (studied live + PPEP repo `Cloudstrucc/elections-canada/PPEP`):
- Home service tiles, PP Dashboard (`EC-PP-PoliticalPartyDashboard`), Annual Report list/subgrid, and
  Notification centre ("My Portal Messages", entity list `PERS - Communication Hub - My Portal Messages`
  on table **`pfa_portalmessage`**), loading snippets `EC-PERS-LoadingRecords` / `EC-PERS-PD-Loading`.
- Design mockups in repo: `PPEP/docs/mockups/{notification-centre,political-party-dashboard}-mockup.html`
  (component CSS reused: `.svc-card`, `.pill`, `.chip-svc`, `.tab`, `table.nt`, `.stat`).

Mockups for review (this folder): `my-workspace-mockup.html` (dashboard with filterable envelope table + full-screen + services), `service-landing-mockup.html` (per-service dashboard, 1 level deep), `notification-centre-mockup.html`.

### Tables / lists — use Power Pages entity lists (for the exact EC-PPEP UX)
The EC-PPEP full-screen expand, 10-row pagination, column sort, search and view selector are **native Power
Pages entity-list (`adx_entitylist`) features** (e.g. "My Applications in Progress" at
`.../Political-Entities/`). To match "the same UI feature" exactly, every table (workspace envelopes,
per-service records, notifications) is a **portal list** bound to a Dataverse view, wrapped by a thin
Liquid/JS layer for the KPI-tile filters and (notifications) the tabs/mark-read/archive. This supersedes the
earlier "custom Web API template" idea — the list gives full-screen + pagination + sort out of the box.

## 1. Schema — unmanaged solution (new table)
New table **`cs_portalmessage`** (mirrors `pfa_portalmessage`), added to an **unmanaged** solution:
| Column | Type | Purpose |
|---|---|---|
| cs_name | Primary name | title |
| cs_subject | Text | subject line |
| cs_content | Multiline | body/preview |
| cs_prioritytype | Choice | 891150000 Immediate action required / 891150001 For your information |
| cs_service | Text | service tag (Envelopes / Templates / Signers …) |
| cs_readon | DateTime | **null = unread**, set = read |
| cs_recipientcontactid | Lookup → contact | who the message is for |
| statecode / statuscode | State/Status | **Active = live, Inactive = archived** |

State model (matches EC-PPEP): **Unread** = Active & `cs_readon` null · **Action required** =
`cs_prioritytype=891150000` · **Archived** = statecode Inactive · **All** = Active.
Web API: enable `Webapi/cs_portalmessage/enabled` + explicit `fields` list; add a **Contact-scoped**
table permission (users see/patch only their own, via `cs_recipientcontactid`) linked to Authenticated Users.

## 2. Theme styles (new partial)
Add **`EC-Workspace-Styles`** web template (CSS) with the reusable components — `.svc-card` (rounded 14px,
coloured top bar, icon chip, in-tile links, `.pill.soon`), `.stat` KPI tiles, `.pill`/`.chip-svc`,
`.tab` filter pills, `table.nt` modern list/subgrid, rounded `.btn`. Include it from `EC-Base-Styles`
(so it loads site-wide, same mechanism as the facelift). Colours bound to `--ec-burgundy`/`--ec-navy` only.

## 3. Header (coe-dev-fp style, with nav menu) + footer
Rework **CS-header** to the coe-dev-fp pattern (see `anon-landing-mockup.html`): a white brand row
(logo + "Elections Canada / Electronic Signature Service" + Français) with a burgundy underline, over a
**navy nav bar** driven by a **weblink set** (menu), with a right cluster that swaps by auth state:
- **Anonymous:** menu = Home · Product brief · Help · Get access; **no sign-in button in the header** (users
  sign in from the hero button on the landing).
- **Authenticated:** menu = My Workspace · Product brief · Help; right = **notification bell** (→ `/notifications`,
  burgundy/amber unread badge via Liquid FetchXML count of Active `cs_portalmessage` for the user with
  `cs_readon` null) + **avatar dropdown** = *My profile · Activity & history · Notifications · Sign out*. Active
  menu item = gold underline.
- **Service pill sub-bar (authenticated, all pages):** a light bar under the nav with pills **Envelopes ·
  Templates · Documents** (quick service nav; active pill highlighted). Rendered from the header so it appears
  everywhere; anonymous users don't see it. (Create-a-template and Download-audit-trail are *not* pills — the
  first is a button in the Templates view, the second a row action on the envelope/documents table.)

Rework **CS-footer** to the coe-dev-fp footer: navy bar, burgundy top accent, left `elections.ca · Privacy ·
Terms of use`, right "Internal use — Elections Canada Electronic Signature Service". (Keeps `EC-Scripts-Base`.)

The **anonymous landing** (already deployed) gets this new header + footer — otherwise unchanged.

## 4. "My Workspace" dashboard (authenticated home)
Replace the **authenticated (`{% if user %}`) branch of CS-Home-WET** with the dashboard (per
`my-workspace-mockup.html`). Top to bottom:
1. Welcome hero ("My Workspace").
2. **KPI filter tiles** (Total / In process / Completed / Action required) — these are the "pill tiles" and
   they **filter the envelope table**; **default = Total envelopes**. Counts via `/_api/cs_envelopes`.
3. **My Envelopes table** — a portal **entity list** on `cs_envelope` (a "My Active Envelopes" view),
   **paginated 10**, with the EC-PPEP **full-screen toggle**, search, sortable columns, status pills, and a
   `⋯` row-actions menu. Clicking a KPI tile re-filters the list (default Total).
4. **Services** — **4 `.svc-card` tiles on one responsive row** (Envelopes · Templates · Signed documents ·
   Help & support) **below the table**; each links to that service's landing page (§4b). *Signing status* and
   *Activity & history* tiles are removed — status lives inside the Envelopes/Documents views, and Activity &
   history moves to the profile dropdown (§4c).
All copy via `ESIGN/*` snippets (EN/FR). The **anonymous branch stays as-is** (the landing already built).

## 4c. Activity & history page (profile-menu item, polymorphic table)
New page reached from the **avatar dropdown → Activity & history** (per `activity-history-mockup.html`): a
**polymorphic activity log** across envelopes, signers, templates and documents — one list with a **Type**
badge column (Envelope/Signer/Template/Document), plus Record, Action, By and When, with KPI filter tiles by
type, full-screen + pagination + search. Sourced from a Dataverse **activity/audit view** (or a union list)
scoped to the current user.

## 4b. Per-service landing/dashboard pages (new pages, one level deep)
Each service tile opens its own **landing/dashboard page** (per `service-landing-mockup.html` /
`service-pages-mockup.html`) so users stay one level from home: breadcrumb (`My Workspace / <Service>`), a
service **context banner** with primary actions, KPI **filter tiles**, and that service's **entity list**
(full-screen + pagination + search). Pages + their mockup coverage:
| Page | Mockup | Notes |
|---|---|---|
| Envelopes dashboard | `service-landing-mockup.html` | envelope list |
| Templates dashboard | `service-pages-mockup.html` → Templates | template list (Name/Category/Status) |
| Create a template | `service-pages-mockup.html` → Create | upload form (name, category, status, PDF, fields) |
| Signed documents dashboard | `service-pages-mockup.html` → Documents | doc list + Download + Audit-trail actions |
| Download audit trail | `service-pages-mockup.html` → Audit trail | per-envelope event timeline + "Download audit trail (PDF)" |
| Signing status / Activity | shared `CS-Service-Dashboard` | list variants |
| **Open Help guide** (renamed from "Open Help dashboard") | `help-guide-mockup.html` | see §8 |
All use one shared layout `CS-Service-Dashboard` parameterized per service. Read-only / low-interaction.

## 7b. Product brief page (new — drafted)
New **Product brief** page + template `CS-Product-Brief`: a marketing/overview page for the e-Sign service
(what it is, key capabilities, security/compliance posture, how to get access) in the same theme — linked from
the header on both anon and auth. Content via `ESIGN/BRIEF/*` snippets (EN/FR). (Draft copy to be provided in
the page; mockup styling matches the anon landing bands.)

## 8. Help guide page (new — replaces "Open Help dashboard")
New **Help guide** page + template `CS-Help-Guide` (per `help-guide-mockup.html`), modeled on the coe-dev-fp
**Help & processes** page: title + intro, a left **accordion table of contents** (Getting started / Envelopes /
Templates / Documents & compliance), and a right **content panel** (Process / Troubleshooting / links). Content
via `ESIGN/HELP/*` snippets (EN/FR). The service tile link + header "Help" both point here.

## 5. Notification centre page (`/notifications`)
New web page + template **CS-Notifications** reproducing `notification-centre-mockup.html`, built the same
way as EC-PPEP: a portal **entity list** on `cs_portalmessage` (giving full-screen + pagination + search)
wrapped by custom JS for the **filter tabs** (All/Unread/Action required/Archived with live counts),
**"Mark all read"**, and per-row **View / Archive** — `PATCH cs_readon` on view/mark-read and toggle
`statecode` on archive (via `/_api/cs_portalmessages`). Presentation: priority pill, service chip,
subject+preview, relative date. Bell badge (§3) reflects the Unread count.

## 6. Loading indicator
Port the EC-PPEP loading behaviour: a spinner overlay web template (`EC-Loading`, from
`EC-PERS-LoadingRecords`) shown while lists/Web API calls resolve; wire the dashboard + notification +
existing list templates to show it instead of ec-esign's current indicator.

## 7. Seed data
Create ~5 OOB `cs_portalmessage` records for the signed-in contact (mix of priorities, one archived, some
unread) so the centre and bell badge are populated for review/testing.

## Delivery, backup, revert
- Extend `power-pages/scripts/deploy-portal-theme.mjs` with phases: `workspace-styles`, `header-bell`,
  `dashboard`, `notifications`, `loading`, `seed`. Idempotent `powerpagecomponent` upserts + per-component
  `*.before.json` backups (surgical revert); schema via a separate metadata/solution script.
- **Dev first → verify (your signed-in Chrome tab) → test.** Full `pac` snapshot before the first run.
- Guard: re-validate all `powerpagecomponent.content` is valid JSON; `pac pages download` still succeeds.

## Verification
Signed-in checks on dev then test: dashboard tiles + KPIs render; bell badge shows unread count; `/notifications`
filters/search/mark-read/archive work and persist (`cs_readon`, statecode); loading spinner shows on list loads;
no console/theme regressions; e-sign flows unaffected.

## Open questions for you
1. Tables approach: **Power Pages entity lists** (recommended — gives the EC-PPEP full-screen + pagination +
   sort + search natively) with KPI-tile filters + notification tabs layered on top. Confirm OK.
2. Table/columns prefix `cs_` and table label "Portal Message" OK? Which unmanaged solution to add it to
   (existing, or a new `ESignaturePortal` solution)?
3. Dashboard tile set — the 6 proposed (Envelopes, Templates, Signed documents, Signing status, Activity,
   Help) — add/remove any? And confirm the 6 matching service landing pages.
4. Workspace envelope table columns — proposed: Envelope #, Subject, Template, Signers, Status, Modified.
   Adjust?
