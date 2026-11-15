@app.get("/api/game/bootstrap")
async def api_game_bootstrap(user=Depends(current_user), guild: str = ""):
    """Godot 클라이언트가 상점/상태를 열 때 쓰는 부트스트랩 정보."""
    guilds = user.get("admin_guilds") or []
    gid = str(guild or (guilds[0].get("id") if guilds else ""))
    if not gid:
        return JSONResponse({"ok": False, "error": "관리 중인 서버가 없습니다."})
    uid = str(user.get("id"))
    cfg = _load_minigame_config()
    catalog = _mg_shop_catalog(cfg)
    st = _mg_minigame_state(uid)
    u = _mg_user(uid)
    return JSONResponse({
        "ok": True,
        "guild_id": gid,
        "user_id": uid,
        "name": user.get("global_name") or user.get("username") or "플레이어",
        "xp": int(st.get("xp", 0)),
        "seeds_note": "게임 내 씨앗은 클라이언트 전용",
        "shop": catalog,
        "owned": {
            "baits": st.get("baits") or {},
            "inventory": st.get("inventory") or {},
        },
        "sell_prices": cfg.get("cooking_prices") or {},
        "inventory_list": _mg_inventory_prices(u, cfg),
        "plot": _plot_payload(u),
        "dungeon_kills": int(u.get("dungeon_kills", 0) or 0),
        "hp": {"cur": _mg_current_hp(u), "max": _mg_player_hp(u)},
        "level": int(u.get("level", 1) or 1),
        "potions": {
            "catalog": cfg.get("potions") or {},
            "item_key": str(cfg.get("potion_item_key") or "🧪 회복 물약"),
            "owned": ((u.get("inventory") or {}).get(
                str(cfg.get("potion_item_key") or "🧪 회복 물약"), {}) or {}),
        },
        "stamina": {"cur": _mg_get_st(u), "max": _mg_max_st(u),
                    "refill_cost": int(cfg.get("stamina_refill_cost", 12000))},
        "farm": _farm_payload(u),
        "skills": _skills_summary_safe(u),
        "gather": _gather_payload(u, "town"),
        "mine": _gather_payload(u, "1"),
        "last_sale": ({k: v for k, v in (u.get("_mg_last_sale") or {}).items() if k != "items"}
                      if isinstance(u.get("_mg_last_sale"), dict) else None),
        "strengthen": {
            "rod_level": int(st.get("rod_level", 0) or 0),
            "weapon_level": int(st.get("strengthen_level", 0) or 0),
            "rod_band": _mg_band(cfg.get("rod_upgrades") or {}, int(st.get("rod_level", 0) or 0)),
            "weapon_band": _mg_band(cfg.get("weapon_upgrades") or {}, int(st.get("strengthen_level", 0) or 0)),
            "rod_name": MINIGAME_ROD_NAMES.get(int(st.get("rod_level", 0) or 0), "낚시대"),
        },
        "cooking": {
            "recipes": cfg.get("cooking_recipes") or [],
            "cost": int(cfg.get("combine_cost", 1000)),
        },
        "fishing": {
            "spots": cfg.get("fishing_stamina_cost") and [
                {"id": k, "name": v.get("name", k), "cost": v.get("cost", 0)}
                for k, v in MINIGAME_SPOTS.items()] or [],
            "bait": st.get("equipped_bait") or "worm",
        },
    })
