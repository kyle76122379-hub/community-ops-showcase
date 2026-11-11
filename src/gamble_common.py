# systems/gamble/common.py
"""도박 게임 공통 로직 (EXP 처리 / 설정 검증 / 쿨타임 / 공용 임베드)."""

from __future__ import annotations

import time

import discord

try:  # 봇 루트에서 실행될 때
    from db import db
except ImportError:  # 패키지 형태로 실행될 때
    from core.db import db

from core.gamble_settings import GAME_DEFS, get_game

CURRENCY = "EXP"


def fmt(amount) -> str:
    return f"{int(amount):,}"


def user_xp(user_id) -> int:
    return int(db.get_user(user_id).get("xp", 0))


def add_xp(user_id, amount: int) -> int:
    data = db.get_user(user_id)
    data["xp"] = max(0, int(data.get("xp", 0)) + int(amount))
    db.data["users"][str(user_id)] = data
    return int(data["xp"])


def cooldown_left(guild_id, user_id, game_key: str) -> float:
    cfg = get_game(guild_id, game_key)
    seconds = int(cfg.get("cooldown", 0))
    if seconds <= 0:
        return 0.0
    key = f"cd:{guild_id}:{user_id}:{game_key}"
    data = db.data["economy"].get(key) or {}
    last = float(data.get("ts", 0) or 0)
    return max(0.0, seconds - (time.time() - last))


def touch_cooldown(guild_id, user_id, game_key: str) -> None:
    key = f"cd:{guild_id}:{user_id}:{game_key}"
    db.data["economy"][key] = {"ts": time.time()}


def check_bet(guild_id, user_id, game_key: str, amount: int):
    """배팅 가능 여부를 검사한다. (ok, 오류메시지)"""
    cfg = get_game(guild_id, game_key)
    amount = int(amount)

    if amount <= 0:
        return False, "❌ 배팅 금액은 **1 EXP** 이상이어야 합니다."

    min_bet = int(cfg.get("min_bet", 0) or 0)
    max_bet = int(cfg.get("max_bet", 0) or 0)
    if min_bet > 0 and amount < min_bet:
        return False, f"❌ 최소 배팅 금액은 **{fmt(min_bet)} {CURRENCY}**입니다."
    if max_bet > 0 and amount > max_bet:
        return False, f"❌ 최대 배팅 금액은 **{fmt(max_bet)} {CURRENCY}**입니다."

    balance = user_xp(user_id)
    if balance < amount:
        return False, f"❌ {CURRENCY}가 부족합니다. (보유: **{fmt(balance)} {CURRENCY}**)"

    left = cooldown_left(guild_id, user_id, game_key)
    if left > 0:
        return False, f"⏳ 아직 쿨타임이 **{int(left) + 1}초** 남았습니다."

    return True, ""


def take_bet(guild_id, user_id, game_key: str, amount: int):
    """검사 후 배팅금을 차감한다. (ok, 오류메시지)"""
    ok, message = check_bet(guild_id, user_id, game_key, amount)
    if not ok:
        return False, message
    add_xp(user_id, -int(amount))
    touch_cooldown(guild_id, user_id, game_key)
    return True, ""


def mode_label(game_key: str) -> str:
    return "PVP" if GAME_DEFS[game_key]["mode"] == "pvp" else "PVBOT"


def payout_after_fee(pot: int, fee_percent: float) -> int:
    fee = max(0.0, min(50.0, float(fee_percent)))
    return int(round(pot * (1 - fee / 100)))


def result_embed(title: str, description: str, color: int) -> discord.Embed:
    embed = discord.Embed(title=title, description=description, color=color)
    embed.set_footer(text="도박은 여가 활동입니다. 과도한 배팅은 삼가주세요.")
    return embed


def balance_embed(user, game_key: str, amount: int, extra: str = "") -> discord.Embed:
    embed = discord.Embed(
        title=f"{user.display_name} 님의 {GAME_DEFS[game_key]['label']}",
        description=f"💵 보유 {CURRENCY}: **{fmt(user_xp(user.id))}**\n🎫 배팅금: **{fmt(amount)} {CURRENCY}**",
        color=0x5865F2,
    )
    if extra:
        embed.add_field(name="안내", value=extra, inline=False)
    return embed
