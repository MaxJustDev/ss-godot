# Endpoint reference

REST endpoints exposed by SaiGame backend. Source of truth for ss-godot port.

> **Status: STUB.** Populated by discovery agent — see `agent_dispatch_plan.md` §"Discovery". Until then, refer to upstream `ss-unity/Assets/SaiGame/Scripts/**/Request*.cs`.

## Base URL

| Environment | URL |
|-------------|-----|
| Production  | `https://api.saigame.studio` |
| Local dev   | `http://local-api.saigame.studio:82` |

## Auth

All authenticated endpoints expect header `Authorization: Bearer <access_token>`.

## Endpoint table

| Method | Path | Auth | Body | Response | Module | Upstream ref |
|--------|------|------|------|----------|--------|--------------|
| POST   | `/api/auth/login`              | No  | `{username, password, game_id}` | `{access_token, refresh_token, expires_in, user}` | Auth | `0_Auth/RequestLogin.cs` |
| POST   | `/api/auth/register`           | No  | `{username, password, email, game_id}` | `{user}` | Auth | `0_Auth/RequestRegister.cs` |
| POST   | `/api/auth/refresh`            | No  | `{refresh_token}` | `{access_token, expires_in}` | Auth | `0_Auth/RequestRefresh.cs` |
| POST   | `/api/auth/logout`             | Yes | `{}` | `{}` | Auth | `0_Auth/RequestLogout.cs` |
| _TBD_  | ...                            | ... | ... | ... | ... | ... |

> ⚠ Rows above are placeholders from `sdk_port_plan.html` §6. Validate every row against upstream `Request*.cs` before relying on them.

## Discovery checklist

- [ ] Clone `ss-unity` locally.
- [ ] `grep -rn "GetRequest\|PostRequest\|PutRequest\|PatchRequest\|DeleteRequest" Assets/SaiGame/Scripts/`
- [ ] For each hit: extract method, path, body shape, response shape, auth requirement.
- [ ] Cross-check against runtime capture (mitmproxy) on Unity demo.
- [ ] Ask SaiGame for OpenAPI / Postman collection (shortcut).
- [ ] Replace this stub with full table.
