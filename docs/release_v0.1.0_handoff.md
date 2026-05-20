# v0.1.0 release — handoff to user

Status as of 2026-05-20: code complete, docs polished. **The remaining steps require the user's GitHub credentials and Godot Asset Library account.**

## What's done (no user action needed)

- ✓ M1 Core (HTTP wrapper, AES, base classes, util/)
- ✓ M2 Auth (login, register, refresh, logout, get_me, Google OAuth)
- ✓ M3a GamerProgress (CRUD)
- ✓ M3b Mailbox (list, read, claim, unclaim, delete)
- ✓ M4 ItemContainer — 9 services, 27 DTOs, 29 endpoints
- ✓ M5a Shop (list, items, purchase)
- ✓ M5b Quest (chain, progressor, history, daily — 11 endpoints)
- ✓ M6a Journey (player events)
- ✓ M6b Leaderboard (list, get, top, my_rank — read-only as upstream)
- ✓ M6c BattleSessions + BattleScript
- ✓ M6d LuaScript (list, run, CRUD)
- ✓ M7 docs polish (API reference, examples sweep, demo scenes login + lobby)
- ✓ AES test vectors verified vs .NET (21/21 byte-equal)
- ✓ Endpoint discovery (62 distinct endpoint paths / 73 method+path rows, all cited to upstream `file:line`)
- ✓ Mock backend (`tests/mock_server/app.py`) covers every endpoint
- ✓ CI workflow (gdtoolkit lint + GUT tests)
- ✓ Release workflow (auto-zip on tag push)
- ✓ Plugin scaffold (`plugin.cfg` v0.1.0, `plugin.gd` autoload)
- ✓ MIT LICENSE with upstream attribution
- ✓ README, CHANGELOG, quick_start, migration_from_unity, 10 per-module example docs
- ✓ `.gdkeep` markers cleaned (only `editor/` and `item_container/gacha/` retain — genuinely empty)

## What the user needs to do (M8)

### Step 1 — Smoke test locally (recommended)

```powershell
# Start mock backend
cd C:\Users\Max\Desktop\SDS\ss-godot\tests\mock_server
pip install -r requirements.txt
python app.py  # leaves listening on http://127.0.0.1:8765
```

In another terminal, open `demo/project.godot` in Godot 4.3+ and run the login scene with creds `demo / demo`.

### Step 2 — Replace placeholder icon

`addons/sai_services/icon.svg` is a placeholder `SS` glyph. Replace with a branded icon (recommended 256×256 PNG or SVG) before tagging.

### Step 3 — Add screenshot to README

README has `<!-- TODO: add screenshot before v0.1.0 release -->`. Replace with a Godot editor screenshot showing `SaiServer` autoload inspector or the login demo scene.

### Step 4 — Commit + tag

```bash
git add .
git commit -m "chore: prepare v0.1.0 release"
git tag v0.1.0
git push origin main --tags
```

The `.github/workflows/release.yml` action will:
- build `dist/sai_services-v0.1.0.zip`
- create GitHub release at <https://github.com/MaxJustDev/ss-godot/releases/tag/v0.1.0>

### Step 5 — Submit to Godot Asset Library

Go to <https://godotengine.org/asset-library/asset>. Log in with your Godot account (create one if needed).

Fill the form with values from `docs/asset_library_submission.md` §"Submission form fields". Key values:

| Field | Value |
|-------|-------|
| Asset name | `SaiGame Services SDK` |
| Category | `Tools` |
| Godot version | `4.3` |
| Version | `0.1.0` |
| Repository | `https://github.com/MaxJustDev/ss-godot` |
| Download URL | `https://github.com/MaxJustDev/ss-godot/releases/download/v0.1.0/sai_services-v0.1.0.zip` |
| Download commit | (paste tag commit SHA from `git rev-parse v0.1.0`) |
| Icon URL | `https://raw.githubusercontent.com/MaxJustDev/ss-godot/main/addons/sai_services/icon.svg` |
| Issues URL | `https://github.com/MaxJustDev/ss-godot/issues` |
| License | `MIT` |

Use the description text in `docs/asset_library_submission.md` §"Description body".

### Step 6 — Notify SaiGame studio (optional but recommended)

Per `sdk_port_plan.html` §13, courtesy-notify upstream SaiGame studio. Template email body lives in that section. Mention:
- Godot port is now public
- License chosen (MIT, with upstream attribution clause)
- Repo URL + Asset Library URL once approved
- Offer to credit / link back from README

### Step 7 — Wait for Asset Library review

1–2 weeks typical turnaround. Common review comments:
- README needs screenshot (already TODO'd above).
- LICENSE missing in source file headers (optional — file-level LICENSE is fine for MIT).

## Future maintenance

For each new version:

1. Bump `version=` in `addons/sai_services/plugin.cfg`.
2. Add `## [X.Y.Z] — YYYY-MM-DD` section to `CHANGELOG.md`.
3. `git tag vX.Y.Z && git push origin vX.Y.Z`.
4. Asset Library admin panel → my assets → ss-godot → **Submit update**.

## Known v0.1.0 limitations (already documented in CHANGELOG + examples)

- Leaderboard: `submit` + `around_me` are reserved client signatures (no upstream endpoint).
- BattleSessions: `create_session` / `send_event` / `finish_session` go through `BattleScript.run_script` with magic script names (no dedicated REST routes upstream).
- Shop: `history()` not in upstream — reserved client signature.
- Module auto-load-on-login hooks intentionally not ported — app layer subscribes to `SaiServer.auth.login_success` directly.

## Risk reminder

Upstream `ss-unity` repo has **no explicit LICENSE file** as of port date. ss-godot LICENSE includes an "Upstream attribution" clause stating intent to re-license or withdraw if SaiGame objects. Step 6 above mitigates this risk.
