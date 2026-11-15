"""숙련도 시스템 단위 테스트 — 실행: cd systems && python test_skills.py"""
import skills


def test_empty():
    s = skills.empty_skills()
    assert set(s.keys()) == set(skills.SKILLS)
    for v in s.values():
        assert v["xp"] == 0 and v["level"] == 0 and v["professions"] == []
    print("OK empty_skills")


def test_level_table():
    # 스타듀밸리 원본 누적 XP 표
    assert skills.CUMULATIVE[1] == 100
    assert skills.CUMULATIVE[2] == 380
    assert skills.CUMULATIVE[5] == 2150
    assert skills.CUMULATIVE[10] == 15000
    print("OK cumulative table 100/380/2150/15000")


def test_level_for_xp():
    assert skills.level_for_xp(0) == 0
    assert skills.level_for_xp(99) == 0
    assert skills.level_for_xp(100) == 1
    assert skills.level_for_xp(379) == 1
    assert skills.level_for_xp(380) == 2
    assert skills.level_for_xp(14999) == 9
    assert skills.level_for_xp(15000) == 10
    assert skills.level_for_xp(99999) == 10
    print("OK level_for_xp boundaries")


def test_xp_to_next():
    assert skills.xp_to_next(0) == 100
    assert skills.xp_to_next(100) == 280
    assert skills.xp_to_next(15000) == 0
    print("OK xp_to_next")


def test_level_progress():
    p = skills.level_progress(0)
    assert p["level"] == 0 and p["need"] == 100 and p["ratio"] == 0.0
    p = skills.level_progress(50)
    assert p["level"] == 0 and p["in_level"] == 50 and abs(p["ratio"] - 0.5) < 1e-9
    p = skills.level_progress(380)
    assert p["level"] == 2 and p["in_level"] == 0
    p = skills.level_progress(15000)
    assert p["level"] == 10 and p["ratio"] == 1.0 and p["need"] == 0
    print("OK level_progress")


def test_add_xp_levelup():
    s = skills.empty_skills()
    r = skills.add_xp(s, "farming", 100)
    assert r["ok"] and r["level"] == 1 and r["level_up"] == [1]
    assert s["farming"]["xp"] == 100 and s["farming"]["level"] == 1
    print("OK add_xp 100 -> Lv1")


def test_add_xp_multi_level():
    s = skills.empty_skills()
    r = skills.add_xp(s, "combat", 380)
    assert r["level"] == 2 and r["level_up"] == [1, 2]
    print("OK add_xp multi level [1,2]")


def test_add_xp_invalid():
    s = skills.empty_skills()
    r = skills.add_xp(s, "nope", 100)
    assert r["ok"] is False
    r = skills.add_xp(s, "fishing", -50)
    assert r["ok"] is True and r["xp"] == 0
    print("OK add_xp invalid/negative")


def test_add_xp_all_skills():
    s = skills.empty_skills()
    for sk in skills.SKILLS:
        skills.add_xp(s, sk, 15000)
        assert s[sk]["level"] == 10
    print("OK all 5 skills reach Lv10 at 15000")


def test_normalize():
    bad = {"farming": {"xp": "abc"}, "fishing": {"xp": 380},
           "combat": None, "mining": {"xp": 15000}, "foraging": {"xp": -5}}
    n = skills.normalize(bad)
    assert n["farming"]["xp"] == 0
    assert n["fishing"]["level"] == 2
    assert n["combat"]["xp"] == 0
    assert n["mining"]["level"] == 10
    assert n["foraging"]["xp"] == 0
    print("OK normalize handles bad data")


def test_normalize_not_dict():
    n = skills.normalize(None)
    assert n == skills.empty_skills()
    n = skills.normalize("garbage")
    assert n == skills.empty_skills()
    print("OK normalize non-dict")


def test_profession_choices():
    for sk in skills.SKILLS:
        c5 = skills.profession_choices(sk, 5)
        c10 = skills.profession_choices(sk, 10)
        assert len(c5) == 2 and len(c10) == 2, f"{sk} 5/10 직업 2개씩"
        assert all(set(o.keys()) == {"id", "name", "desc"} for o in c5 + c10)
    assert skills.profession_choices("farming", 3) == []
    print("OK profession_choices 2 each")


def test_choose_profession():
    s = skills.empty_skills()
    r = skills.choose_profession(s, "farming", 5, "tiller")
    assert r["ok"] is False  # 레벨 미달
    skills.add_xp(s, "farming", 2150)
    assert s["farming"]["level"] == 5
    r = skills.choose_profession(s, "farming", 5, "tiller")
    assert r["ok"] is True and r["profession"]["name"] == "농부"
    assert "tiller" in s["farming"]["professions"]
    r = skills.choose_profession(s, "farming", 5, "rancher")
    assert r["ok"] is False  # 중복 선택 거부
    r = skills.choose_profession(s, "farming", 5, "bad")
    assert r["ok"] is False
    r = skills.choose_profession(s, "farming", 3, "tiller")
    assert r["ok"] is False
    print("OK choose_profession")


def test_choose_profession_10():
    s = skills.empty_skills()
    skills.add_xp(s, "fishing", 15000)
    r = skills.choose_profession(s, "fishing", 10, "angler")
    assert r["ok"] is True
    print("OK choose_profession Lv10")


def test_tool_energy_cost():
    assert skills.tool_energy_cost("farming", 0, 2) == 2
    assert skills.tool_energy_cost("farming", 10, 2) == 1   # 50% 감소
    assert skills.tool_energy_cost("farming", 5, 2) == 2    # 25% 감소 -> 반올림 2
    assert skills.tool_energy_cost("mining", 10, 4) == 2
    assert skills.tool_energy_cost("mining", 99, 2) == 1    # 10 초과 방어
    print("OK tool_energy_cost")


def test_sell_bonus():
    assert skills.sell_bonus("farming", []) == 1.0
    assert skills.sell_bonus("farming", ["tiller"]) == 1.1
    assert skills.sell_bonus("farming", ["artisan"]) == 1.4
    assert skills.sell_bonus("fishing", ["fisher"]) == 1.25
    assert skills.sell_bonus("fishing", ["angler"]) == 1.5
    assert skills.sell_bonus("mining", ["blacksmith"]) == 1.5
    assert skills.sell_bonus("foraging", ["forester"]) == 1.5
    assert skills.sell_bonus("combat", ["fighter"]) == 1.0
    print("OK sell_bonus")


def test_summary():
    s = skills.empty_skills()
    skills.add_xp(s, "farming", 2150)
    skills.add_xp(s, "fishing", 100)
    out = skills.summary(s)
    assert set(out.keys()) == set(skills.SKILLS)
    assert out["farming"]["level"] == 5
    assert out["farming"]["name"] == "농사"
    assert out["fishing"]["level"] == 1
    assert out["mining"]["level"] == 0
    assert len(out["farming"]["choices"]) == 2   # 5레벨 직업 선택 가능
    assert out["fishing"]["choices"] == []       # 1레벨, 선택 없음
    print("OK summary")


if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for fn in fns:
        fn()
    print(f"\n=== {len(fns)}개 테스트 전부 통과 ===")
