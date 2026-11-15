PLOT_COST_BUY = 4000
PLOT_COST_BUILD = 3000
PLOT_SLOTS = 4
PLOT_BUILD_SECONDS = 180      # 건설 소요 시간(초) — 즉시 완성 아님


@app.post("/api/game/plot/buy")
async def api_game_plot_buy(user=Depends(current_user)):
    """목수에게 영토를 산다 — 유저당 1칸, 슬롯은 uid 로 고정 배정."""
    uid = str(user.get("id"))

    def _do(u: dict):
        cur = u.get("game_plot")
        if isinstance(cur, dict) and cur.get("slot") is not None:
            return {"ok": False, "error": "이미 영토가 있습니다."}
        if int(u.get("xp", 0)) < PLOT_COST_BUY:
            return {"ok": False, "error": f"XP가 부족합니다. (필요 {PLOT_COST_BUY:,} XP)"}
        try:
            slot = int(uid) % PLOT_SLOTS
        except (TypeError, ValueError):
            slot = 0
        u["xp"] = int(u["xp"]) - PLOT_COST_BUY
        u["game_plot"] = {"slot": slot, "built": False}
        return {"ok": True, "plot": u["game_plot"], "xp": int(u["xp"])}

    res, ok = _mg_mutate(uid, _do)
    return JSONResponse({**res, "ok": bool(res.get("ok")) and ok})


@app.post("/api/game/plot/quest/start")
async def api_game_plot_quest_start(user=Depends(current_user)):
    """목수에게 집 짓기 퀘스트를 받는다."""
    uid = str(user.get("id"))

    def _do(u: dict):
        cur = u.get("game_plot")
        if not isinstance(cur, dict) or cur.get("slot") is None:
            return {"ok": False, "error": "먼저 영토를 구매하세요."}
        if cur.get("built"):
            return {"ok": False, "error": "이미 집이 있습니다."}
        if int(cur.get("quest", 0)) >= 1:
            return {"ok": False, "error": "이미 퀘스트를 받았습니다."}
        cur["quest"] = 1
        u["game_plot"] = cur
        return {"ok": True, "plot": cur}

    res, ok = _mg_mutate(uid, _do)
    return JSONResponse({**res, "ok": bool(res.get("ok")) and ok})


@app.post("/api/game/plot/quest/claim")
async def api_game_plot_quest_claim(user=Depends(current_user)):
    """던전 몬스터 처치를 확인하고 건설 허가를 준다."""
    uid = str(user.get("id"))

    def _do(u: dict):
        cur = u.get("game_plot")
        if not isinstance(cur, dict) or cur.get("slot") is None:
            return {"ok": False, "error": "먼저 영토를 구매하세요."}
        if int(cur.get("quest", 0)) < 1:
            return {"ok": False, "error": "퀘스트를 먼저 받으세요."}
        if int(cur.get("quest", 0)) >= 2:
            return {"ok": False, "error": "이미 완료했습니다."}
        if int(u.get("dungeon_kills", 0) or 0) < 1:
            return {"ok": False, "error": "던전 몬스터를 1마리 처치해야 합니다."}
        cur["quest"] = 2
        u["game_plot"] = cur
        return {"ok": True, "plot": cur}

    res, ok = _mg_mutate(uid, _do)
    return JSONResponse({**res, "ok": bool(res.get("ok")) and ok})


@app.post("/api/game/plot/build")
async def api_game_plot_build(user=Depends(current_user)):
    """목수가 내 영토에 집을 지어준다."""
    uid = str(user.get("id"))

    def _do(u: dict):
        cur = u.get("game_plot")
        if not isinstance(cur, dict) or cur.get("slot") is None:
            return {"ok": False, "error": "먼저 영토를 구매하세요."}
        if cur.get("built"):
            return {"ok": False, "error": "이미 집이 있습니다."}
        if int(cur.get("quest", 0)) < 2:
            return {"ok": False, "error": "목수 퀘스트를 먼저 완료하세요."}
        if int(u.get("xp", 0)) < PLOT_COST_BUILD:
            return {"ok": False, "error": f"XP가 부족합니다. (필요 {PLOT_COST_BUILD:,} XP)"}
        u["xp"] = int(u["xp"]) - PLOT_COST_BUILD
        cur["built"] = False
        cur["building_started"] = time.time()
        cur["build_seconds"] = PLOT_BUILD_SECONDS
        u["game_plot"] = cur
        return {"ok": True, "plot": cur, "xp": int(u["xp"])}

    res, ok = _mg_mutate(uid, _do)
    return JSONResponse({**res, "ok": bool(res.get("ok")) and ok})


@app.get("/api/game/ping")
async def api_game_ping():
