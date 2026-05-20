# Godot Asset Library — submission checklist

Submission requires the user's Godot Asset Library account. This file is the prep doc — the actual submission is a manual web form at <https://godotengine.org/asset-library/asset/edit>.

## Pre-submit checklist

- [ ] All M1–M6 modules ported (`addons/sai_services/` contains every sub-service).
- [ ] All `*.gdkeep` markers removed from non-empty dirs.
- [ ] `addons/sai_services/plugin.cfg` `version="0.1.0"`.
- [ ] `addons/sai_services/icon.svg` polished (current is placeholder — replace with branded icon).
- [ ] `CHANGELOG.md` `[Unreleased]` rolled into `[0.1.0]` with release date.
- [ ] `LICENSE` file in root (MIT).
- [ ] `README.md` has screenshot OR animated demo gif (Asset Library recommends visual preview).
- [ ] `gdtoolkit` lint passes (`gdlint addons/`).
- [ ] `gdformat --check` passes.
- [ ] GUT unit tests pass (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`).
- [ ] Integration tests pass against local mock server (`python tests/mock_server/app.py` then run integration tests).
- [ ] Tag commit: `git tag v0.1.0 && git push origin v0.1.0`.
- [ ] `.github/workflows/release.yml` produces a release zip at `dist/sai_services-v0.1.0.zip`.
- [ ] GitHub release page exists at <https://github.com/MaxJustDev/ss-godot/releases/tag/v0.1.0>.

## Submission form fields

Submit at <https://godotengine.org/asset-library/asset> (requires Godot account).

| Field | Value |
|-------|-------|
| **Asset name** | `SaiGame Services SDK` |
| **Category** | `Tools` (primary) / `Scripts` (alternative if Tools is rejected) |
| **Godot version** | `4.3` |
| **Version string** | `0.1.0` |
| **Description** | (copy from `addons/sai_services/plugin.cfg` `description=` field, expand to ~300 chars) |
| **Repository provider** | `GitHub` |
| **Repository URL** | `https://github.com/MaxJustDev/ss-godot` |
| **Issues URL** | `https://github.com/MaxJustDev/ss-godot/issues` |
| **Icon URL** | `https://raw.githubusercontent.com/MaxJustDev/ss-godot/main/addons/sai_services/icon.svg` |
| **Download URL** | `https://github.com/MaxJustDev/ss-godot/releases/download/v0.1.0/sai_services-v0.1.0.zip` |
| **Download commit** | (tag commit SHA of `v0.1.0`) |
| **License** | `MIT` |

## Description body (paste into form)

> REST client SDK for the SaiGame backend. Godot 4 port of the official Unity SDK (`SaiGame-studio/ss-unity` v0.2.40d).
>
> Provides 10 service modules: Auth (incl. Google login), GamerProgress, Mailbox, Inventory (item containers, crafting, gacha, equipment slots, tags), Shop, Quest (chain / daily / progressor), Journey (player events), Leaderboard, BattleSessions, LuaScript.
>
> Zero dependencies — uses Godot built-in `HTTPRequest`, `JSON`, and `AESContext`. Single autoload `SaiServer` registers all sub-services on plugin enable. Async API via `await` + Dictionary return shape. Token persistence via `ConfigFile`.
>
> Quick start: enable the plugin, set `game_id` on the `SaiServer` autoload, call `SaiServer.auth.login(user, pass)`. See README for full examples.

## Post-submission

- [ ] Maintainer review on godotengine.org — feedback usually within 1–2 weeks.
- [ ] Fix any review comments (most common: README screenshot missing, license header missing in source files).
- [ ] On approval, asset is searchable in editor `AssetLib` tab.
- [ ] Future versions: re-submit via "Update" button in Asset Library admin panel.

## Re-submission for future versions

For each new version:

1. Bump `version=` in `plugin.cfg` + new `CHANGELOG.md` entry.
2. `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. Wait for `release.yml` to build the zip.
4. Asset Library → my assets → ss-godot → **Submit update**.
5. Update version string + download URL + commit SHA.

## References

- Asset Library guidelines: <https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html>
- Plugin layout requirements: <https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html>
