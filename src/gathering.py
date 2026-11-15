"""스타듀밸리식 채집(foraging)·채광(mining) 노드 시스템.

원본(Stardew Valley) 규칙을 따른다:
- 채집 노드(약초·버섯·산딸기·꽃)는 맵에 고정 생성되고 며칠마다 리스폰된다.
- 채광 노드(돌·광맥)는 곡괭이로 캐며, 캘 때마다 광물이 나온다.
- 노드마다 필요한 곡괭이 레벨이 있고, 레벨이 낮으면 캘 수 없다.
- 채집/채광 행동은 실행력(에너지)을 소모한다.
- 숙련도 레벨이 오르면 실행력 소모가 줄고, 드롭이 좋아진다.

DB·웹에 의존하지 않는 순수 로직만 담는다(단위 테스트 가능).
"""
import random

# ── 노드 종류 ──
NODE_FORAGE = "forage"     # 채집 (약초/버섯/열매)
NODE_ROCK = "rock"         # 채광 (돌/광맥)

# 채집 노드 정의 — id: (이름, 판매가, 필요 레벨, 무게)
FORAGE_NODES = {
    "wild_herb": ("🌾 들풀", 15, 0, 30),
    "daffodil": ("🌼 수선화", 30, 1, 20),
    "leek": ("🥬 야생 부추", 60, 1, 16),
    "morel": ("🍄 곰보버섯", 150, 2, 10),
    "berry": ("🫐 야생 산딸기", 75, 2, 18),
    "hazelnut": ("🌰 개암", 90, 3, 12),
    "crystal_fruit": ("💠 수정 열매", 450, 6, 5),
    "fiddlehead": ("🌿 고사리 새순", 90, 3, 12),
    "purple_mushroom": ("🍄 보라 버섯", 250, 4, 8),
    "spice_berry": ("🌶️ 향신료 열매", 80, 2, 14),
}

# 광물(채광) 정의 — id: (이름, 판매가, 필요 곡괭이 레벨, 무게, 드롭 수 범위)
MINE_NODES = {
    "stone": ("🪨 돌", 2, 0, 30, (1, 3)),
    "coal": ("⚫ 석탄", 15, 0, 18, (1, 2)),
    "copper": ("🟠 구리 광석", 30, 1, 20, (1, 3)),
    "iron": ("⚙️ 철 광석", 60, 2, 16, (1, 2)),
    "gold": ("🟡 금 광석", 150, 3, 10, (1, 2)),
    "quartz": ("💠 수정", 100, 2, 8, (1, 1)),
    "amethyst": ("🟣 자수정", 200, 3, 6, (1, 1)),
    "ruby": ("🔴 루비", 350, 5, 4, (1, 1)),
    "emerald": ("💚 에메랄드", 400, 5, 4, (1, 1)),
    "diamond": ("💎 다이아몬드", 750, 8, 2, (1, 1)),
    "iridium": ("🔷 이리듐 광석", 900, 9, 2, (1, 1)),
}

# 던전별 노드 구성 — 던전 번호: {forage: [(node, weight)], rock: [(node, weight)]}
DUNGEON_NODES = {
    1: {
        "forage": [("wild_herb", 35), ("daffodil", 25), ("leek", 20),
                   ("morel", 10), ("berry", 10)],
        "rock": [("stone", 50), ("coal", 25), ("copper", 18), ("quartz", 7)],
    },
    2: {
        "forage": [("morel", 20), ("berry", 20), ("hazelnut", 20),
                   ("fiddlehead", 20), ("purple_mushroom", 12), ("spice_berry", 8)],
        "rock": [("stone", 25), ("coal", 15), ("copper", 18), ("iron", 20),
                 ("gold", 12), ("quartz", 6), ("amethyst", 4)],
    },
    3: {
        "forage": [("purple_mushroom", 25), ("crystal_fruit", 20),
                   ("hazelnut", 20), ("fiddlehead", 20), ("morel", 15)],
        "rock": [("iron", 15), ("gold", 22), ("amethyst", 20), ("ruby", 15),
                 ("emerald", 14), ("diamond", 9), ("iridium", 5)],
    },
}


def empty_nodes() -> dict:
    """노드 상태 초기화 — nodes[던전번호][좌표키] = {...}"""
    return {"nodes": {}, "respawn_day": 0}


def _pick(weighted: list, rng=None) -> str:
    """가중치 목록에서 하나를 뽑는다."""
    r = rng if rng is not None else random
    total = sum(w for _k, w in weighted)
    if total <= 0:
        return weighted[0][0]
    roll = r.uniform(0, total)
    upto = 0.0
    for key, weight in weighted:
        upto += weight
        if roll <= upto:
            return key
    return weighted[-1][0]


def generate_dungeon_nodes(dungeon_id: int, day: int, count: int = 8,
                           rng=None) -> list:
    """던전에 채집/채광 노드를 count개 생성한다(좌표·종류·남은 횟수)."""
    conf = DUNGEON_NODES.get(int(dungeon_id))
    if not conf:
        return []
    r = rng if rng is not None else random
    out = []
    used = set()
    for i in range(count):
        is_rock = (i % 2 == 1)          # 절반 채집, 절반 채광
        table = conf["rock"] if is_rock else conf["forage"]
        node_id = _pick(table, r)
        kind = NODE_ROCK if is_rock else NODE_FORAGE
        info = (MINE_NODES if kind == NODE_ROCK else FORAGE_NODES)[node_id]
        # 겹치지 않는 좌표(던전 11×9 그리드 안)
        for _try in range(40):
            x = r.randint(1, 9)
            y = r.randint(1, 7)
            if (x, y) not in used:
                used.add((x, y))
                break
        else:
            continue
        out.append({
            "id": node_id,
            "kind": kind,
            "name": info[0],
            "x": x,
            "y": y,
            "hits": 1 if kind == NODE_FORAGE else int(r.randint(2, 4)),
            "day": int(day),
        })
    return out


def node_def(node_id: str, kind: str) -> dict:
    """노드 정의를 dict로 돌려준다."""
    table = MINE_NODES if kind == NODE_ROCK else FORAGE_NODES
    info = table.get(node_id)
    if not info:
        return {}
    if kind == NODE_ROCK:
        name, sell, req_lv, weight, (dmin, dmax) = info
        return {"id": node_id, "kind": kind, "name": name, "sell": sell,
                "req_level": req_lv, "weight": weight, "drop_min": dmin,
                "drop_max": dmax}
    name, sell, req_lv, weight = info
    return {"id": node_id, "kind": kind, "name": name, "sell": sell,
            "req_level": req_lv, "weight": weight, "drop_min": 1, "drop_max": 1}


def gather(nodes: list, x: int, y: int, kind: str, level: int,
           luck: float = 1.0, rng=None) -> dict:
    """노드 하나를 캔다/딴다.

    반환: {"ok", "item", "count", "depleted", "xp", "error"}
    """
    r = rng if rng is not None else random
    if not isinstance(nodes, list):
        return {"ok": False, "error": "노드 데이터가 없습니다."}
    target = None
    idx = -1
    for i, n in enumerate(nodes):
        if not isinstance(n, dict):
            continue
        if int(n.get("x", -1)) == int(x) and int(n.get("y", -1)) == int(y):
            target = n
            idx = i
            break
    if target is None:
        return {"ok": False, "error": "여기에는 캘 것이 없습니다."}
    if target.get("kind") != kind:
        want = "채광" if target.get("kind") == NODE_ROCK else "채집"
        return {"ok": False, "error": f"이 노드는 {want} 대상입니다."}
    d = node_def(str(target.get("id")), kind)
    if not d:
        return {"ok": False, "error": "알 수 없는 노드입니다."}
    try:
        lv = int(level)
    except (TypeError, ValueError):
        lv = 0
    if lv < int(d["req_level"]):
        skill = "채광" if kind == NODE_ROCK else "채집"
        return {"ok": False,
                "error": f"{skill} 숙련도 {d['req_level']}레벨이 필요합니다. (현재 {lv})"}

    hits = max(0, int(target.get("hits", 1))) - 1
    # 드롭 개수 (행운/레벨 보정)
    dmin, dmax = int(d["drop_min"]), int(d["drop_max"])
    bonus = 1 if (lv >= 5 and r.random() < 0.25) else 0     # 5렙 이상 25% 추가
    cnt = r.randint(dmin, dmax) + bonus
    cnt = max(1, int(cnt * max(0.5, min(2.0, luck))))
    # XP: 채집은 7, 채광은 광물 가치에 비례(스타듀밸리와 유사)
    if kind == NODE_ROCK:
        xp = max(5, int(d["sell"] * 0.15) + 5)
    else:
        xp = max(7, int(d["sell"] * 0.1) + 5)

    out = {
        "ok": True,
        "item": d["name"],
        "node_id": d["id"],
        "count": cnt,
        "xp": xp,
        "sell": d["sell"],
        "depleted": hits <= 0,
    }
    if idx >= 0:
        if hits <= 0:
            nodes.pop(idx)
        else:
            nodes[idx]["hits"] = hits
    return out


def respawn(nodes: list, dungeon_id: int, day: int, count: int = 8,
            rng=None) -> list:
    """하루가 지나면 던전 노드를 새로 채운다(스타듀밸리 채집 리스폰)."""
    fresh = generate_dungeon_nodes(dungeon_id, day, count, rng)
    keep = []
    if isinstance(nodes, list):
        for n in nodes:
            if isinstance(n, dict) and int(n.get("day", -1)) == int(day):
                keep.append(n)
    # 기존 좌표와 겹치지 않게
    used = {(int(n.get("x", -1)), int(n.get("y", -1))) for n in keep}
    merged = list(keep)
    for n in fresh:
        if (n["x"], n["y"]) in used:
            continue
        used.add((n["x"], n["y"]))
        merged.append(n)
    return merged


# ── 마을 채집 노드 (던전 없이도 채집 가능) ──
TOWN_FORAGE_SPOTS = [
    # 광장 주변 (이동하지 않아도 바로 보이도록 중심부 포함)
    (17, 21), (18, 21), (17, 22), (18, 22),
    (9, 20), (9, 21), (31, 20), (31, 21),
    (20, 13), (21, 13), (20, 28), (21, 28),
    # 외곽
    (7, 17), (8, 17), (7, 18), (8, 18),
    (30, 12), (31, 12), (30, 13), (31, 13),
    (12, 33), (13, 33), (12, 34), (13, 34),
]

TOWN_FORAGE_TABLE = [
    ("wild_herb", 40), ("daffodil", 25), ("leek", 18),
    ("berry", 10), ("morel", 7),
]


def generate_town_forage(day: int, rng=None) -> list:
    """마을 채집 노드를 생성한다(고정 좌표, 랜덤 종류)."""
    r = rng if rng is not None else random
    out = []
    for (x, y) in TOWN_FORAGE_SPOTS:
        node_id = _pick(TOWN_FORAGE_TABLE, r)
        info = FORAGE_NODES[node_id]
        out.append({
            "id": node_id,
            "kind": NODE_FORAGE,
            "name": info[0],
            "x": x,
            "y": y,
            "hits": 1,
            "day": int(day),
        })
    return out


def energy_cost(kind: str, level: int, base: int = 2) -> int:
    """채집/채광 실행력 소모 — 레벨이 높으면 감소(최소 1)."""
    try:
        lv = max(0, min(10, int(level)))
        b = max(1, int(base))
    except (TypeError, ValueError):
        return max(1, base if isinstance(base, int) else 2)
    factor = 1.0 - min(0.5, lv * 0.05)
    return max(1, int(round(b * factor)))


def quality_roll(level: int, rng=None) -> str:
    """채집품 품질 — 식물학자 직업이 있으면 전부 최상급(호출측에서 처리)."""
    r = rng if rng is not None else random
    lv = max(0, min(10, int(level or 0)))
    roll = r.random()
    # 레벨이 높을수록 좋은 품질 확률 증가
    gold_p = 0.03 * lv
    silver_p = 0.08 + 0.03 * lv
    if roll < gold_p:
        return "gold"
    if roll < gold_p + silver_p:
        return "silver"
    return "normal"


QUALITY_MULT = {"normal": 1.0, "silver": 1.25, "gold": 1.5, "iridium": 2.0}
