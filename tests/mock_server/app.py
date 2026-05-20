"""Mock SaiGame backend for offline integration tests.

Run:
    pip install flask
    python app.py  # listens on http://127.0.0.1:8765

In Godot tests, point SaiServer.BASE_URL to http://127.0.0.1:8765 via a test-only
override (subclass or `_test_base_url_override` member).

This mock returns canned responses derived from docs/endpoints.md.
It does NOT validate request bodies strictly — tests for that live in upstream.
"""

from __future__ import annotations

import secrets
import time
from typing import Any

from flask import Flask, jsonify, request

app = Flask(__name__)

# --- In-memory state ---------------------------------------------------------

USERS: dict[str, dict[str, Any]] = {
    # username -> {password, user_id, email}
    "demo": {"password": "demo", "user_id": "u_001", "email": "demo@example.com"},
}
TOKENS: dict[str, str] = {}  # access_token -> user_id
REFRESH: dict[str, str] = {}  # refresh_token -> user_id
PROGRESS: dict[str, dict[str, Any]] = {
    "u_001": {"level": 1, "xp": 0, "gold": 100, "custom": {}},
}


def _seed_mailbox() -> list[dict[str, Any]]:
    return [
        {
            "id": "m_001",
            "sender_id": "system",
            "subject": "Welcome to SaiGame",
            "body": "Your adventure begins!",
            "message_type": "system",
            "status": "unread",
            "attachments": [],
            "expires_at": "",
            "read_at": "",
            "claimed_at": "",
            "created_at": "2026-05-20T00:00:00Z",
        },
        {
            "id": "m_002",
            "sender_id": "gm_001",
            "subject": "Daily reward",
            "body": "Claim your daily bonus.",
            "message_type": "reward",
            "status": "unread",
            "attachments": [
                {"type": "currency", "definition_id": "gold", "quantity": 500, "item_definition": {}},
                {"type": "item", "definition_id": "def_potion", "quantity": 3, "item_definition": {"name": "Healing Potion"}},
            ],
            "expires_at": "2026-06-20T00:00:00Z",
            "read_at": "",
            "claimed_at": "",
            "created_at": "2026-05-20T00:00:01Z",
        },
    ]


# user_id -> list of message dicts (mutable per-user mailbox).
MAILBOX: dict[str, list[dict[str, Any]]] = {
    "u_001": _seed_mailbox(),
}


def _new_token() -> str:
    return secrets.token_urlsafe(24)


def _require_auth() -> str | None:
    h = request.headers.get("Authorization", "")
    if not h.startswith("Bearer "):
        return None
    return TOKENS.get(h[len("Bearer "):])


# --- Health ------------------------------------------------------------------


@app.get("/api/health")
def health() -> Any:
    return jsonify({"ok": True, "ts": int(time.time())})


# --- Auth --------------------------------------------------------------------


@app.post("/api/v1/auth/login")
def login() -> Any:
    body = request.get_json(silent=True) or {}
    user = USERS.get(body.get("username", ""))
    if not user or user["password"] != body.get("password"):
        return jsonify({"error": "invalid_credentials"}), 401
    access = _new_token()
    refresh = _new_token()
    TOKENS[access] = user["user_id"]
    REFRESH[refresh] = user["user_id"]
    return jsonify({
        "access_token": access,
        "refresh_token": refresh,
        "expires_in": 3600,
        "user": {"id": user["user_id"], "username": body["username"], "email": user["email"]},
    })


@app.post("/api/v1/auth/register")
def register() -> Any:
    body = request.get_json(silent=True) or {}
    uname = body.get("username", "")
    if not uname or uname in USERS:
        return jsonify({"error": "username_taken"}), 409
    user_id = f"u_{len(USERS) + 1:03d}"
    USERS[uname] = {"password": body.get("password", ""), "user_id": user_id, "email": body.get("email", "")}
    PROGRESS[user_id] = {"level": 1, "xp": 0, "gold": 0, "custom": {}}
    return jsonify({"user": {"id": user_id, "username": uname, "email": body.get("email", "")}})


@app.post("/api/v1/auth/refresh")
def refresh_token() -> Any:
    body = request.get_json(silent=True) or {}
    user_id = REFRESH.get(body.get("refresh_token", ""))
    if not user_id:
        return jsonify({"error": "invalid_refresh"}), 401
    access = _new_token()
    TOKENS[access] = user_id
    return jsonify({"access_token": access, "expires_in": 3600})


@app.post("/api/v1/auth/logout")
def logout() -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({})


# --- Progress ----------------------------------------------------------------
#
# GamerProgress per docs/endpoints.md (## GamerProgress).
# The state model used by tests is keyed by user_id and stores the wire-shape
# fields: id, user_id, game_id, level, experience, gold, game_data (str),
# created_at, updated_at, version. PROGRESS above is initialised with a
# simpler schema for backwards-compat with existing tests; handlers below
# upgrade entries lazily to the full schema on access.


def _ensure_full_progress(user_id: str, game_id: str) -> dict[str, Any] | None:
    """Upgrade a legacy PROGRESS entry into the full wire shape, or return
    None if no record exists for this user/game."""
    if user_id not in PROGRESS:
        return None
    p = PROGRESS[user_id]
    # Legacy entries may lack the wire-shape keys. Patch in defaults.
    now = int(time.time())
    p.setdefault("id", f"prog_{user_id}")
    p.setdefault("user_id", user_id)
    p["game_id"] = game_id  # always refresh — record is per (user, game).
    p.setdefault("level", 1)
    p.setdefault("experience", p.pop("xp") if "xp" in p else 0)
    p.setdefault("gold", 0)
    # game_data is raw JSON string. Migrate legacy "custom" dict if present.
    if "game_data" not in p:
        legacy = p.pop("custom", None)
        if isinstance(legacy, (dict, list)):
            import json as _json
            p["game_data"] = _json.dumps(legacy)
        elif isinstance(legacy, str):
            p["game_data"] = legacy
        else:
            p["game_data"] = "{}"
    p.setdefault("created_at", now)
    p.setdefault("updated_at", now)
    p.setdefault("version", 1)
    return p


@app.post("/api/v1/games/<game_id>/gamer-progress")
def create_progress(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    now = int(time.time())
    import json as _json
    raw_gd = body.get("game_data", {})
    game_data_str = _json.dumps(raw_gd) if isinstance(raw_gd, (dict, list)) else str(raw_gd or "{}")
    record = {
        "id": f"prog_{user_id}",
        "user_id": user_id,
        "game_id": game_id,
        "level": 1,
        "experience": int(body.get("experience", 0)),
        "gold": int(body.get("gold", 0)),
        "game_data": game_data_str,
        "created_at": now,
        "updated_at": now,
        "version": 1,
    }
    PROGRESS[user_id] = record
    return jsonify({"data": record, "message": "created"}), 201


@app.get("/api/v1/games/<game_id>/my-gamer-progress")
def get_progress(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    p = _ensure_full_progress(user_id, game_id)
    if p is None:
        return jsonify({"error": "not_found"}), 404
    return jsonify(p)


@app.patch("/api/v1/gamer-progress/<progress_id>")
def patch_progress(progress_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    # Find the record by id across users (per-user storage in this mock).
    target_user: str | None = None
    for uid, rec in PROGRESS.items():
        if rec.get("id") == progress_id or (uid == user_id and progress_id == f"prog_{uid}"):
            target_user = uid
            break
    if target_user is None:
        return jsonify({"error": "not_found"}), 404
    p = _ensure_full_progress(target_user, PROGRESS[target_user].get("game_id", ""))
    if p is None:
        return jsonify({"error": "not_found"}), 404
    body = request.get_json(silent=True) or {}
    p["experience"] = int(p.get("experience", 0)) + int(body.get("experience_delta", 0))
    p["gold"] = int(p.get("gold", 0)) + int(body.get("gold_delta", 0))
    if "game_data" in body:
        import json as _json
        gd = body["game_data"]
        p["game_data"] = _json.dumps(gd) if isinstance(gd, (dict, list)) else str(gd or "{}")
    p["updated_at"] = int(time.time())
    p["version"] = int(p.get("version", 0)) + 1
    return jsonify(p)


@app.delete("/api/v1/games/<game_id>/my-gamer-progress")
def delete_progress(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    PROGRESS.pop(user_id, None)
    return jsonify({}), 200


# Retained for now: legacy PUT handler used by older tests. Once the GamerProgress
# port is the only consumer this can be removed (real backend uses PATCH).
@app.put("/api/v1/games/<game_id>/my-gamer-progress")
def put_progress(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    cur = PROGRESS.setdefault(user_id, {"level": 1, "xp": 0, "gold": 0, "custom": {}})
    for k in ("level", "xp", "gold", "custom"):
        if k in body:
            cur[k] = body[k]
    return jsonify({"ok": True})


# --- Mailbox -----------------------------------------------------------------
#
# Endpoints mirror docs/endpoints.md `## Mailbox`:
#   GET    /api/v1/games/<game_id>/mailbox/messages
#   PATCH  /api/v1/games/<game_id>/mailbox/messages/<message_id>   body {read: bool}
#   POST   /api/v1/games/<game_id>/mailbox/messages/<message_id>/claim   body {}
#   DELETE /api/v1/games/<game_id>/mailbox/messages/<message_id>/claim   (unclaim)
#   DELETE /api/v1/games/<game_id>/mailbox/messages/<message_id>         (delete)


def _find_mailbox_message(user_id: str, message_id: str) -> dict[str, Any] | None:
    for msg in MAILBOX.get(user_id, []):
        if msg["id"] == message_id:
            return msg
    return None


@app.get("/api/v1/games/<game_id>/mailbox/messages")
def mailbox_list(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    try:
        limit = int(request.args.get("limit", "20"))
        offset = int(request.args.get("offset", "0"))
    except ValueError:
        return jsonify({"error": "invalid_pagination"}), 400
    messages = MAILBOX.get(user_id, [])
    page = messages[offset : offset + limit]
    return jsonify({"messages": page, "total": len(messages)})


@app.patch("/api/v1/games/<game_id>/mailbox/messages/<message_id>")
def mailbox_patch(game_id: str, message_id: str) -> Any:
    # PATCH is dual-use: `{"read": true}` -> mark_read, `{"read": false}` ->
    # mark_unread. Same path, body literal differs only by the bool. Response
    # wraps the message ({message, message_text}); client also tolerates a
    # flat MailboxMessage shape.
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    msg = _find_mailbox_message(user_id, message_id)
    if msg is None:
        return jsonify({"error": "not_found"}), 404
    body = request.get_json(silent=True) or {}
    if "read" not in body:
        return jsonify({"error": "missing_read_flag"}), 400
    if bool(body["read"]):
        msg["status"] = "read"
        msg["read_at"] = "2026-05-20T00:00:05Z"
    else:
        msg["status"] = "unread"
        msg["read_at"] = ""
    return jsonify({"message": msg, "message_text": "ok"})


@app.post("/api/v1/games/<game_id>/mailbox/messages/<message_id>/claim")
def mailbox_claim(game_id: str, message_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    msg = _find_mailbox_message(user_id, message_id)
    if msg is None:
        return jsonify({"error": "not_found"}), 404
    if msg.get("claimed_at"):
        return jsonify({"error": "already_claimed"}), 409
    msg["status"] = "claimed"
    msg["claimed_at"] = "2026-05-20T00:00:10Z"
    rewards = [
        {
            "type": a.get("type", ""),
            "definition_id": a.get("definition_id", ""),
            "quantity": int(a.get("quantity", 0)),
        }
        for a in msg.get("attachments", [])
    ]
    return jsonify({"rewards": rewards})


@app.delete("/api/v1/games/<game_id>/mailbox/messages/<message_id>/claim")
def mailbox_unclaim(game_id: str, message_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    msg = _find_mailbox_message(user_id, message_id)
    if msg is None:
        return jsonify({"error": "not_found"}), 404
    msg["claimed_at"] = ""
    if msg.get("status") == "claimed":
        msg["status"] = "read" if msg.get("read_at") else "unread"
    return jsonify({})


@app.delete("/api/v1/games/<game_id>/mailbox/messages/<message_id>")
def mailbox_delete(game_id: str, message_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    messages = MAILBOX.get(user_id, [])
    for i, msg in enumerate(messages):
        if msg["id"] == message_id:
            messages.pop(i)
            return jsonify({})
    return jsonify({"error": "not_found"}), 404


# --- Journey / PlayerEvent ---------------------------------------------------
#
# Single endpoint per docs/endpoints.md `## Journey`:
#   POST /api/v1/games/<game_id>/events  body { event_type, session_id, event_data }
#
# We log each accepted event into an in-memory list keyed by user_id (tests
# can inspect EVENTS to assert the wire-shape). Response mirrors the upstream
# `TrackEventResponse { message, event_id }` shape
# (6_Journey/TrackEventResponse.cs:6).

EVENTS: dict[str, list[dict[str, Any]]] = {}


@app.post("/api/v1/games/<game_id>/events")
def track_event(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    event_type = str(body.get("event_type", ""))
    if not event_type:
        return jsonify({"error": "missing_event_type"}), 400
    session_id = str(body.get("session_id", ""))
    event_data = body.get("event_data", {})
    event_id = f"ev_{secrets.token_hex(8)}"
    record = {
        "event_id": event_id,
        "user_id": user_id,
        "game_id": game_id,
        "event_type": event_type,
        "session_id": session_id,
        "event_data": event_data,
        "received_at": int(time.time()),
    }
    EVENTS.setdefault(user_id, []).append(record)
    return jsonify({"message": "event tracked", "event_id": event_id})


# --- Shop --------------------------------------------------------------------
#
# Endpoints per docs/endpoints.md (## Shop). State model:
#   - SHOPS: list of shop records, shared across users (filtered by game_id)
#   - SHOP_ITEMS: list of shop-item records, with stock + per-player purchase
#     tracking (PLAYER_PURCHASE_COUNTS)
#   - PURCHASES: per-user list of PurchaseRecord (reserved for future
#     `Shop.history()` endpoint — not yet exposed)
#   - PURCHASE_IDEMPOTENCY: replay-detection cache keyed by
#     (user_id, shop_id, idempotency_key)
#
# Currency is wired into the existing GamerProgress.gold balance so tests can
# exercise insufficient_balance / out_of_stock paths end-to-end.

SHOPS: list[dict[str, Any]] = [
    {
        "id": "shop_001",
        "studio_id": "st_demo",
        "game_id": "g_test",
        "shop_key": "main_store",
        "name": "Main Store",
        "description": "Default starter shop.",
        "shop_type": "general",
        "is_active": True,
        "currency_item_def_id": "def_gold",
        "item_count": 2,
        "starts_at": "",
        "ends_at": "",
        "created_at": "2026-05-20T00:00:00Z",
        "updated_at": "2026-05-20T00:00:00Z",
    },
]

SHOP_ITEMS: list[dict[str, Any]] = [
    {
        "id": "si_001",
        "shop_id": "shop_001",
        "item_def_id": "def_sword",
        "display_name": "Iron Sword",
        "description": "+5 ATK",
        "price": 50,
        "currency_item_def_id": "def_gold",
        "purchase_limit_type": "",
        "purchase_limit": 0,
        "restock_schedule": "",
        "stock": 99,
        "sort_order": 1,
        "is_active": True,
        "available_from": "",
        "available_until": "",
        "created_at": "2026-05-20T00:00:00Z",
        "updated_at": "2026-05-20T00:00:00Z",
        "purchased_count": 0,
    },
    {
        "id": "si_002",
        "shop_id": "shop_001",
        "item_def_id": "def_potion",
        "display_name": "Health Potion",
        "description": "Restores 50 HP.",
        "price": 10,
        "currency_item_def_id": "def_gold",
        "purchase_limit_type": "player",
        "purchase_limit": 5,
        "restock_schedule": "",
        "stock": 200,
        "sort_order": 2,
        "is_active": True,
        "available_from": "",
        "available_until": "",
        "created_at": "2026-05-20T00:00:00Z",
        "updated_at": "2026-05-20T00:00:00Z",
        "purchased_count": 0,
    },
]

PURCHASES: dict[str, list[dict[str, Any]]] = {}
PLAYER_PURCHASE_COUNTS: dict[tuple[str, str], int] = {}
PURCHASE_IDEMPOTENCY: dict[tuple[str, str, str], dict[str, Any]] = {}


@app.get("/api/v1/games/<game_id>/shops")
def list_shops(game_id: str) -> Any:
    """List shops for a game. Paginated via ?limit & ?offset.

    upstream: 4_Shop/Shop.cs:139 — Shop.GetShopsCoroutine
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    try:
        limit = int(request.args.get("limit", "20"))
        offset = int(request.args.get("offset", "0"))
    except ValueError:
        return jsonify({"error": "invalid_pagination"}), 400
    matching = [s for s in SHOPS if s.get("game_id") == game_id]
    page = matching[offset : offset + limit]
    return jsonify({
        "shops": page,
        "limit": limit,
        "offset": offset,
        "total": len(matching),
    })


@app.get("/api/v1/games/<game_id>/shops/<shop_id>/items")
def list_shop_items(game_id: str, shop_id: str) -> Any:
    """List items in a single shop.

    upstream: 4_Shop/Shop.cs:315 — Shop.GetShopItemsCoroutine
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    shop = next((s for s in SHOPS if s["id"] == shop_id and s["game_id"] == game_id), None)
    if shop is None:
        return jsonify({"error": "shop_not_found"}), 404
    items: list[dict[str, Any]] = []
    for raw in SHOP_ITEMS:
        if raw["shop_id"] != shop_id:
            continue
        # Project a per-user view so purchased_count reflects this caller's
        # history (matches the upstream comment on ShopItemData.cs:29).
        view = dict(raw)
        if view.get("purchase_limit_type") == "player":
            view["purchased_count"] = PLAYER_PURCHASE_COUNTS.get((user_id, raw["id"]), 0)
        items.append(view)
    return jsonify({
        "items": items,
        "item_count": len(items),
        "shop_id": shop_id,
    })


@app.post("/api/v1/games/<game_id>/shops/<shop_id>/purchase")
def purchase_shop_item(game_id: str, shop_id: str) -> Any:
    """Purchase a shop item. Deducts gold from GamerProgress and increments
    per-player / global purchase counters.

    Idempotency: a repeated `idempotency_key` for the same (user, shop)
    returns the original PurchaseRecord without double-charging.

    Errors mirror docs/examples/shop.md:
      - 404 shop_not_found / item_not_found
      - 402 insufficient_balance
      - 409 item_out_of_stock / purchase_limit_reached / item_inactive

    upstream: 4_Shop/Shop.cs:406-416 — Shop.PurchaseItemCoroutine
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    shop_item_id = body.get("shop_item_id", "")
    try:
        quantity = int(body.get("quantity", 1))
    except (TypeError, ValueError):
        return jsonify({"error": "bad_quantity"}), 400
    idempotency_key = body.get("idempotency_key", "")
    if quantity <= 0:
        return jsonify({"error": "bad_quantity"}), 400

    # Replay detection: same (user, shop, key) returns the original record
    # without re-charging.
    if idempotency_key:
        existing = PURCHASE_IDEMPOTENCY.get((user_id, shop_id, idempotency_key))
        if existing is not None:
            return jsonify({"purchase_record": existing})

    shop = next((s for s in SHOPS if s["id"] == shop_id and s["game_id"] == game_id), None)
    if shop is None:
        return jsonify({"error": "shop_not_found"}), 404
    item = next(
        (i for i in SHOP_ITEMS if i["id"] == shop_item_id and i["shop_id"] == shop_id),
        None,
    )
    if item is None:
        return jsonify({"error": "item_not_found"}), 404
    if not item.get("is_active", True):
        return jsonify({"error": "item_inactive"}), 409
    if int(item.get("stock", 0)) < quantity:
        return jsonify({"error": "item_out_of_stock"}), 409

    # Per-player purchase limit.
    if item.get("purchase_limit_type") == "player" and int(item.get("purchase_limit", 0)) > 0:
        already = PLAYER_PURCHASE_COUNTS.get((user_id, shop_item_id), 0)
        if already + quantity > int(item["purchase_limit"]):
            return jsonify({"error": "purchase_limit_reached"}), 409

    # Charge gold via GamerProgress (link to PROGRESS).
    progress = _ensure_full_progress(user_id, game_id)
    total_price = int(item["price"]) * quantity
    if progress is None or int(progress.get("gold", 0)) < total_price:
        return jsonify({"error": "insufficient_balance"}), 402

    progress["gold"] = int(progress["gold"]) - total_price
    progress["updated_at"] = int(time.time())
    progress["version"] = int(progress.get("version", 0)) + 1
    item["stock"] = int(item["stock"]) - quantity
    if item.get("purchase_limit_type") == "player":
        PLAYER_PURCHASE_COUNTS[(user_id, shop_item_id)] = (
            PLAYER_PURCHASE_COUNTS.get((user_id, shop_item_id), 0) + quantity
        )
    elif item.get("purchase_limit_type") == "global":
        item["purchased_count"] = int(item.get("purchased_count", 0)) + quantity

    record = {
        "id": f"pr_{_new_token()[:8]}",
        "shop_id": shop_id,
        "shop_item_id": shop_item_id,
        "user_id": user_id,
        "game_id": game_id,
        "quantity": quantity,
        "unit_price": int(item["price"]),
        "total_price": total_price,
        "idempotency_key": idempotency_key,
        "currency_item_def_id": item.get("currency_item_def_id", ""),
        "created_at": str(int(time.time())),
    }
    PURCHASES.setdefault(user_id, []).append(record)
    if idempotency_key:
        PURCHASE_IDEMPOTENCY[(user_id, shop_id, idempotency_key)] = record
    return jsonify({"purchase_record": record})


# --- Leaderboard -------------------------------------------------------------
#
# Endpoints per docs/endpoints.md (## Leaderboard). State model:
#   - LEADERBOARDS: board metadata keyed by board_id
#   - LEADERBOARD_SCORES: per-board score table keyed by board_id ->
#     list[{user_id, display_name, score, metadata, updated_at}]
#
# `submit(board_id, score)` and `around_me(board_id, window)` are NOT part
# of upstream v0.2.40d (Leaderboard.cs exposes 4 read-only endpoints only),
# but the discovery doc explicitly reserves them for M7+. The mock includes
# best-effort stubs for both so future client work has something to talk to:
#   POST /api/v1/games/<game_id>/leaderboards/<board_id>/submit  {score, metadata?}
#   GET  /api/v1/games/<game_id>/leaderboards/<board_id>/around-me?window=N
# Real backend behaviour may differ — verify against captured traffic before
# trusting these for parity testing.

LEADERBOARDS: dict[str, dict[str, Any]] = {
    "lb_global_xp": {
        "id": "lb_global_xp",
        "studio_id": "st_demo",
        "game_id": "g_test",
        "board_key": "global_xp",
        "name": "Global XP",
        "description": "Lifetime XP across all players.",
        "score_mode": "max",
        "sort_direction": "desc",
        "reset_schedule": "never",
        "season_id": "",
        "is_active": True,
        "max_score_delta": 0.0,
        "score_source_type": "client_submit",
        "score_source_ref_id": "",
        "created_at": "2026-05-20T00:00:00Z",
        "updated_at": "2026-05-20T00:00:00Z",
    },
    "lb_weekly_arena": {
        "id": "lb_weekly_arena",
        "studio_id": "st_demo",
        "game_id": "g_test",
        "board_key": "weekly_arena",
        "name": "Weekly Arena",
        "description": "Resets every Monday 00:00 UTC.",
        "score_mode": "max",
        "sort_direction": "desc",
        "reset_schedule": "weekly",
        "season_id": "",
        "is_active": True,
        "max_score_delta": 0.0,
        "score_source_type": "client_submit",
        "score_source_ref_id": "",
        "created_at": "2026-05-20T00:00:00Z",
        "updated_at": "2026-05-20T00:00:00Z",
    },
}

# board_id -> list of {user_id, display_name, score, metadata, updated_at}
LEADERBOARD_SCORES: dict[str, list[dict[str, Any]]] = {
    "lb_global_xp": [
        {"user_id": "u_001", "display_name": "demo", "score": 12450.0,
         "metadata": "", "updated_at": "2026-05-20T00:00:00Z"},
        {"user_id": "u_002", "display_name": "alice", "score": 9000.0,
         "metadata": "", "updated_at": "2026-05-20T00:00:00Z"},
        {"user_id": "u_003", "display_name": "bob", "score": 5000.0,
         "metadata": "", "updated_at": "2026-05-20T00:00:00Z"},
    ],
    "lb_weekly_arena": [
        {"user_id": "u_002", "display_name": "alice", "score": 320.0,
         "metadata": "", "updated_at": "2026-05-20T00:00:00Z"},
        {"user_id": "u_001", "display_name": "demo", "score": 180.0,
         "metadata": "", "updated_at": "2026-05-20T00:00:00Z"},
    ],
}


def _sorted_scores(board_id: str) -> list[dict[str, Any]]:
    """Return scores for `board_id` sorted by the board's sort_direction."""
    board = LEADERBOARDS.get(board_id)
    if board is None:
        return []
    raw = LEADERBOARD_SCORES.get(board_id, [])
    desc = board.get("sort_direction", "desc") != "asc"
    return sorted(raw, key=lambda r: float(r["score"]), reverse=desc)


@app.get("/api/v1/games/<game_id>/leaderboards")
def list_boards(game_id: str) -> Any:
    """List leaderboards for a game.

    upstream: 7_Leaderboard/Leaderboard.cs:131-133
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    matching = [b for b in LEADERBOARDS.values() if b.get("game_id") == game_id]
    return jsonify({"boards": matching})


@app.get("/api/v1/games/<game_id>/leaderboards/<board_id>")
def get_board(game_id: str, board_id: str) -> Any:
    """Get one leaderboard board.

    Upstream tolerates two response shapes: `{board: {...}}` (wrapped) and a
    flat board. We always return wrapped here; the client falls back to flat
    on its own.

    upstream: 7_Leaderboard/Leaderboard.cs:199-201
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    board = LEADERBOARDS.get(board_id)
    if board is None or board.get("game_id") != game_id:
        return jsonify({"error": "board_not_found"}), 404
    return jsonify({"board": board})


@app.get("/api/v1/games/<game_id>/leaderboards/<board_id>/top")
def get_top(game_id: str, board_id: str) -> Any:
    """Top N rankings for a board, sorted by score per board sort_direction.

    upstream: 7_Leaderboard/Leaderboard.cs:273-275
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    board = LEADERBOARDS.get(board_id)
    if board is None or board.get("game_id") != game_id:
        return jsonify({"error": "board_not_found"}), 404
    try:
        limit = int(request.args.get("limit", "10"))
    except ValueError:
        return jsonify({"error": "invalid_limit"}), 400
    sorted_scores = _sorted_scores(board_id)
    entries: list[dict[str, Any]] = []
    for i, row in enumerate(sorted_scores[:limit]):
        entries.append({
            "rank": i + 1,
            "user_id": row["user_id"],
            "display_name": row.get("display_name", ""),
            "score": float(row["score"]),
            "metadata": row.get("metadata", ""),
            "updated_at": row.get("updated_at", ""),
        })
    return jsonify({"entries": entries, "limit": limit, "total": len(sorted_scores)})


@app.get("/api/v1/games/<game_id>/leaderboards/<board_id>/me")
def get_my_rank(game_id: str, board_id: str) -> Any:
    """Calling player's own rank in the board.

    upstream: 7_Leaderboard/Leaderboard.cs:344-346
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    board = LEADERBOARDS.get(board_id)
    if board is None or board.get("game_id") != game_id:
        return jsonify({"error": "board_not_found"}), 404
    sorted_scores = _sorted_scores(board_id)
    rank_idx: int = -1
    row: dict[str, Any] | None = None
    for i, r in enumerate(sorted_scores):
        if r["user_id"] == user_id:
            rank_idx = i
            row = r
            break
    if row is None:
        return jsonify({
            "rank": 0,
            "user_id": user_id,
            "score": 0.0,
            "metadata": "",
            "season": {"id": board.get("season_id", ""), "season_number": 0},
            "updated_at": "",
        })
    return jsonify({
        "rank": rank_idx + 1,
        "user_id": user_id,
        "score": float(row["score"]),
        "metadata": row.get("metadata", ""),
        "season": {"id": board.get("season_id", ""), "season_number": 0},
        "updated_at": row.get("updated_at", ""),
    })


# --- Leaderboard: reserved stubs (NOT upstream) ----------------------------
# Both endpoints are documented in docs/examples/leaderboard.md as the
# intended SDK surface but have no real route in ss-unity v0.2.40d. The mock
# implements them so future client work and integration tests can run; once
# the real backend ships these, re-verify wire shape.

@app.post("/api/v1/games/<game_id>/leaderboards/<board_id>/submit")
def submit_score(game_id: str, board_id: str) -> Any:
    """Submit a score for the calling user. Server applies the board's
    `score_mode` (default: max). Not part of upstream v0.2.40d — reserved.
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    board = LEADERBOARDS.get(board_id)
    if board is None or board.get("game_id") != game_id:
        return jsonify({"error": "board_not_found"}), 404
    body = request.get_json(silent=True) or {}
    try:
        score = float(body.get("score", 0))
    except (TypeError, ValueError):
        return jsonify({"error": "bad_score"}), 400
    metadata = str(body.get("metadata", ""))
    scores = LEADERBOARD_SCORES.setdefault(board_id, [])
    display_name = next(
        (uname for uname, u in USERS.items() if u["user_id"] == user_id),
        user_id,
    )
    existing: dict[str, Any] | None = next((r for r in scores if r["user_id"] == user_id), None)
    score_mode = board.get("score_mode", "max")
    now_str = "2026-05-20T00:00:00Z"
    if existing is None:
        scores.append({
            "user_id": user_id,
            "display_name": display_name,
            "score": score,
            "metadata": metadata,
            "updated_at": now_str,
        })
    else:
        if score_mode == "max":
            existing["score"] = max(float(existing["score"]), score)
        elif score_mode == "sum":
            existing["score"] = float(existing["score"]) + score
        else:  # "latest", "min", fallback to overwrite
            existing["score"] = score
        existing["metadata"] = metadata
        existing["updated_at"] = now_str
    # Recompute rank.
    sorted_scores = _sorted_scores(board_id)
    rank_idx = next((i for i, r in enumerate(sorted_scores) if r["user_id"] == user_id), -1)
    final = next((r for r in sorted_scores if r["user_id"] == user_id), {})
    return jsonify({
        "rank": rank_idx + 1 if rank_idx >= 0 else 0,
        "user_id": user_id,
        "score": float(final.get("score", 0.0)),
        "updated_at": now_str,
    })


@app.get("/api/v1/games/<game_id>/leaderboards/<board_id>/around-me")
def around_me(game_id: str, board_id: str) -> Any:
    """Player-centered window. Returns entries above and below the caller.
    Not part of upstream v0.2.40d — reserved.
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    board = LEADERBOARDS.get(board_id)
    if board is None or board.get("game_id") != game_id:
        return jsonify({"error": "board_not_found"}), 404
    try:
        window = int(request.args.get("window", "10"))
    except ValueError:
        return jsonify({"error": "invalid_window"}), 400
    sorted_scores = _sorted_scores(board_id)
    my_idx = next((i for i, r in enumerate(sorted_scores) if r["user_id"] == user_id), -1)
    if my_idx < 0:
        return jsonify({"entries": [], "total": len(sorted_scores)})
    half = max(window // 2, 1)
    start = max(0, my_idx - half)
    end = min(len(sorted_scores), my_idx + half + 1)
    entries: list[dict[str, Any]] = []
    for i in range(start, end):
        row = sorted_scores[i]
        entries.append({
            "rank": i + 1,
            "user_id": row["user_id"],
            "display_name": row.get("display_name", ""),
            "score": float(row["score"]),
            "metadata": row.get("metadata", ""),
            "updated_at": row.get("updated_at", ""),
            "is_me": row["user_id"] == user_id,
        })
    return jsonify({"entries": entries, "total": len(sorted_scores)})


# --- Quest -------------------------------------------------------------------
#
# Endpoints mirror docs/endpoints.md `## Quest / *`:
#   GET    /api/v1/games/<game_id>/quests/chains
#   GET    /api/v1/games/<game_id>/quests/chains/<chain_id>/members
#   GET    /api/v1/games/<game_id>/quests/chains/<chain_id>/tree
#   POST   /api/v1/games/<game_id>/quests/<quest_id>/start
#   POST   /api/v1/games/<game_id>/quests/<quest_id>/check
#   POST   /api/v1/games/<game_id>/quests/<quest_id>/claim
#   GET    /api/v1/games/<game_id>/quest-claims
#   GET    /api/v1/games/<game_id>/quests/<quest_id>            (status)
#   POST   /api/v1/games/<game_id>/daily-quests/<pool_id>/assign-ahead
#   GET    /api/v1/games/<game_id>/daily-quest-pools
#   GET    /api/v1/games/<game_id>/daily-quests/<pool_id>       (today)

QUEST_CHAINS: list[dict[str, Any]] = [
    {
        "id": "ch_main",
        "studio_id": "s_1",
        "game_id": "g_test",
        "chain_key": "main",
        "display_name": "Main Storyline",
        "description": "Follow the main path",
        "chain_type": "story",
        "is_active": True,
        "created_at": "2026-05-01T00:00:00Z",
        "updated_at": "2026-05-01T00:00:00Z",
    },
]

QUEST_DEFINITIONS: dict[str, dict[str, Any]] = {
    "q_tutorial": {
        "id": "q_tutorial",
        "studio_id": "s_1",
        "game_id": "g_test",
        "code_name": "tutorial_done",
        "name": "Tutorial",
        "description": "Finish the tutorial",
        "quest_type": "chain",
        "conditions": {"operator": "all", "clauses": []},
        "rewards": [
            {"reward_type": "currency", "item_definition_id": "gold", "amount": 50, "quantity": 50},
        ],
        "is_active": True,
        "is_hidden": False,
        "sort_order": 0,
        "created_at": "2026-05-01T00:00:00Z",
        "updated_at": "2026-05-01T00:00:00Z",
    },
    "q_kill_goblin": {
        "id": "q_kill_goblin",
        "studio_id": "s_1",
        "game_id": "g_test",
        "code_name": "kill_goblin",
        "name": "Goblin Slayer",
        "description": "Kill 10 goblins",
        "quest_type": "chain",
        "conditions": {"operator": "all", "clauses": [{"target": 10}]},
        "rewards": [{"reward_type": "currency", "item_definition_id": "gold", "quantity": 100}],
        "is_active": True,
        "is_hidden": False,
        "sort_order": 1,
        "created_at": "2026-05-01T00:00:00Z",
        "updated_at": "2026-05-01T00:00:00Z",
    },
}

CHAIN_MEMBERS: dict[str, list[dict[str, Any]]] = {
    "ch_main": [
        {
            "id": "cm_1",
            "chain_id": "ch_main",
            "quest_definition_id": "q_tutorial",
            "sort_order": 0,
            "unlock_quest_ids": [],
            "definition": QUEST_DEFINITIONS["q_tutorial"],
            "status": "in_progress",
            "created_at": "2026-05-01T00:00:00Z",
            "updated_at": "2026-05-01T00:00:00Z",
        },
        {
            "id": "cm_2",
            "chain_id": "ch_main",
            "quest_definition_id": "q_kill_goblin",
            "sort_order": 1,
            "unlock_quest_ids": ["q_tutorial"],
            "definition": QUEST_DEFINITIONS["q_kill_goblin"],
            "status": "not_started",
            "created_at": "2026-05-01T00:00:00Z",
            "updated_at": "2026-05-01T00:00:00Z",
        },
    ],
}

DAILY_POOLS: list[dict[str, Any]] = [
    {
        "id": "pool_main",
        "studio_id": "s_1",
        "game_id": "g_test",
        "pool_key": "main",
        "display_name": "Daily Tasks",
        "description": "",
        "slots_per_day": 3,
        "reset_hour_utc": 0,
        "assignment_strategy": "random",
        "is_active": True,
        "created_at": "2026-05-01T00:00:00Z",
        "updated_at": "2026-05-01T00:00:00Z",
    },
]

QUEST_PROGRESS: dict[str, dict[str, dict[str, Any]]] = {}
QUEST_CLAIMS: dict[str, list[dict[str, Any]]] = {}


def _user_progress(user_id: str) -> dict[str, dict[str, Any]]:
    return QUEST_PROGRESS.setdefault(user_id, {})


def _user_claims(user_id: str) -> list[dict[str, Any]]:
    return QUEST_CLAIMS.setdefault(user_id, [])


def _make_progress(user_id: str, quest_id: str, game_id: str, status: str = "in_progress") -> dict[str, Any]:
    now = "2026-05-20T00:00:00Z"
    return {
        "id": f"p_{user_id}_{quest_id}",
        "studio_id": "s_1",
        "game_id": game_id,
        "user_id": user_id,
        "quest_definition_id": quest_id,
        "progress_data": {"count": 0},
        "status": status,
        "completed_at": "",
        "claimed_at": "",
        "reset_at": "",
        "version": 1,
        "created_at": now,
        "updated_at": now,
    }


@app.get("/api/v1/games/<game_id>/quests/chains")
def quest_list_chains(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    try:
        limit = int(request.args.get("limit", "50"))
        offset = int(request.args.get("offset", "0"))
    except ValueError:
        return jsonify({"error": "invalid_pagination"}), 400
    page = QUEST_CHAINS[offset : offset + limit]
    return jsonify({"chains": page, "limit": limit, "offset": offset, "total": len(QUEST_CHAINS)})


@app.get("/api/v1/games/<game_id>/quests/chains/<chain_id>/members")
def quest_chain_members(game_id: str, chain_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    members = CHAIN_MEMBERS.get(chain_id)
    if members is None:
        return jsonify({"error": "not_found"}), 404
    return jsonify({"members": members})


@app.get("/api/v1/games/<game_id>/quests/chains/<chain_id>/tree")
def quest_chain_tree(game_id: str, chain_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    members = CHAIN_MEMBERS.get(chain_id)
    if members is None:
        return jsonify({"error": "not_found"}), 404
    nodes: list[dict[str, Any]] = []
    head: dict[str, Any] | None = None
    cursor: dict[str, Any] | None = None
    progress = _user_progress(user_id)
    for m in members:
        qid = m["quest_definition_id"]
        status = progress.get(qid, {}).get("status", "not_started")
        node = {
            "quest_id": qid,
            "quest_name": m["definition"]["name"],
            "status": status,
            "children": [],
        }
        if head is None:
            head = node
            cursor = node
        else:
            assert cursor is not None
            cursor["children"].append(node)
            cursor = node
    if head is not None:
        nodes.append(head)
    return jsonify({"chain_id": chain_id, "chain_name": "Main Storyline", "nodes": nodes})


@app.post("/api/v1/games/<game_id>/quests/<quest_id>/start")
def quest_start(game_id: str, quest_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    progress = _user_progress(user_id)
    if quest_id not in progress:
        progress[quest_id] = _make_progress(user_id, quest_id, game_id, "in_progress")
    p = progress[quest_id]
    return jsonify({
        "id": p["id"],
        "studio_id": p["studio_id"],
        "game_id": p["game_id"],
        "user_id": p["user_id"],
        "quest_definition_id": quest_id,
        "status": p["status"],
        "version": p["version"],
        "created_at": p["created_at"],
        "updated_at": p["updated_at"],
    })


@app.post("/api/v1/games/<game_id>/quests/<quest_id>/check")
def quest_check(game_id: str, quest_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    delta = int(body.get("delta", 0))
    progress = _user_progress(user_id)
    p = progress.setdefault(quest_id, _make_progress(user_id, quest_id, game_id, "in_progress"))
    p["progress_data"]["count"] = int(p["progress_data"].get("count", 0)) + delta
    if p["progress_data"]["count"] >= 10 and p["status"] == "in_progress":
        p["status"] = "completed"
        p["completed_at"] = "2026-05-20T00:30:00Z"
    p["version"] += 1
    definition = QUEST_DEFINITIONS.get(quest_id, {"id": quest_id, "name": quest_id})
    return jsonify({"progress": p, "quest_definition": definition, "status": p["status"]})


@app.post("/api/v1/games/<game_id>/quests/<quest_id>/claim")
def quest_claim(game_id: str, quest_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    progress = _user_progress(user_id)
    p = progress.get(quest_id)
    if p is None:
        return jsonify({"error": "not_started"}), 404
    if p["status"] not in ("completed", "claimed"):
        return jsonify({"error": "not_completed"}), 409
    if p["status"] == "claimed":
        return jsonify({"error": "already_claimed"}), 409
    p["status"] = "claimed"
    p["claimed_at"] = "2026-05-20T00:45:00Z"
    rewards = QUEST_DEFINITIONS.get(quest_id, {}).get("rewards", [])
    claim_id = f"claim_{user_id}_{quest_id}_{len(_user_claims(user_id)) + 1}"
    record = {
        "id": claim_id,
        "studio_id": "s_1",
        "game_id": game_id,
        "user_id": user_id,
        "quest_definition_id": quest_id,
        "progress_id": p["id"],
        "idempotency_key": secrets.token_hex(8),
        "rewards_granted": rewards,
        "claimed_at": p["claimed_at"],
        "quest_definition": QUEST_DEFINITIONS.get(quest_id),
    }
    _user_claims(user_id).append(record)
    return jsonify(record)


@app.get("/api/v1/games/<game_id>/quest-claims")
def quest_claims_list(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    try:
        limit = int(request.args.get("limit", "50"))
        offset = int(request.args.get("offset", "0"))
    except ValueError:
        return jsonify({"error": "invalid_pagination"}), 400
    claims = _user_claims(user_id)
    page = claims[offset : offset + limit]
    return jsonify({"claims": page, "limit": limit, "offset": offset, "total": len(claims)})


@app.get("/api/v1/games/<game_id>/quests/<quest_id>")
def quest_status(game_id: str, quest_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    definition = QUEST_DEFINITIONS.get(quest_id)
    if definition is None:
        return jsonify({"error": "not_found"}), 404
    progress = _user_progress(user_id).get(quest_id)
    return jsonify({
        "progress": progress,
        "quest_definition": definition,
        "status": progress["status"] if progress else "not_started",
    })


@app.get("/api/v1/games/<game_id>/daily-quest-pools")
def daily_pools_list(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({"pools": DAILY_POOLS, "limit": 50, "offset": 0, "total": len(DAILY_POOLS)})


@app.get("/api/v1/games/<game_id>/daily-quests/<pool_id>")
def daily_today(game_id: str, pool_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    pool = next((p for p in DAILY_POOLS if p["id"] == pool_id), None)
    if pool is None:
        return jsonify({"error": "not_found"}), 404
    progress = _user_progress(user_id)
    today = "2026-05-20"
    entries: list[dict[str, Any]] = []
    for qid, defn in QUEST_DEFINITIONS.items():
        p = progress.get(qid, _make_progress(user_id, qid, game_id, "not_started"))
        entries.append({
            "assignment": {
                "id": f"a_{user_id}_{qid}",
                "studio_id": "s_1",
                "game_id": game_id,
                "user_id": user_id,
                "pool_id": pool_id,
                "quest_definition_id": qid,
                "assigned_date": today,
                "expires_at": "2026-05-21T00:00:00Z",
                "created_at": today + "T00:00:00Z",
            },
            "quest": defn,
            "status": p["status"],
            "progress": p,
            "rewards": defn.get("rewards", []),
        })
    streak = {
        "id": f"st_{user_id}_{pool_id}",
        "studio_id": "s_1",
        "game_id": game_id,
        "user_id": user_id,
        "pool_id": pool_id,
        "current_streak": 1,
        "longest_streak": 1,
        "total_completions": 0,
        "version": 1,
        "created_at": today + "T00:00:00Z",
        "updated_at": today + "T00:00:00Z",
    }
    return jsonify({"pool": pool, "entries": entries, "streak": streak, "assigned_date": today})


@app.post("/api/v1/games/<game_id>/daily-quests/<pool_id>/assign-ahead")
def daily_assign_ahead(game_id: str, pool_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    days_ahead = int(body.get("days_ahead", 7))
    pool = next((p for p in DAILY_POOLS if p["id"] == pool_id), None)
    if pool is None:
        return jsonify({"error": "not_found"}), 404
    import datetime as _dt
    start = _dt.date(2026, 5, 20)
    days: list[dict[str, Any]] = []
    for i in range(days_ahead):
        d = start + _dt.timedelta(days=i)
        days.append({
            "date": d.isoformat(),
            "is_today": i == 0,
            "already_assigned": False,
            "quests": [],
        })
    return jsonify({
        "pool_id": pool_id,
        "days_ahead": days_ahead,
        "start_date": start.isoformat(),
        "end_date": (start + _dt.timedelta(days=days_ahead - 1)).isoformat(),
        "days": days,
    })


# --- Battle (sessions + script) ---------------------------------------------
#
# Endpoints per docs/endpoints.md (## Battle):
#   GET  /api/v1/games/<game_id>/me/battle-sessions?limit=&offset=
#   POST /api/v1/games/<game_id>/scripts/<script_name>/run
#
# State model:
#   - BATTLE_SESSIONS: per-(user, game) list of session dicts matching the
#     upstream BattleSessionData wire shape
#     (8_Battle/Models/BattleSessionData.cs).
#   - BATTLE_SCRIPT_LOGS: append-only per-user log of (script_name, payload)
#     pairs so tests can assert what hit the wire.
#
# The script endpoint is a generic RPC dispatcher - upstream forwards the
# response raw without a typed schema (BattleScript.cs:74). To exercise the
# lifecycle promised by docs/examples/battle_session.md, three magic script
# names are recognised:
#   - "create_session" - mints a fresh session, persists it, returns
#     {session_id, status: "in_progress", started_at}
#   - "send_event"     - appends an event to the session battle log and
#     returns {ok: true}
#   - "finish_session" - marks the session finished and returns the canned
#     summary {xp_gained: 100, gold_gained: 50} per the M6c spec
# Any other script name returns {ran: <name>, payload: <body.payload>} so
# generic tests still get a deterministic envelope.

BATTLE_SESSIONS: dict[tuple[str, str], list[dict[str, Any]]] = {}
BATTLE_SCRIPT_LOGS: dict[str, list[dict[str, Any]]] = {}


def _new_battle_session(user_id: str, game_id: str, start_payload: dict[str, Any]) -> dict[str, Any]:
    now = int(time.time())
    return {
        "id": f"bs_{secrets.token_hex(6)}",
        "game_id": game_id,
        "player_id": user_id,
        "status": "in_progress",
        "started_at": str(now),
        "expires_at": str(now + 3600),
        "ended_at": "",
        "start_data": dict(start_payload) if isinstance(start_payload, dict) else {},
        "end_data": {},
    }


@app.get("/api/v1/games/<game_id>/me/battle-sessions")
def list_battle_sessions(game_id: str) -> Any:
    """List the caller's battle sessions for this game.

    upstream: 8_Battle/BattleSessions.cs:123 - GetSessionsCoroutine
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    try:
        limit = int(request.args.get("limit", "50"))
        offset = int(request.args.get("offset", "0"))
    except ValueError:
        return jsonify({"error": "invalid_pagination"}), 400
    sessions = BATTLE_SESSIONS.get((user_id, game_id), [])
    page = sessions[offset : offset + limit]
    return jsonify({
        "limit": limit,
        "offset": offset,
        "total": len(sessions),
        "sessions": page,
    })


@app.post("/api/v1/games/<game_id>/scripts/<script_name>/run")
def run_battle_script(game_id: str, script_name: str) -> Any:
    """Run a server-side battle script. Response is forwarded raw by the SDK
    (BattleScript.cs:74), so the per-script shape is whatever this mock
    returns - tests should assert on raw dictionary keys, not a typed model.

    Three magic script names exercise the docs/examples/battle_session.md
    lifecycle:
      - create_session  -> mints + persists a session, returns its id
      - send_event      -> appends an event to the session battle log
      - finish_session  -> marks finished, returns canned XP/gold summary

    upstream: 8_Battle/BattleScript.cs:69 - RunScriptCoroutine
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    payload = body.get("payload", {}) if isinstance(body, dict) else {}
    if not isinstance(payload, dict):
        payload = {}
    BATTLE_SCRIPT_LOGS.setdefault(user_id, []).append({
        "game_id": game_id,
        "script_name": script_name,
        "payload": payload,
    })

    key = (user_id, game_id)
    sessions = BATTLE_SESSIONS.setdefault(key, [])

    if script_name == "create_session":
        session = _new_battle_session(user_id, game_id, payload)
        sessions.append(session)
        return jsonify({
            "session_id": session["id"],
            "status": session["status"],
            "started_at": session["started_at"],
        })

    if script_name == "send_event":
        session_id = str(payload.get("session_id", ""))
        target = next((s for s in sessions if s["id"] == session_id), None)
        if target is None:
            return jsonify({"error": "session_not_found"}), 404
        log = target["start_data"].setdefault("battle_log", [])
        log.append({
            "type": payload.get("event_type", ""),
            "data": payload.get("event_data", {}),
            "ts": int(time.time()),
        })
        return jsonify({"ok": True})

    if script_name == "finish_session":
        session_id = str(payload.get("session_id", ""))
        target = next((s for s in sessions if s["id"] == session_id), None)
        if target is None:
            return jsonify({"error": "session_not_found"}), 404
        target["status"] = "finished"
        target["ended_at"] = str(int(time.time()))
        target["end_data"] = {
            "victory": bool(payload.get("victory", False)),
            "summary": str(payload.get("result", "")),
        }
        # Canned summary per the M6c spec.
        return jsonify({
            "session_id": session_id,
            "xp_gained": 100,
            "gold_gained": 50,
        })

    # Default: echo back what was run so generic tests get a deterministic shape.
    return jsonify({"ran": script_name, "payload": payload})


# --- ItemContainer (M4) ------------------------------------------------------
#
# Simple in-memory containers / items / presets / tags / equipped slots /
# generators / recipes. No gacha rarity simulation — canned drops only.
#
# upstream: 3_ItemContainer/**/*.cs

CONTAINERS: dict[str, list[dict[str, Any]]] = {}
CONTAINER_ITEMS: dict[str, list[dict[str, Any]]] = {}
INVENTORY: dict[str, list[dict[str, Any]]] = {}
PRESETS: dict[str, list[dict[str, Any]]] = {}
TAGS_BY_GAME: dict[str, list[dict[str, Any]]] = {}
EQUIPMENT_SLOTS_DEF: dict[str, list[dict[str, Any]]] = {}
EQUIPPED_BY_USER: dict[str, list[dict[str, Any]]] = {}
GENERATORS_BY_USER: dict[str, list[dict[str, Any]]] = {}
RECIPES_BY_KEY: dict[str, dict[str, Any]] = {}
CRAFTING_HISTORY: dict[str, list[dict[str, Any]]] = {}


def _seed_item_container(user_id: str) -> None:
    CONTAINERS.setdefault(user_id, [
        {
            "id": "c_bag",
            "owner_user_id": user_id,
            "container_type": "bag",
            "item_container_definition_id": "def_bag",
            "definition": {"id": "def_bag", "name": "Bag", "grid_cols": 4, "grid_rows": 4},
        },
    ])
    CONTAINER_ITEMS.setdefault("c_bag", [
        {
            "id": "i_potion",
            "item_definition_id": "d_potion",
            "item_container_id": "c_bag",
            "quantity": 5,
            "definition": {"id": "d_potion", "name": "Potion", "category": "consumable"},
        },
    ])
    INVENTORY.setdefault(user_id, list(CONTAINER_ITEMS["c_bag"]))
    PRESETS.setdefault(user_id, [])
    EQUIPPED_BY_USER.setdefault(user_id, [])
    GENERATORS_BY_USER.setdefault(user_id, [])
    CRAFTING_HISTORY.setdefault(user_id, [])


@app.get("/api/v1/games/<game_id>/containers")
def ic_list_containers(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    return jsonify({
        "containers": CONTAINERS[user_id],
        "has_more": False,
        "limit": int(request.args.get("limit", 50)),
        "offset": int(request.args.get("offset", 0)),
    })


@app.get("/api/v1/containers/<container_id>/items")
def ic_list_container_items(container_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    items = CONTAINER_ITEMS.get(container_id, [])
    return jsonify({"container_id": container_id, "items": items})


@app.post("/api/v1/games/<game_id>/gacha/<gacha_pack_id>")
def ic_open_gacha(game_id: str, gacha_pack_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({
        "is_duplicate": False,
        "items_granted": [{"item_definition_id": "d_gem", "name": "Gem", "quantity": 3}],
        "mailbox_message_id": "msg_1",
        "transaction_id": f"tx_{secrets.token_hex(4)}",
    })


@app.post("/api/v1/games/<game_id>/gacha/by-code/<code>")
def ic_open_gacha_by_code(game_id: str, code: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({
        "is_duplicate": False,
        "items_granted": [{"item_definition_id": "d_gem", "quantity": 5}],
        "mailbox_message_id": "msg_2",
        "transaction_id": f"tx_{secrets.token_hex(4)}",
    })


@app.get("/api/v1/games/<game_id>/inventory")
def ic_inventory_list(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    items = INVENTORY.get(user_id, [])
    category = request.args.get("category", "")
    if category:
        items = [i for i in items if i.get("definition", {}).get("category") == category]
    return jsonify({
        "items": items,
        "limit": int(request.args.get("limit", 50)),
        "offset": int(request.args.get("offset", 0)),
        "total": len(items),
    })


@app.patch("/api/v1/games/<game_id>/inventory-items/<item_id>")
def ic_update_item_props(game_id: str, item_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({"message": "properties updated successfully"})


@app.get("/api/v1/items/categories")
def ic_item_categories() -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({"categories": ["consumable", "weapon", "armor", "currency"]})


# The ONLY /api/v2/ endpoint in the SDK.
@app.put("/api/v2/games/<game_id>/item-inventories/<item_def_id>/qty")
def ic_item_qty(game_id: str, item_def_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    return jsonify({"item_definition_id": item_def_id, "new_quantity": body.get("quantity", 0)})


@app.post("/api/v1/games/<game_id>/inventory/move")
def ic_move(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({"ok": True})


@app.post("/api/v1/games/<game_id>/inventory/swap")
def ic_swap(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({"ok": True})


@app.get("/api/v1/games/<game_id>/item-tags")
def ic_list_tags(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    tags = TAGS_BY_GAME.setdefault(game_id, [
        {"id": "t_1", "tag_key": "weapon", "label": "Weapons", "color": "#cc4444", "item_count": 0},
        {"id": "t_2", "tag_key": "consumable", "label": "Consumables", "color": "#44cc44", "item_count": 0},
    ])
    return jsonify({
        "tags": tags,
        "total": len(tags),
        "limit": int(request.args.get("limit", 50)),
        "offset": int(request.args.get("offset", 0)),
    })


@app.get("/api/v1/games/<game_id>/item-tags/<tag_key>/items")
def ic_items_by_tag(game_id: str, tag_key: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    items = [i for i in INVENTORY[user_id] if i.get("definition", {}).get("category") == tag_key]
    return jsonify({"items": items, "limit": 50, "offset": 0, "total": len(items)})


@app.get("/api/v1/games/<game_id>/inventory/equipment-slots")
def ic_slots(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    slots = EQUIPMENT_SLOTS_DEF.setdefault(game_id, [
        {"id": "s_weapon", "slot_key": "weapon", "name": "Weapon", "is_active": True},
        {"id": "s_armor", "slot_key": "armor", "name": "Armor", "is_active": True},
    ])
    return jsonify({"slots": slots, "total": len(slots)})


@app.post("/api/v1/games/<game_id>/inventory/equip")
def ic_equip(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    _seed_item_container(user_id)
    EQUIPPED_BY_USER[user_id].append({
        "slot_key": body.get("slot_key", ""),
        "item_id": body.get("item_id", ""),
        "slot_data": body.get("slot_data", {}),
    })
    return jsonify({"ok": True})


@app.post("/api/v1/games/<game_id>/inventory/unequip")
def ic_unequip(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    target = body.get("item_id", "")
    _seed_item_container(user_id)
    EQUIPPED_BY_USER[user_id] = [
        e for e in EQUIPPED_BY_USER[user_id] if e.get("item_id") != target
    ]
    return jsonify({"ok": True})


@app.get("/api/v1/games/<game_id>/inventory/equipped")
def ic_equipped(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    return jsonify({"equipped": EQUIPPED_BY_USER[user_id]})


def _ic_find_preset(user_id: str, preset_id: str) -> dict[str, Any] | None:
    for p in PRESETS.get(user_id, []):
        if p.get("id") == preset_id:
            return p
    return None


@app.post("/api/v1/games/<game_id>/presets")
def ic_create_preset(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    _seed_item_container(user_id)
    new = {
        "id": f"p_{secrets.token_hex(4)}",
        "definition_id": body.get("definition_id", "def_loadout"),
        "preset_type": "loadout",
        "name": body.get("name", body.get("code_name", "Preset")),
        "max_slots": 4,
        "is_temp": False,
        "slots": [],
    }
    PRESETS[user_id].append(new)
    return jsonify(new)


@app.get("/api/v1/games/<game_id>/presets")
def ic_list_presets(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    return jsonify({"containers": PRESETS[user_id]})


@app.get("/api/v1/games/<game_id>/presets/<preset_id>")
def ic_get_preset(game_id: str, preset_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    p = _ic_find_preset(user_id, preset_id)
    if p is None:
        return jsonify({"error": "not_found"}), 404
    return jsonify({"container": p, "slots": p.get("slots", [])})


@app.put("/api/v1/games/<game_id>/presets/<preset_id>/slots/<int:slot_index>")
def ic_add_preset_slot(game_id: str, preset_id: str, slot_index: int) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    p = _ic_find_preset(user_id, preset_id)
    if p is None:
        return jsonify({"error": "not_found"}), 404
    slots = [s for s in p.get("slots", []) if s.get("slot_index") != slot_index]
    slots.append({"slot_index": slot_index, "inventory_item_id": body.get("inventory_item_id", "")})
    p["slots"] = slots
    return jsonify({"ok": True})


@app.delete("/api/v1/games/<game_id>/presets/<preset_id>/slots/<int:slot_index>")
def ic_remove_preset_slot(game_id: str, preset_id: str, slot_index: int) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    p = _ic_find_preset(user_id, preset_id)
    if p is None:
        return jsonify({"error": "not_found"}), 404
    p["slots"] = [s for s in p.get("slots", []) if s.get("slot_index") != slot_index]
    return jsonify({"ok": True})


@app.patch("/api/v1/games/<game_id>/presets/<preset_id>")
def ic_update_preset(game_id: str, preset_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    p = _ic_find_preset(user_id, preset_id)
    if p is None:
        return jsonify({"error": "not_found"}), 404
    body = request.get_json(silent=True) or {}
    if "name" in body:
        p["name"] = body["name"]
    if "metadata" in body:
        p["metadata"] = body["metadata"]
    return jsonify(p)


@app.delete("/api/v1/games/<game_id>/presets/<preset_id>")
def ic_delete_preset(game_id: str, preset_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    PRESETS[user_id] = [p for p in PRESETS[user_id] if p.get("id") != preset_id]
    return jsonify({"ok": True})


@app.post("/api/v1/games/<game_id>/crafting/craft")
def ic_craft(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    _seed_item_container(user_id)
    tx = {
        "transaction_id": f"tx_{secrets.token_hex(4)}",
        "success": True,
        "bonus_triggered": False,
        "output_items": [{"item_definition_id": "d_iron_sword", "quantity": 1}],
        "materials_used": [
            {"item_definition_id": "d_iron_ore", "quantity": 2, "was_consumed": True},
        ],
    }
    CRAFTING_HISTORY[user_id].append({
        "id": tx["transaction_id"],
        "recipe_id": body.get("recipe_id", body.get("recipe_key", "")),
        "idempotency_key": body.get("idempotency_key", ""),
        "status": "success",
        "success": True,
        "bonus_triggered": False,
        "outputs_snapshot": tx["output_items"],
        "materials_snapshot": tx["materials_used"],
    })
    return jsonify(tx)


@app.get("/api/v1/games/<game_id>/crafting/history")
def ic_crafting_history(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    txs = CRAFTING_HISTORY[user_id]
    return jsonify({
        "page": int(request.args.get("page", 1)),
        "page_size": int(request.args.get("page_size", 20)),
        "total": len(txs),
        "transactions": txs,
    })


@app.get("/api/v1/games/<game_id>/crafting/recipes-by-key/<recipe_key>")
def ic_recipe_by_key(game_id: str, recipe_key: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    recipe = RECIPES_BY_KEY.setdefault(recipe_key, {
        "id": f"r_{recipe_key}",
        "recipe_key": recipe_key,
        "name": recipe_key.replace("_", " ").title(),
        "category": "weapon",
        "success_rate": 100,
        "bonus_rate": 10,
        "is_active": True,
        "inputs": [],
        "outputs": [],
    })
    return jsonify(recipe)


# GET /generators returns a BARE array — only such response shape in the SDK.
@app.get("/api/v1/games/<game_id>/generators")
def ic_list_generators(game_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    return jsonify(GENERATORS_BY_USER[user_id])


@app.get("/api/v1/games/<game_id>/generators/<inv_item_id>")
def ic_check_generator(game_id: str, inv_item_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    _seed_item_container(user_id)
    for g in GENERATORS_BY_USER[user_id]:
        if g.get("inventory_item_id") == inv_item_id:
            return jsonify(g)
    return jsonify({"error": "not_found"}), 404


@app.post("/api/v1/games/<game_id>/generators/<inv_item_id>/collect")
def ic_collect_generator(game_id: str, inv_item_id: str) -> Any:
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    return jsonify({
        "units_collected": 3,
        "output_item_code": "gem",
        "output_inventory_item_id": f"out_{secrets.token_hex(2)}",
    })


# --- LuaScript (M6d) --------------------------------------------------------
#
# Endpoints mirror docs/endpoints.md `## LuaScript`. Five wire routes — but
# `POST .../scripts/<script_name>/run` is ALREADY served above by the M6c
# `run_battle_script` handler (same wire path, both M6c BattleScript and M6d
# LuaScriptManager call into it). So this section only adds four:
#   GET    /api/v1/games/<game_id>/scripts                          — list
#   POST   /api/v1/games/<game_id>/scripts                          — create
#   PATCH  /api/v1/games/<game_id>/scripts/<script_id>              — full OR
#                                                                      flags-only
#                                                                      (SAME path,
#                                                                      body shape
#                                                                      determines
#                                                                      branch)
#   DELETE /api/v1/games/<game_id>/scripts/<script_id>              — delete
#
# Seed the in-memory list with 3 entries so `GET /scripts` is non-empty and
# tests can assert on unwrap behaviour. The bare-array form is returned (no
# wrapper) to exercise the client's `_extract_scripts_array` fallback chain.

LUA_SCRIPTS: dict[str, list[dict[str, Any]]] = {
    "g_test": [
        {
            "id": "ls_001",
            "name": "battle_start",
            "description": "Initialises battle state.",
            "script_body": "function on_start() return true end",
            "version": 1,
            "is_active": True,
            "is_library": False,
            "created_by": "u_001",
            "created_at": "2026-05-20T00:00:00Z",
            "updated_at": "2026-05-20T00:00:00Z",
        },
        {
            "id": "ls_002",
            "name": "battle_end",
            "description": "Computes battle rewards.",
            "script_body": "function on_end() return { gold = 10 } end",
            "version": 2,
            "is_active": True,
            "is_library": False,
            "created_by": "u_001",
            "created_at": "2026-05-20T00:01:00Z",
            "updated_at": "2026-05-20T00:01:30Z",
        },
        {
            "id": "ls_003",
            "name": "math_lib",
            "description": "Reusable math helpers.",
            "script_body": "return { add = function(a, b) return a + b end }",
            "version": 1,
            "is_active": True,
            "is_library": True,
            "created_by": "u_001",
            "created_at": "2026-05-20T00:02:00Z",
            "updated_at": "2026-05-20T00:02:00Z",
        },
    ],
}


def _find_lua_script(game_id: str, script_id: str) -> dict[str, Any] | None:
    for rec in LUA_SCRIPTS.get(game_id, []):
        if rec["id"] == script_id:
            return rec
    return None


@app.get("/api/v1/games/<game_id>/scripts")
def lua_list(game_id: str) -> Any:
    """List Lua scripts. Returns a BARE JSON array — exercises the bare-array
    branch of the client's `_extract_scripts_array` fallback chain. The three
    wrapper shapes (`scripts` / `data` / `items`) are covered by the unit
    tests against the FakeSaiServer.

    upstream: 9_LuaScript/LuaScriptManager.cs:274 — LoadBackendScriptsCoroutine
    upstream: 9_LuaScript/LuaScriptManager.cs:332-335 — bare-array tolerance
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    records = LUA_SCRIPTS.get(game_id, [])
    return jsonify(records)


@app.post("/api/v1/games/<game_id>/scripts")
def lua_create(game_id: str) -> Any:
    """Create a Lua script. Body shape: `{name, description, script_body}`.

    upstream: 9_LuaScript/LuaScriptManager.cs:587 — CreateRequest
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    name = str(body.get("name", "")).strip()
    if not name:
        return jsonify({"error": "name_required"}), 400
    bucket = LUA_SCRIPTS.setdefault(game_id, [])
    new_id = f"ls_{len(bucket) + 1:03d}"
    now = "2026-05-20T00:10:00Z"
    record = {
        "id": new_id,
        "name": name,
        "description": str(body.get("description", "")),
        "script_body": str(body.get("script_body", "")),
        "version": 1,
        "is_active": True,
        "is_library": False,
        "created_by": user_id,
        "created_at": now,
        "updated_at": now,
    }
    bucket.append(record)
    return jsonify(record), 201


@app.patch("/api/v1/games/<game_id>/scripts/<script_id>")
def lua_patch(game_id: str, script_id: str) -> Any:
    """PATCH is dual-use against the SAME wire path:
      - Full update body (`UpdateRequest`):
          `{description, script_body, is_active, is_library}`
      - Flags-only body (`FlagsRequest`):
          `{is_active, is_library}`
    Distinguished by presence of `script_body` in the request body — matches
    upstream LuaScriptManager.cs:378 (full) vs LuaScriptManager.cs:401 (flags).

    upstream: 9_LuaScript/LuaScriptManager.cs:389,409
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    rec = _find_lua_script(game_id, script_id)
    if rec is None:
        return jsonify({"error": "not_found"}), 404
    body = request.get_json(silent=True) or {}
    # Full update branch — `script_body` present means UpdateRequest shape.
    if "script_body" in body:
        if "description" in body:
            rec["description"] = str(body["description"])
        rec["script_body"] = str(body["script_body"])
    # Flags (shared by both branches).
    if "is_active" in body:
        rec["is_active"] = bool(body["is_active"])
    if "is_library" in body:
        rec["is_library"] = bool(body["is_library"])
    rec["version"] = int(rec.get("version", 0)) + 1
    rec["updated_at"] = "2026-05-20T00:11:00Z"
    return jsonify(rec)


@app.delete("/api/v1/games/<game_id>/scripts/<script_id>")
def lua_delete(game_id: str, script_id: str) -> Any:
    """Delete a Lua script.

    upstream: 9_LuaScript/LuaScriptManager.cs:419 — DeleteScriptCoroutine
    """
    user_id = _require_auth()
    if not user_id:
        return jsonify({"error": "unauthorized"}), 401
    bucket = LUA_SCRIPTS.get(game_id, [])
    for i, rec in enumerate(bucket):
        if rec["id"] == script_id:
            bucket.pop(i)
            return jsonify({})
    return jsonify({"error": "not_found"}), 404


# Note: `POST /api/v1/games/<game_id>/scripts/<script_name>/run` is served by
# `run_battle_script` above — both M6c BattleScript.run_script and M6d
# LuaScriptManager.run share that single wire endpoint, so we do NOT
# re-register it here (Flask would refuse with a duplicate route error).
# The default branch of `run_battle_script` already returns
# `{ran: <name>, payload: <body.payload>}` which is enough for LuaScript
# integration tests to assert raw-passthrough behaviour.


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8765, debug=True)
