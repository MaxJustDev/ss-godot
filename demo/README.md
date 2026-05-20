# Demo project

Showcase application for ss-godot SDK.

## Setup

```bash
# From repo root
cp -r addons demo/   # or symlink: ln -s ../addons addons (Linux/Mac)
```

Windows PowerShell symlink:

```powershell
New-Item -ItemType SymbolicLink -Path demo\addons -Target ..\addons
```

Then open `demo/project.godot` in Godot 4.3+. Enable plugin in **Project Settings → Plugins**.

## Scenes

- `scenes/demo.tscn` — main menu wiring every module's example.

Per-module sample scripts in `scripts/`. Each exercises:

- Login / register / logout
- Save + load progress
- Read + claim mailbox
- Inventory CRUD (add, deduct, move, swap, equip, craft, gacha)
- Quest claim
- Shop purchase
- Leaderboard fetch
- Battle session lifecycle
- Journey events emit
- Lua script invoke (stub)

## Status

WIP. Most scenes land in M7 (docs + demo polish) after module ports complete.
