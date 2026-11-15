"""재화 원장 — 모든 XP 변경이 통과하는 단일 경로 (발췌)

원본: core/db.py + web/main.py
why: 채팅 XP 지급, 게임 보상, 주식 체결이 서로의 변경을 덮어쓰지 않으려면
     확인과 차감이 같은 트랜잭션 안에서 끝나야 한다.
"""


class _DataManager:
    def change_user(self, user_id: str, mutator):
        """유저 행을 원자적으로 바꾼다 (트랜잭션 read-modify-write).

        채팅 XP 지급과 주식 체결이 서로의 변경을 덮어쓰지 않도록 모든 XP 변경은 이 경로를 쓴다.
        """
        return self.data["users"].update_item(str(user_id), mutator)


# ── 미니게임 API 공통: 인증된 유저의 DB 행을 트랜잭션 안에서 바꿔 쓴다 ──
def _mg_mutate(user_id: str, mutator):
    """db.change_user 로 원자적 read-modify-write. (u, ok) 반환."""
    uid = str(user_id)

    def _run(doc: dict):
        u = doc
        _mg_check_daily_reset(u)
        return mutator(u)

    try:
        result = db.change_user(uid, _run)
        return result, True
    except Exception as e:
        return {"ok": False, "error": f"DB 오류: {e}"}, False
