# core/gamble_settings.py
"""도박(미니게임) 설정 스키마.

웹 대시보드(web)와 디스코드 봇(systems/gamble)이 동일한 기본값과 검증 규칙을
사용하도록 만든 단일 소스 모듈이다.

저장 위치:
    db.data["guilds"][guild_id]["gamble"]["games"][game_key] = {...}
"""

from __future__ import annotations

MAX_XP = 10 ** 12

# 돌림판 기본 세그먼트 배수 (합 5.5 / 6칸 = 기대 수익률 91.7% ≈ 92%)
DEFAULT_WHEEL_SEGMENTS = [2.0, 2.0, 1.0, 0.5, 0.0, 0.0]

# 각 게임의 기본값과 허용 범위.
# ranges: key -> (최소, 최대)  |  types: key -> "int" | "float"
GAME_DEFS = {
    "odd_even": {
        "label": "홀짝",
        "mode": "pvp",
        "defaults": {"fee": 3, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"fee": (0, 50), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"fee": "int", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "dice": {
        "label": "주사위",
        "mode": "pvp",
        "defaults": {"fee": 3, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"fee": (0, 50), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"fee": "int", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "baskin31": {
        "label": "베스킨라빈스31",
        "mode": "pvp",
        "defaults": {"fee": 3, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"fee": (0, 50), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"fee": "int", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "blessing": {
        "label": "축복권",
        "mode": "bot",
        "defaults": {"win_mult": 2, "win_chance": 0.47, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"win_mult": (1, 100), "win_chance": (0.01, 0.99), "cooldown": (0, 86400),
                   "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"win_mult": "float", "win_chance": "float", "cooldown": "int",
                  "min_bet": "int", "max_bet": "int"},
    },
    "slots": {
        "label": "슬롯머신",
        "mode": "bot",
        "defaults": {"win_mult": 2, "win_chance": 0.47, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"win_mult": (1, 100), "win_chance": (0.01, 0.99), "cooldown": (0, 86400),
                   "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"win_mult": "float", "win_chance": "float", "cooldown": "int",
                  "min_bet": "int", "max_bet": "int"},
    },
    "wheel": {
        "label": "돌림판",
        "mode": "bot",
        "defaults": {"segments": list(DEFAULT_WHEEL_SEGMENTS), "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "mines": {
        "label": "지뢰찾기",
        "mode": "bot",
        "defaults": {"mines": 4, "step": 0.2, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"mines": (1, 19), "step": (0, 10), "cooldown": (0, 86400),
                   "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"mines": "int", "step": "float", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "highlow": {
        "label": "하이로우",
        "mode": "bot",
        "defaults": {"step": 0.35, "max_rounds": 15, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"step": (0, 10), "max_rounds": (1, 100), "cooldown": (0, 86400),
                   "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"step": "float", "max_rounds": "int", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "blackjack": {
        "label": "블랙잭",
        "mode": "bot",
        "defaults": {"win_mult": 2, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"win_mult": (1, 100), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"win_mult": "float", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "tower": {
        "label": "타워",
        "mode": "bot",
        "defaults": {"floors": 8, "traps": 1, "step": 0.43, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"floors": (1, 20), "traps": (1, 2), "step": (0, 10), "cooldown": (0, 86400),
                   "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"floors": "int", "traps": "int", "step": "float", "cooldown": "int",
                  "min_bet": "int", "max_bet": "int"},
    },
    "horse": {
        "label": "경마",
        "mode": "bot",
        "defaults": {"horses": 5, "win_mult": 4, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"horses": (2, 10), "win_mult": (1, 100), "cooldown": (0, 86400),
                   "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"horses": "int", "win_mult": "float", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "bomb": {
        "label": "폭탄해체",
        "mode": "bot",
        "defaults": {"max_tries": 6, "cooldown": 0},
        "ranges": {"max_tries": (1, 20), "cooldown": (0, 86400)},
        "types": {"max_tries": "int", "cooldown": "int"},
    },
    "russian": {
        "label": "리시안셔츠",
        "mode": "pvp",
        "defaults": {"fee": 3, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"fee": (0, 50), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"fee": "int", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "indian": {
        "label": "인디언포커",
        "mode": "pvp",
        "defaults": {"fee": 3, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"fee": (0, 50), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"fee": "int", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "ladder": {
        "label": "사다리",
        "mode": "bot",
        "defaults": {"fee": 0, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"fee": (0, 50), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"fee": "int", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "baccarat": {
        "label": "바카라",
        "mode": "bot",
        "defaults": {"fee": 0, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"fee": (0, 50), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"fee": "int", "cooldown": "int", "min_bet": "int", "max_bet": "int"},
    },
    "tictactoe": {
        "label": "틱택토",
        "mode": "pvp",
        "defaults": {"fee": 3, "cooldown": 0, "min_bet": 0, "max_bet": 0},
        "ranges": {"fee": (0, 50), "cooldown": (0, 86400), "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
        "types": {"fee": "int", "cooldown": "int", "min_bet": (0, MAX_XP), "max_bet": (0, MAX_XP)},
    },
}

GAME_ORDER = [
    "odd_even", "dice", "baskin31",
    "blessing", "slots", "wheel",
    "mines", "highlow", "blackjack",
    "tower", "horse", "bomb",
    "russian", "indian", "tictactoe",
    "ladder", "baccarat",
]


def default_gamble() -> dict:
    """모든 게임의 기본 설정 묶음."""
    return {"games": {key: dict(defn["defaults"]) for key, defn in GAME_DEFS.items()}}


def _to_type(kind: str, value):
    if kind == "int":
        return int(round(float(value)))
    return float(value)


def _clamp(value, low, high):
    if value < low:
        return low
    if value > high:
        return high
    return value


def _normalize_segments(raw) -> list:
    if not isinstance(raw, (list, tuple)):
        return list(DEFAULT_WHEEL_SEGMENTS)
    segments = []
    for item in raw:
        try:
            value = float(item)
        except (TypeError, ValueError):
            continue
        segments.append(round(_clamp(value, 0.0, 100.0), 2))
    if len(segments) < 2:
        return list(DEFAULT_WHEEL_SEGMENTS)
    if len(segments) > 12:
        segments = segments[:12]
    return segments


def normalize_game(game_key: str, raw) -> dict:
    """단일 게임 설정을 기본값과 병합하고 타입/범위를 보정한다."""
    defn = GAME_DEFS[game_key]
    data = dict(defn["defaults"])
    if isinstance(raw, dict):
        for key, kind in defn["types"].items():
            if key not in raw:
                continue
            try:
                value = _to_type(kind, raw[key])
            except (TypeError, ValueError):
                continue
            low, high = defn["ranges"][key]
            data[key] = _clamp(value, low, high)
        if game_key == "wheel" and "segments" in raw:
            data["segments"] = _normalize_segments(raw["segments"])

    # 최소 배팅이 최대 배팅보다 크면 최대값에 맞춘다. (0 = 제한 없음)
    if data.get("max_bet", 0) > 0 and data.get("min_bet", 0) > data["max_bet"]:
        data["min_bet"] = data["max_bet"]

    # 승리 확률은 소수점 4자리로 정리
    if "win_chance" in data:
        data["win_chance"] = round(float(data["win_chance"]), 4)
    return data


def normalize_gamble(raw) -> dict:
    """길드 단위 도박 설정 전체를 기본값과 병합한다."""
    result = default_gamble()
    if isinstance(raw, dict):
        games = raw.get("games")
        if isinstance(games, dict):
            for key in GAME_DEFS:
                if key in games:
                    result["games"][key] = normalize_game(key, games[key])
    return result


def get_gamble(guild_id) -> dict:
    """DB에서 길드 도박 설정을 읽어온다. (없으면 기본값)"""
    try:
        from core.db import db
    except ImportError:  # 봇 내부에서 core 없이 import 되는 경우 방어
        from db import db

    guild = db.data.get("guilds", {}).get(str(guild_id)) or {}
    return normalize_gamble(guild.get("gamble"))


def get_game(guild_id, game_key: str) -> dict:
    return get_gamble(guild_id)["games"][game_key]


def save_game(guild_id, game_key: str, patch) -> dict:
    """게임 설정 일부를 저장하고 정규화된 전체 설정을 돌려준다."""
    try:
        from core.db import db
    except ImportError:
        from db import db

    gid = str(guild_id)
    guild = db.data.get("guilds", {}).get(gid) or {}
    current = normalize_gamble(guild.get("gamble"))
    merged = dict(current["games"][game_key])
    if isinstance(patch, dict):
        merged.update(patch)
    current["games"][game_key] = normalize_game(game_key, merged)

    guild = dict(guild)
    guild["gamble"] = current
    db.data["guilds"][gid] = guild
    return current["games"][game_key]


def expected_return(game_key: str, cfg: dict) -> float:
    """기대 수익률(0~1). 웹 카드의 '기대 수익률' 표시와 동일한 계산식."""
    if game_key in ("blessing", "slots"):
        return float(cfg.get("win_chance", 0.47)) * float(cfg.get("win_mult", 2))
    if game_key == "wheel":
        segments = cfg.get("segments") or DEFAULT_WHEEL_SEGMENTS
        return sum(segments) / max(1, len(segments))
    if game_key == "horse":
        return float(cfg.get("win_mult", 4)) / max(1, int(cfg.get("horses", 5)))
    return 0.0
