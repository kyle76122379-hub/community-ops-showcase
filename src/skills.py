"""스타듀밸리식 5개 숙련도 시스템 — 농사·채집·낚시·채광·전투.

원본(Stardew Valley) 규칙:
- 숙련도는 5종이며 각각 10레벨까지 오른다.
- 레벨 요구 경험치는 고정표다(스킬별 동일).
- 레벨 5와 10에서 직업(Profession) 2개 중 하나를 고른다.
- 숙련도 레벨은 해당 도구의 효율(실행력 소모)을 낮춘다.

레벨업 XP 표(원본 그대로, 해당 레벨 도달에 필요한 증가분):
  1:100  2:280  3:390  4:530  5:850
  6:1150 7:1500 8:2100 9:3100 10:5000   (누적 15000)

DB·웹에 의존하지 않는 순수 로직만 담는다(단위 테스트 가능).
"""
SKILLS = ("farming", "foraging", "fishing", "mining", "combat")

SKILL_KO = {
    "farming": "농사",
    "foraging": "채집",
    "fishing": "낚시",
    "mining": "채광",
    "combat": "전투",
}

MAX_LEVEL = 10

# 각 레벨에 '도달'하기 위해 그 레벨에서 추가로 필요한 XP (원본 표)
LEVEL_XP = {
    1: 100, 2: 280, 3: 390, 4: 530, 5: 850,
    6: 1150, 7: 1500, 8: 2100, 9: 3100, 10: 5000,
}

# 누적 XP (레벨 L 도달에 필요한 총량)
CUMULATIVE = {}
_total = 0
for _lv in range(1, MAX_LEVEL + 1):
    _total += LEVEL_XP[_lv]
    CUMULATIVE[_lv] = _total   # Lv1=100, Lv2=380, ... Lv10=15000

# 직업 선택 — 레벨 5/10 에서 둘 중 하나
PROFESSIONS = {
    "farming": {
        5: [("tiller", "농부", "작물 판매가 +10%"),
            ("rancher", "목장주", "동물 생산품 가치 +20%")],
        10: [("artisan", "장인", "가공품 가치 +40%"),
             ("agriculturist", "농업학자", "작물 성장 속도 +10%")],
    },
    "foraging": {
        5: [("forester", "임업인", "목재 가치 +50%"),
            ("gatherer", "채집가", "채집 시 20% 확률로 2개")],
        10: [("lumberjack", "벌목꾼", "나무에서 목재 추가 획득"),
             ("botanist", "식물학자", "채집품 전부 최상급 품질")],
    },
    "fishing": {
        5: [("fisher", "어부", "낚시 판매가 +25%"),
            ("trapper", "덫사냥꾼", "통발 자원 절약")],
        10: [("angler", "낚시꾼", "물고기 판매가 +50%"),
             ("pirate", "해적", "보물상자 발견 확률 2배")],
    },
    "mining": {
        5: [("miner", "광부", "광물 +1개 추가 획득"),
            ("geologist", "지질학자", "보석 발견 확률 증가")],
        10: [("blacksmith", "대장장이", "광물 판매가 +50%"),
             ("excavator", "발굴가", "유물 발견 확률 2배")],
    },
    "combat": {
        5: [("fighter", "전사", "공격력 +10%, 최대 HP +15"),
            ("scout", "정찰병", "치명타 확률 +50%")],
        10: [("brute", "투사", "공격력 +15%"),
             ("defender", "수호자", "최대 HP +25")],
    },
}


def empty_skills() -> dict:
    """모든 숙련도를 0레벨/0XP로 초기화한다."""
    return {s: {"xp": 0, "level": 0, "professions": []} for s in SKILLS}


def normalize(skills) -> dict:
    """저장된 숙련도 dict를 안전한 형태로 보정한다(누락/손상 대비)."""
    out = empty_skills()
    if not isinstance(skills, dict):
        return out
    for s in SKILLS:
        cur = skills.get(s)
        if not isinstance(cur, dict):
            continue
        try:
            xp = max(0, int(cur.get("xp", 0) or 0))
        except (TypeError, ValueError):
            xp = 0
        profs = cur.get("professions")
        if not isinstance(profs, list):
            profs = []
        out[s] = {
            "xp": xp,
            "level": level_for_xp(xp),
            "professions": [str(p) for p in profs if isinstance(p, str)],
        }
    return out


def level_for_xp(xp: int) -> int:
    """누적 XP 로 현재 레벨(0~10)을 구한다."""
    try:
        xp = int(xp)
    except (TypeError, ValueError):
        return 0
    lv = 0
    for need_level in range(1, MAX_LEVEL + 1):
        if xp >= CUMULATIVE[need_level]:
            lv = need_level
        else:
            break
    return lv


def xp_to_next(xp: int) -> int:
    """다음 레벨까지 남은 XP (만렙이면 0)."""
    lv = level_for_xp(xp)
    if lv >= MAX_LEVEL:
        return 0
    try:
        xp = int(xp)
    except (TypeError, ValueError):
        xp = 0
    return max(0, CUMULATIVE[lv + 1] - xp)


def level_progress(xp: int) -> dict:
    """레벨 진행도 — 현재 레벨 구간 내 진행률."""
    lv = level_for_xp(xp)
    try:
        xp = int(xp)
    except (TypeError, ValueError):
        xp = 0
    if lv >= MAX_LEVEL:
        return {"level": MAX_LEVEL, "in_level": xp - CUMULATIVE[MAX_LEVEL],
                "need": 0, "ratio": 1.0}
    base = CUMULATIVE[lv] if lv > 0 else 0
    need = CUMULATIVE[lv + 1] - base
    in_level = xp - base
    ratio = (float(in_level) / float(need)) if need > 0 else 0.0
    return {"level": lv, "in_level": in_level, "need": need,
            "ratio": max(0.0, min(1.0, ratio))}


def add_xp(skills: dict, skill: str, amount: int) -> dict:
    """숙련도 XP를 더한다.

    원본 dict를 그 자리에서 수정한다(in-place). normalize()가 새 dict를
    만들기 때문에 반환값만 쓰면 XP가 유실되므로, 호출자의 dict를 직접 갱신한다.
    반환: {"ok", "level_up": [...], "level": int, "xp": int}
    """
    if not isinstance(skills, dict):
        return {"ok": False, "error": "숙련도 데이터가 dict가 아닙니다.", "level_up": []}
    if skill not in SKILLS:
        return {"ok": False, "error": f"알 수 없는 숙련도: {skill}", "level_up": []}
    # 누락된 항목을 보정해 원본에 반영(이후 in-place 수정 가능)
    for k, v in normalize(skills).items():
        if k not in skills or not isinstance(skills.get(k), dict):
            skills[k] = v
        else:
            skills[k]["xp"] = v["xp"]
            skills[k]["level"] = v["level"]
            skills[k]["professions"] = v["professions"]

    try:
        gain = int(amount)
    except (TypeError, ValueError):
        gain = 0
    cur = skills[skill]
    if gain <= 0:
        return {"ok": True, "level_up": [], "level": int(cur["level"]),
                "xp": int(cur["xp"]), "skill": skill}

    before = int(cur["level"])
    cur["xp"] = int(cur["xp"]) + gain
    after = level_for_xp(cur["xp"])
    cur["level"] = after
    ups = list(range(before + 1, after + 1))
    return {"ok": True, "level_up": ups, "level": after, "xp": cur["xp"],
            "skill": skill}


def profession_choices(skill: str, level: int) -> list:
    """해당 레벨에서 고를 수 있는 직업 목록."""
    table = PROFESSIONS.get(skill) or {}
    opts = table.get(level) or []
    return [{"id": k, "name": n, "desc": d} for k, n, d in opts]


def choose_profession(skills: dict, skill: str, level: int, prof_id: str) -> dict:
    """레벨 5/10 직업을 고른다. 이미 골랐으면 거부. 원본 dict를 in-place 수정."""
    if not isinstance(skills, dict):
        return {"ok": False, "error": "숙련도 데이터가 dict가 아닙니다."}
    if skill not in SKILLS:
        return {"ok": False, "error": "알 수 없는 숙련도입니다."}
    if level not in (5, 10):
        return {"ok": False, "error": "직업은 5레벨과 10레벨에서만 선택합니다."}
    norm = normalize(skills)
    if skill not in skills or not isinstance(skills.get(skill), dict):
        skills[skill] = norm[skill]
    elif "professions" not in skills[skill] or not isinstance(skills[skill]["professions"], list):
        skills[skill]["professions"] = norm[skill]["professions"]
    cur = skills[skill]
    cur_lv = level_for_xp(cur.get("xp", 0))
    if cur_lv < level:
        return {"ok": False, "error": f"{level}레벨에 도달해야 합니다. (현재 {cur_lv})"}
    opts = {o["id"]: o for o in profession_choices(skill, level)}
    if prof_id not in opts:
        return {"ok": False, "error": "존재하지 않는 직업입니다."}
    already = {o["id"] for o in profession_choices(skill, level)} & set(cur["professions"])
    if already:
        return {"ok": False, "error": "이미 이 레벨의 직업을 선택했습니다."}
    cur["professions"] = list(cur["professions"]) + [prof_id]
    return {"ok": True, "profession": opts[prof_id], "skill": skill, "level": level}


def tool_energy_cost(skill: str, level: int, base_cost: int = 2) -> int:
    """숙련도 레벨이 높을수록 도구 실행력 소모가 줄어든다(최소 1)."""
    try:
        lv = max(0, min(MAX_LEVEL, int(level)))
        base = max(1, int(base_cost))
    except (TypeError, ValueError):
        return max(1, base_cost)
    # 레벨당 5% 감소, 최대 50% 감소
    factor = 1.0 - min(0.5, lv * 0.05)
    return max(1, int(round(base * factor)))


def sell_bonus(skill: str, professions: list) -> float:
    """직업에 따른 판매가 배율(1.0 = 원본 가격)."""
    profs = set(professions or [])
    if skill == "farming":
        if "artisan" in profs:
            return 1.4
        if "tiller" in profs:
            return 1.1
    if skill == "fishing":
        if "angler" in profs:
            return 1.5
        if "fisher" in profs:
            return 1.25
    if skill == "mining":
        if "blacksmith" in profs:
            return 1.5
    if skill == "foraging":
        if "forester" in profs:
            return 1.5
    return 1.0


def summary(skills) -> dict:
    """UI 표시용 요약 — 각 숙련도의 레벨/진행도."""
    skills = normalize(skills)
    out = {}
    for s in SKILLS:
        cur = skills[s]
        prog = level_progress(cur["xp"])
        out[s] = {
            "name": SKILL_KO[s],
            "level": cur["level"],
            "xp": cur["xp"],
            "in_level": prog["in_level"],
            "need": prog["need"],
            "ratio": round(prog["ratio"], 3),
            "professions": cur["professions"],
            "choices": (profession_choices(s, 5) if cur["level"] >= 5 and
                        not _has_level_prof(s, cur, 5) else
                        profession_choices(s, 10) if cur["level"] >= 10 and
                        not _has_level_prof(s, cur, 10) else []),
        }
    return out


def _has_level_prof(skill: str, cur: dict, level: int) -> bool:
    """해당 레벨 직업을 이미 골랐는지."""
    opts = {o["id"] for o in profession_choices(skill, level)}
    return bool(opts & set(cur.get("professions") or []))
