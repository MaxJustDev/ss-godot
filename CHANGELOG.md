# Changelog

All notable changes to **ss-godot** are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Tracks upstream `SaiGame-studio/ss-unity` SDK. Godot port uses independent SemVer (see `sdk_port_plan.html` §10).

## [Unreleased]

### Planned (M1)
- `core/sai_server.gd` — full HTTP wrapper (GET/POST/PUT/PATCH/DELETE).
- `util/aes_helper.gd` — AES CBC/PKCS7 cross-platform with .NET test vector verification.
- `util/json_helper.gd` — JSON parse/stringify with typed wrapper.
- Unit tests for core + AES (GUT framework).

## [0.1.0-dev] — 2026-05-20

### Added
- M0 repo skeleton.
- `addons/sai_services/` plugin scaffold (`plugin.cfg`, `plugin.gd`, `icon.svg`).
- Autoload registration for `SaiServer` singleton stub.
- Module directory structure mirroring upstream `Assets/SaiGame/Scripts/`:
  - `core/`, `auth/`, `progress/`, `mailbox/`, `item_container/` (8 nested subdirs), `shop/`, `quest/`, `journey/`, `leaderboard/`, `battle/`, `lua_script/`, `util/`, `editor/`.
- `demo/`, `tests/`, `docs/` placeholders.
- MIT LICENSE with upstream attribution.
- Godot 4 `.gitignore`.

### Notes
- Tracks `ss-unity` v0.2.40d.
- Upstream Unity repo has no explicit LICENSE file — port published in good faith under MIT.
