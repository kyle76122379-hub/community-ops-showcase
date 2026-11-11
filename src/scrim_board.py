# core/scrim_board.py
"""스크림 일정 보드 — 구글 캘린더에 올라간 일정을 채널 한 곳에 모아 보여 준다.

투표 → 웹 기준(확정 슬롯) → 캘린더 등록은 core/scrim_calendar 가 하고, 이 모듈은 그 결과를
채널 글 하나로 정리한다. 보드는 **캘린더를 그대로 읽어** 만들기 때문에, 손으로 캘린더를 고쳐도
다음 갱신에 반영된다.

저장 위치
--------
scrim_board : key = guild_id, {channel_id, message_id, updated_at, count}
"""

from __future__ import annotations

import datetime as dt
import time

from core import scrim_booking, scrim_plan
from core.db import SQLiteProxyDict, db

try:  # 팀별 상징 이모지 — 설정이 없어도 보드는 떠야 한다
    from config import TEAM_COLORS
except Exception:
    TEAM_COLORS = {}

CHANNEL_ID = scrim_booking.CHANNEL_ID
MAX_LEN = 1900
_STORES = {}


def _store(name):
    try:
        return db.data[name]
    except (KeyError, TypeError):
        pass
    if name not in _STORES:
        try:
            proxy = SQLiteProxyDict(name)
        except Exception:
            return None
        try:
            db.data[name] = proxy
        except Exception:
            pass
        _STORES[name] = proxy
    return _STORES[name]


def _now() -> str:
    return time.strftime("%Y-%m-%d %H:%M:%S")


def get(guild_id) -> dict:
    store = _store("scrim_board")
    record = {}
    if store is not None:
        try:
            value = store.get(str(guild_id))
        except Exception:
            value = None
        if isinstance(value, dict):
            record = value
    return {
        "guild_id": str(guild_id),
        "channel_id": str(record.get("channel_id") or CHANNEL_ID),
        "message_id": str(record.get("message_id") or ""),
        "updated_at": str(record.get("updated_at") or ""),
        "count": int(record.get("count") or 0),
    }


def save(guild_id, message_id=None, channel_id=None, count=None) -> dict:
    record = get(guild_id)
    if message_id is not None:
        record["message_id"] = str(message_id)
    if channel_id:
        record["channel_id"] = str(channel_id)
    if count is not None:
        record["count"] = int(count)
    record["updated_at"] = _now()
    store = _store("scrim_board")
    if store is not None:
        try:
            store[str(guild_id)] = record
        except Exception:
            pass
    return record


# ────────────────────────────────────────────────────────────
# 이벤트 → 슬롯/문구
# ────────────────────────────────────────────────────────────

def event_slot(event: dict) -> str:
    """이벤트 시작/끝 시각으로 취합 슬롯 라벨('8-10')을 찾는다. 못 찾으면 ''."""
    start = scrim_booking.parse_iso(event.get("start"))
    end = scrim_booking.parse_iso(event.get("end"))
    if not start:
        return ""
    start = start.astimezone(scrim_booking.scrim_calendar.KST)
    end_hour = end.astimezone(scrim_booking.scrim_calendar.KST).hour if end else (start.hour + 2) % 24
    for slot, hours in scrim_plan.SLOT_HOURS.items():
        if hours[0] == start.hour:
            expect_end = hours[1] % 24
            if end_hour == expect_end or (hours[1] >= 24 and end_hour == 0):
                return slot
            return slot
    return ""


def event_key(event: dict) -> str:
    """'너이|2026-11-12|8-10' — 용병 슬롯 키와 같은 형식(날짜|슬롯|팀 순서만 다름)."""
    start = scrim_booking.parse_iso(event.get("start"))
    date_iso = start.astimezone(scrim_booking.scrim_calendar.KST).date().isoformat() if start else ""
    return f"{event.get('team') or ''}|{date_iso}|{event_slot(event)}"


def slot_key_of(event: dict) -> str:
    """용병 모집 슬롯 키 (`날짜|슬롯|팀`)."""
    start = scrim_booking.parse_iso(event.get("start"))
    date_iso = start.astimezone(scrim_booking.scrim_calendar.KST).date().isoformat() if start else ""
    return f"{date_iso}|{event_slot(event)}|{event.get('team') or ''}"


def _desc_lines(event: dict) -> list:
    """캘린더 설명을 의미 있는 줄 목록으로 — '상대 정보' 헤더 줄은 내용이 아니므로 버린다.

    같은 팀이라도 어떤 일정은 `상대 정보\\nA` 형식이고, 어떤 일정은 `A` 만 적혀 있다.
    예전에는 헤더가 있는 쪽만 읽어서 나머지 일정의 메모가 보드에서 통째로 사라졌다.
    """
    text = str(event.get("description") or "").strip()
    if not text:
        return []
    out = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.rstrip(":").strip().replace(" ", "") == "상대정보":
            continue
        out.append(line)
    return out


def opponent_of(event: dict) -> str:
    """상대 라인 — '상대 정보' 헤더가 있든 없든 설명의 첫 내용 줄."""
    lines = _desc_lines(event)
    return lines[0][:80] if lines else ""


def memo_of(event: dict, limit: int = 80) -> str:
    """상대 라인 이후의 나머지 메모(티어·플랫폼·비고 등)."""
    lines = _desc_lines(event)
    if len(lines) <= 1:
        return ""
    return " / ".join(lines[1:])[:limit]


def line_of(event: dict) -> str:
    """'`20:00-22:00` 🟦 **두이** · vs oze' — 날짜는 묶음 제목이 보여 주므로 시각만 적는다."""
    start = scrim_booking.parse_iso(event.get("start"))
    end = scrim_booking.parse_iso(event.get("end"))
    team = str(event.get("team") or "")
    emoji = TEAM_COLORS.get(team) or "🎮"
    time_text = ""
    if start:
        start = start.astimezone(scrim_booking.scrim_calendar.KST)
        if end:
            end = end.astimezone(scrim_booking.scrim_calendar.KST)
            time_text = f"`{start:%H:%M}-{end:%H:%M}`"
        else:
            time_text = f"`{start:%H:%M}`"
    opponent = opponent_of(event)
    head = " ".join(part for part in (time_text, f"{emoji} **{team}**") if part)
    return head + (f" · vs {opponent}" if opponent else "")


def group_events(events) -> list:
    """[{date_iso, label, items[]}] — 날짜 오름차순, **시작 시각이 지난 일정은 제외**."""
    now = dt.datetime.now(scrim_booking.scrim_calendar.KST)
    groups = {}
    for event in events or []:
        start = scrim_booking.parse_iso(event.get("start"))
        if not start:
            continue
        moment = start.astimezone(scrim_booking.scrim_calendar.KST)
        if moment <= now:
            continue
        date_iso = moment.date().isoformat()
        groups.setdefault(date_iso, []).append(event)
    rows = []
    for date_iso in sorted(groups):
        day = dt.date.fromisoformat(date_iso)
        items = sorted(groups[date_iso], key=lambda e: str(e.get("start")))
        rows.append({
            "date_iso": date_iso,
            "label": f"{day.month}/{day.day} ({'월화수목금토일'[day.weekday()]})",
            "items": items,
        })
    return rows


def board_text(events, header: str = "") -> str:
    """채널에 띄울 보드 문구. 1900자 제한에 맞춰 자른다."""
    groups = group_events(events)
    head = header or ("# 📆 스크림 일정\n\n구글 캘린더에 등록된 일정·메모입니다. "
                      "**[일정 관리]** 로 상대 정보·추가·취소를, **[새로고침]** 으로 캘린더 메모를 즉시 반영합니다.")
    if not groups:
        return (head + "\n\n_등록된 일정이 없습니다._\n\n"
                "투표가 확정되면 자동으로 채워집니다.")
    lines = [head, ""]
    shown = 0
    for group in groups:
        block = [f"## 📅 {group['label']}", ""]
        for event in group["items"]:
            block.append(f"· {line_of(event)}")
            memo = memo_of(event)
            if memo:
                block.append(f"   ↳ {memo}")
        candidate = "\n".join(lines + block) + "\n"
        if len(candidate) > MAX_LEN:
            rest = sum(len(g["items"]) for g in groups) - shown
            lines.append(f"… 외 {rest}건")
            break
        lines.extend(block)
        lines.append("")
        shown += len(group["items"])
    return "\n".join(lines).strip()


def count(events) -> int:
    return sum(len(g["items"]) for g in group_events(events))
