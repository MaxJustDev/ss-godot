# Example — LuaScript

Thin RPC wrapper around server-side Lua scripts. The SDK does **not** execute Lua locally — it calls scripts hosted on the SaiGame backend.

## List available scripts

```gdscript
var result := await SaiServer.lua_script.list()
if result.success:
    # `scripts` is Array[Dictionary] (raw backend records — schema is dynamic).
    for s in result.data.scripts:
        print("%s — %s" % [s.get("id", ""), s.get("name", "")])
```

## Run a script

```gdscript
var result := await SaiServer.lua_script.run("damage_calc", {
    "attacker": attacker_id,
    "defender": defender_id,
    "ability": "fireball",
})
if result.success:
    # data == { "name": "damage_calc", "raw": <parsed JSON the script returned> }
    print("Result: %s" % result.data.raw)
```

Body and response shapes are **dynamic** — defined per-script server-side. Client treats them as opaque JSON. Document each script's contract in your game's project docs.

## Update script flags (admin-style)

```gdscript
await SaiServer.lua_script.set_flags(script_id, {"enabled": false})
```

Most games won't need this — it's primarily for tooling that toggles server scripts on/off without redeploys.

## Caveats

- Response forwarding is raw — the SDK doesn't deserialize into a typed model.
- Errors come back as `{success: false, error: "...", data: null}` per the standard return contract.
- Scripts are versioned server-side; the SDK doesn't expose version pinning.
