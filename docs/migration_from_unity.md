# Migration from Unity SDK (ss-unity)

If you already use `SaiGame-studio/ss-unity` v0.2.40d in Unity, here is the mapping to ss-godot.

## API translation cheat sheet

| Unity (C#) | Godot (GDScript) |
|------------|------------------|
| `SaiServer.Instance` | autoload `SaiServer` (or `get_node("/root/SaiServer")`) |
| `SaiServer.Instance.SaiAuth.Login(u, p)` | `SaiServer.auth.login(u, p)` |
| `IEnumerator` + `yield return` | `async` func + `await` |
| `event Action<T>` | `signal <name>(arg: T)` |
| `JsonUtility.ToJson(obj)` | `JSON.stringify(dict)` |
| `JsonUtility.FromJson<T>(s)` | `JSON.parse_string(s)` → Dictionary |
| `MonoBehaviour` | `Node` |
| `SaiBehaviour` | `SaiBehaviour` (Godot port with `_load_components()` hook) |
| `SaiSingleton<T>` | autoload Node (no generic singleton in GDScript) |
| `[SerializeField]` | `@export` |
| `PlayerPrefs.SetString(k, v)` | `ConfigFile` + `user://sai_server.cfg` |
| `UnityWebRequest` | `HTTPRequest` node |
| `AllowAllCertificateHandler` | `TLSOptions.client_unsafe()` (dev only) |
| `Resources.Load(p)` | `load("res://" + p)` / `preload(...)` |
| `OnInspectorGUI` custom editor | `@tool` script + `EditorInspectorPlugin` |

## Naming convention

Unity uses PascalCase. GDScript uses snake_case.

| Unity | Godot |
|-------|-------|
| `GetProgress()` | `get_progress()` |
| `LoginSuccess` event | `login_success` signal |
| `IsAuthenticated` | `is_authenticated` |
| `BaseUrl` | `base_url` |

## Return shape

Unity SDK throws / uses out-params. Godot port returns `Dictionary`:

```gdscript
var result: Dictionary = await SaiServer.auth.login(u, p)
if result.success:
    var user: Dictionary = result.data
else:
    push_error(result.error)
```

`result.success: bool`, `result.error: String`, `result.data: Variant`, `result.status: int` (HTTP code).

## Signals vs. callbacks

Unity:

```csharp
SaiAuth.Instance.OnLoginSuccess += user => Debug.Log("welcome " + user.Username);
SaiAuth.Instance.Login(u, p);
```

Godot:

```gdscript
SaiServer.auth.login_success.connect(func(user): print("welcome %s" % user.username))
SaiServer.auth.login(u, p)
```

## Coroutine vs async

Unity:

```csharp
IEnumerator FetchProgress() {
    yield return SaiServer.Instance.GamerProgress.GetProgress(onSuccess: data => {...});
}
```

Godot:

```gdscript
func fetch_progress() -> void:
    var result := await SaiServer.progress.get_progress()
    if result.success:
        print(result.data)
```

## Module folder mapping

| Unity (`Assets/SaiGame/Scripts/`) | Godot (`addons/sai_services/`) |
|-----------------------------------|--------------------------------|
| `SaiServer.cs` | `core/sai_server.gd` |
| `Common/SaiBehaviour.cs` | `core/sai_behaviour.gd` |
| `Common/SaiSingleton.cs` | `core/sai_singleton.gd` |
| `Common/SaiEncryption.cs` | `util/aes_helper.gd` |
| `0_Auth/` | `auth/` |
| `1_GamerProgress/` | `progress/` |
| `2_Mailbox/` | `mailbox/` |
| `3_ItemContainer/` | `item_container/` (8 nested subdirs preserved) |
| `4_Shop/` | `shop/` |
| `5_Quest/` | `quest/` |
| `6_Journey/` | `journey/` |
| `7_Leaderboard/` | `leaderboard/` |
| `8_Battle/` | `battle/` |
| `9_LuaScript/` | `lua_script/` |
| `Editor/` | `editor/` |

## Breaking differences (no workaround in port)

- **No reflection-based component scanning.** Unity `SaiBehaviour` auto-loads components via reflection. Godot port requires explicit `@onready` references or `_load_components()` overrides.
- **No `[FormerlySerializedAs]` analog.** GDScript serialization is dictionary-based — renames don't break saved files the same way.
- **Editor inspector custom UI** uses Godot's `EditorInspectorPlugin` API which is structurally different from `OnInspectorGUI`.
