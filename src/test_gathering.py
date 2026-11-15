"""채집·채광 시스템 단위 테스트 — 실행: cd systems && python test_gathering.py"""
import random
import gathering as g


def test_tables():
    assert len(g.FORAGE_NODES) == 10
    assert len(g.MINE_NODES) == 11
    for k, v in g.FORAGE_NODES.items():
        assert len(v) == 4, k
    for k, v in g.MINE_NODES.items():
        assert len(v) == 5, k
        assert v[4][0] <= v[4][1], k
    print("OK node tables (10 forage / 11 mine)")


def test_node_def():
    d = g.node_def("gold", g.NODE_ROCK)
    assert d["name"] == "🟡 금 광석" and d["sell"] == 150 and d["req_level"] == 3
    d = g.node_def("daffodil", g.NODE_FORAGE)
    assert d["name"] == "🌼 수선화" and d["sell"] == 30
    assert g.node_def("nope", g.NODE_ROCK) == {}
    print("OK node_def")


def test_dungeon_nodes():
    rng = random.Random(42)
    for did in (1, 2, 3):
        nodes = g.generate_dungeon_nodes(did, 1, 8, rng)
        assert len(nodes) == 8, did
        coords = {(n["x"], n["y"]) for n in nodes}
        assert len(coords) == 8, "좌표 중복 없음"
        kinds = {n["kind"] for n in nodes}
        assert g.NODE_ROCK in kinds and g.NODE_FORAGE in kinds
        for n in nodes:
            assert 1 <= n["x"] <= 9 and 1 <= n["y"] <= 7
            assert n["hits"] >= 1
    assert g.generate_dungeon_nodes(99, 1, 8, rng) == []
    print("OK generate_dungeon_nodes")


def test_gather_basic():
    rng = random.Random(1)
    nodes = [{"id": "stone", "kind": g.NODE_ROCK, "name": "🪨 돌",
              "x": 3, "y": 3, "hits": 2, "day": 1}]
    r = g.gather(nodes, 3, 3, g.NODE_ROCK, level=5, rng=rng)
    assert r["ok"], r
    assert r["item"] == "🪨 돌"
    assert r["count"] >= 1
    assert r["xp"] >= 5
    assert r["depleted"] is False
    assert len(nodes) == 1 and nodes[0]["hits"] == 1
    # 두 번째 캐면 고갈
    r2 = g.gather(nodes, 3, 3, g.NODE_ROCK, level=5, rng=rng)
    assert r2["ok"] and r2["depleted"] is True
    assert len(nodes) == 0
    print("OK gather basic + deplete")


def test_gather_no_node():
    nodes = [{"id": "stone", "kind": g.NODE_ROCK, "x": 1, "y": 1,
              "hits": 1, "day": 1}]
    r = g.gather(nodes, 9, 9, g.NODE_ROCK, level=5)
    assert r["ok"] is False and "없습니다" in r["error"]
    print("OK gather no node")


def test_gather_wrong_kind():
    nodes = [{"id": "stone", "kind": g.NODE_ROCK, "x": 1, "y": 1,
              "hits": 1, "day": 1}]
    r = g.gather(nodes, 1, 1, g.NODE_FORAGE, level=5)
    assert r["ok"] is False and "채광" in r["error"]
    print("OK gather wrong kind")


def test_gather_level_gate():
    nodes = [{"id": "diamond", "kind": g.NODE_ROCK, "x": 2, "y": 2,
              "hits": 1, "day": 1}]
    r = g.gather(nodes, 2, 2, g.NODE_ROCK, level=3)
    assert r["ok"] is False and "8레벨" in r["error"]
    r = g.gather(nodes, 2, 2, g.NODE_ROCK, level=8)
    assert r["ok"] is True
    print("OK gather level gate")


def test_gather_forage():
    rng = random.Random(7)
    nodes = [{"id": "daffodil", "kind": g.NODE_FORAGE, "x": 4, "y": 4,
              "hits": 1, "day": 1}]
    r = g.gather(nodes, 4, 4, g.NODE_FORAGE, level=1, rng=rng)
    assert r["ok"] and r["item"] == "🌼 수선화"
    assert r["count"] == 1
    assert r["depleted"] is True
    print("OK gather forage")


def test_respawn():
    rng = random.Random(3)
    nodes = g.generate_dungeon_nodes(1, 1, 8, rng)
    before = len(nodes)
    nodes2 = g.respawn([], 1, 2, 8, rng)
    assert len(nodes2) == 8
    assert all(n["day"] == 2 for n in nodes2)
    print(f"OK respawn ({before} -> {len(nodes2)})")


def test_town_forage():
    rng = random.Random(5)
    t = g.generate_town_forage(1, rng)
    assert len(t) == len(g.TOWN_FORAGE_SPOTS)
    coords = {(n["x"], n["y"]) for n in t}
    assert len(coords) == len(t), "마을 좌표 중복 없음"
    for n in t:
        assert n["kind"] == g.NODE_FORAGE
    print(f"OK town forage ({len(t)} spots)")


def test_energy_cost():
    assert g.energy_cost(g.NODE_ROCK, 0, 2) == 2
    assert g.energy_cost(g.NODE_ROCK, 10, 2) == 1
    assert g.energy_cost(g.NODE_FORAGE, 99, 2) == 1
    assert g.energy_cost(g.NODE_ROCK, 0, 4) == 4
    assert g.energy_cost(g.NODE_ROCK, 10, 4) == 2
    print("OK energy_cost")


def test_quality():
    rng = random.Random(11)
    lv0 = [g.quality_roll(0, rng) for _ in range(400)]
    lv10 = [g.quality_roll(10, rng) for _ in range(400)]
    assert "gold" not in lv0
    assert lv10.count("gold") > lv0.count("gold")
    assert set(lv0) <= {"normal", "silver", "gold"}
    print("OK quality_roll (lv10 gold > lv0)")


def test_luck_scaling():
    rng = random.Random(2)
    nodes = [{"id": "stone", "kind": g.NODE_ROCK, "x": 1, "y": 1,
              "hits": 99, "day": 1}]
    lo = g.gather(nodes, 1, 1, g.NODE_ROCK, level=0, luck=0.5, rng=rng)
    hi = g.gather(nodes, 1, 1, g.NODE_ROCK, level=0, luck=2.0, rng=rng)
    assert lo["ok"] and hi["ok"]
    assert hi["count"] >= lo["count"]
    print("OK luck scaling")


if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for fn in fns:
        fn()
    print(f"\n=== {len(fns)}개 테스트 전부 통과 ===")
