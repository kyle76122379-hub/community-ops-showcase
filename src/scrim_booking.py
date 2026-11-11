"""상대와 잡은 스크림 일정 — 채널 보드 + 상대 정보 기록 + 일정 추가/취소 + 용병 글 연동.

구조
----
1) 보드: 구글 캘린더에 등록된 일정을 채널 1568766808209756211 에 **글 하나로** 모아 보여 준다.
   (투표 → 웹 기준 확정 슬롯 → 캘린더 등록은 core/scrim_calendar 가 담당. 3분마다 새로 읽는다.)
2) 관리 패널(ephemeral): [일정 관리] → ① 팀 → ② 그 팀 캘린더 일정(또는 새 일정) →
   [📝 상대 정보] / [🗑 일정 취소] / [➕ 일정 추가].
3) 채널 글 흐름: 글을 쓰면 [일정 등록] 버튼이 달리고, 누르면 글쓴이에게만 보이는 패널에서
   팀 → 일정을 골라 그 일정에 상대 정보를 기록한다.
4) 용병 연동: 일정이 취소되면 그 시간대 용병 글을 지우고, 새 일정이 생기면 투표를 다시 읽어
   한 자리가 비었을 때(4/5)만 용병 글을 올린다.

custom_id 는 전부 초안/세션 ID 를 담아 `on_interaction` 에서 처리한다(재시작 안전).
"""

import discord
from discord.ext import commands, tasks

import core.scrim_board as board
import core.scrim_booking as booking
import core.scrim_calendar as scrim_calendar
import core.scrim_mercenary as merc
import core.scrim_plan as scrim_plan

OPEN_PREFIX = "scrimbook_open:"
TEAM_PREFIX = "scrimbook_team:"
EVENT_PREFIX = "scrimbook_event:"
DATE_PREFIX = "scrimbook_date:"
SLOT_PREFIX = "scrimbook_slot:"
OK_PREFIX = "scrimbook_ok:"
NO_PREFIX = "scrimbook_no:"

BOARD_OPEN = "scrimboard_open"
BOARD_REFRESH = "scrimboard_refresh"
BOARD_ADD = "scrimboard_add:"
BOARD_ATTACH = "scrimboard_attach:"
BOARD_DELETE = "scrimboard_delete:"
BOARD_CLOSE = "scrimboard_close"

try:
    from config import GUILD_ID as SCRIM_GUILD_ID
except Exception:
    SCRIM_GUILD_ID = "617814295182311424"

NEW_VALUE = "__new__"
COLOR = 0x5865F2
BOARD_MINUTES = 3


# ────────────────────────────────────────────────────────────
# 공용 렌더
# ────────────────────────────────────────────────────────────

def build_embed(draft: dict, note: str = "") -> discord.Embed:
    opponent = str(draft.get("opponent") or "").strip() or "(텍스트 없음)"
    embed = discord.Embed(title="🗓 스크림 일정", color=COLOR,
                          description=f"**상대 정보**\n{opponent[:900]}")
    if draft.get("author_name"):
        embed.add_field(name="글쓴이", value=str(draft["author_name"])[:80], inline=False)

    embed.add_field(name="① 팀", value=draft.get("team") or "선택 필요", inline=True)
    mode = str(draft.get("mode") or "")
    if mode == "existing":
        event_text = booking.event_label({"start": draft.get("event_start"),
                                          "end": draft.get("event_end"),
                                          "title": draft.get("event_title")})
    else:
        event_text = ""
    embed.add_field(name="② 일정",
                    value=(event_text or ("새 일정으로 등록" if mode == "new" else "선택 필요")),
                    inline=True)
    if mode == "new":
        embed.add_field(name="③ 날짜", value=(booking.date_label(draft.get("date_iso"))
                                              if draft.get("date_iso") else "선택 필요"), inline=True)
        hours = scrim_plan.SLOT_HOURS.get(str(draft.get("slot") or ""))
        embed.add_field(name="④ 시간",
                        value=(f"{draft.get('slot')} ({hours[0]:02d}-{hours[1]:02d})" if hours
                               else "선택 필요"), inline=True)
    if note:
        embed.add_field(name="안내", value=note[:500], inline=False)
    embed.set_footer(text="팀 → 일정을 고르면 아래 버튼으로 처리합니다.")
    return embed


def build_view(draft: dict, events=None, disabled: bool = False, board_mode: bool = False) -> discord.ui.View:
    view = discord.ui.View(timeout=None)
    picked_team = str(draft.get("team") or "")
    view.add_item(discord.ui.Select(
        placeholder="① 어느 팀 경기인가요?",
        custom_id=f"{TEAM_PREFIX}{draft['id']}"[:100],
        row=0, disabled=disabled,
        options=[discord.SelectOption(label=team, value=team, default=(team == picked_team))
                 for team in scrim_plan.TEAMS],
    ))

    picked_event = str(draft.get("event_id") or "")
    mode = str(draft.get("mode") or "")
    options = []
    if not picked_team:
        options.append(discord.SelectOption(label="① 팀을 먼저 고르세요", value="__none__"))
        event_placeholder = "② 어느 일정인가요? — 팀을 먼저 고르세요"
        event_disabled = True
    else:
        rows = list(events or [])
        for event in rows[:24]:
            label = booking.event_label(event)
            if event.get("title"):
                label += f" · {event['title']}"
            if "상대 정보" in str(event.get("description") or ""):
                label += " (상대 등록됨)"
            options.append(discord.SelectOption(
                label=label[:100], value=str(event.get("eventId"))[:100],
                default=(str(event.get("eventId")) == picked_event)))
        options.append(discord.SelectOption(
            label="➕ 새 일정으로 등록 (캘린더에 없음)", value=NEW_VALUE, default=(mode == "new")))
        event_placeholder = (f"② 어느 일정인가요? — {picked_team} 일정 {len(rows)}개"
                             if rows else f"② {picked_team} 캘린더에 다가오는 일정이 없습니다")
        event_disabled = disabled
    view.add_item(discord.ui.Select(
        placeholder=event_placeholder[:150],
        custom_id=f"{EVENT_PREFIX}{draft['id']}"[:100],
        row=1, disabled=event_disabled, options=options[:25],
    ))

    button_row = 2
    if mode == "new":
        dates = booking.date_options()
        picked_date = str(draft.get("date_iso") or "")
        view.add_item(discord.ui.Select(
            placeholder="③ 몇 일 경기인가요?",
            custom_id=f"{DATE_PREFIX}{draft['id']}"[:100],
            row=2, disabled=disabled,
            options=[discord.SelectOption(label=label, value=iso, default=(iso == picked_date))
                     for iso, label in dates[:25]],
        ))
        slots = booking.slot_options()
        picked_slot = str(draft.get("slot") or "")
        view.add_item(discord.ui.Select(
            placeholder="④ 몇 시 경기인가요?",
            custom_id=f"{SLOT_PREFIX}{draft['id']}"[:100],
            row=3, disabled=disabled,
            options=[discord.SelectOption(label=label, value=slot, default=(slot == picked_slot))
                     for slot, label in slots[:25]],
        ))
        button_row = 4

    if board_mode:
        if mode == "new":
            view.add_item(discord.ui.Button(label="일정 추가", emoji="➕",
                                            style=discord.ButtonStyle.success,
                                            custom_id=f"{BOARD_ADD}{draft['id']}"[:100],
                                            row=button_row, disabled=disabled))
        else:
            view.add_item(discord.ui.Button(label="상대 정보", emoji="📝",
                                            style=discord.ButtonStyle.primary,
                                            custom_id=f"{BOARD_ATTACH}{draft['id']}"[:100],
                                            row=button_row,
                                            disabled=disabled or not draft.get("event_id")))
            view.add_item(discord.ui.Button(label="일정 취소", emoji="🗑",
                                            style=discord.ButtonStyle.danger,
                                            custom_id=f"{BOARD_DELETE}{draft['id']}"[:100],
                                            row=button_row,
                                            disabled=disabled or not draft.get("event_id")))
        view.add_item(discord.ui.Button(label="닫기", style=discord.ButtonStyle.secondary,
                                        custom_id=BOARD_CLOSE, row=button_row))
    else:
        view.add_item(discord.ui.Button(label="확정", style=discord.ButtonStyle.success, emoji="✅",
                                        custom_id=f"{OK_PREFIX}{draft['id']}"[:100],
                                        row=button_row, disabled=disabled))
        view.add_item(discord.ui.Button(label="취소", style=discord.ButtonStyle.danger, emoji="🗑",
                                        custom_id=f"{NO_PREFIX}{draft['id']}"[:100],
                                        row=button_row, disabled=disabled))
    return view


class OpponentModal(discord.ui.Modal):
    """보드에서 고른 일정에 상대 정보를 적는 한 칸짜리 모달."""

    def __init__(self, cog, guild_id: str, draft_id: str, current: str = ""):
        super().__init__(title="상대 정보 등록", timeout=600)
        self.cog = cog
        self.guild_id = guild_id
        self.draft_id = draft_id
        self.text = discord.ui.TextInput(
            label="상대 정보", style=discord.TextStyle.paragraph,
            placeholder="예) 7팀 / GM2 / 문의 @seven — 22:00 시작", max_length=900,
            required=True, default=current[:900] or None)
        self.add_item(self.text)

    async def on_submit(self, interaction: discord.Interaction):
        draft = booking.get(self.guild_id, self.draft_id)
        if not draft:
            await interaction.response.send_message("세션이 만료되었습니다.", ephemeral=True)
            return
        # 캘린더 API 왕복이 3초를 넘기면 Discord가 상호작용을 무효화(10062)하므로 먼저 defer 한다.
        await interaction.response.defer()
        draft["opponent"] = str(self.text.value or "").strip()
        result = await booking.attach_opponent(draft)
        events = await self.cog._events_for(draft)
        note = result["message"]
        await interaction.edit_original_response(
            embed=build_embed(draft, note=note),
            view=build_view(draft, events, board_mode=True))
        if result["ok"]:
            await self.cog.refresh_board(self.guild_id)


class ScrimBookingCog(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.board_task.start()

    def cog_unload(self):
        self.board_task.cancel()

    async def _events_for(self, draft: dict) -> list:
        team = str((draft or {}).get("team") or "")
        if not team:
            return []
        return await booking.fetch_events([team])

    # ────────────────────────────────────────────────────────
    # 보드
    # ────────────────────────────────────────────────────────
    def _board_view(self) -> discord.ui.View:
        view = discord.ui.View(timeout=None)
        view.add_item(discord.ui.Button(label="일정 관리", emoji="🛠",
                                        style=discord.ButtonStyle.primary,
                                        custom_id=BOARD_OPEN))
        # 캘린더 메모를 즉시 다시 읽어 보드에 반영하는 강제 동기화 버튼
        view.add_item(discord.ui.Button(label="새로고침", emoji="🔄",
                                        style=discord.ButtonStyle.secondary,
                                        custom_id=BOARD_REFRESH))
        return view

    async def _board_channel(self, guild_id: str):
        record = board.get(guild_id)
        channel_id = str(record["channel_id"])
        if not channel_id.isdigit():
            return None
        return self.bot.get_channel(int(channel_id)) or await self.bot.fetch_channel(int(channel_id))

    async def refresh_board(self, guild_id: str, events=None) -> dict:
        try:
            events = await booking.fetch_events(days=30) if events is None else events
            channel = await self._board_channel(guild_id)
            if channel is None:
                return {"ok": False, "message": "보드 채널을 찾지 못했습니다."}
            text = board.board_text(events)
            record = board.get(guild_id)
            view = self._board_view()
            message = None
            if str(record["message_id"]).isdigit():
                try:
                    message = await channel.fetch_message(int(record["message_id"]))
                    await message.edit(content=text, view=view,
                                       allowed_mentions=discord.AllowedMentions.none())
                except Exception:
                    message = None
            if message is None:
                # 새 글을 만들기 전에 채널의 기존 보드 글을 찾아 재사용한다
                try:
                    async for candidate in channel.history(limit=50):
                        if candidate.author.id != self.bot.user.id:
                            continue
                        if (candidate.content or "").startswith("# 📆 스크림 일정"):
                            message = candidate
                            await message.edit(content=text, view=view,
                                               allowed_mentions=discord.AllowedMentions.none())
                            break
                except Exception as exc:
                    print(f"[일정 보드] 기존 글 탐색 실패: {type(exc).__name__}: {exc}")
            if message is None:
                message = await channel.send(content=text, view=view,
                                             allowed_mentions=discord.AllowedMentions.none())
            board.save(guild_id, message_id=message.id, count=board.count(events))
            return {"ok": True, "count": board.count(events), "message_id": message.id}
        except Exception as exc:
            print(f"[일정 보드] 갱신 실패: {type(exc).__name__}: {exc}")
            return {"ok": False, "message": f"{type(exc).__name__}: {exc}"}

    # ────────────────────────────────────────────────────────
    # 용병 글 연동
    # ────────────────────────────────────────────────────────
    def _merc_item(self, guild_id: str, key: str) -> dict | None:
        settings = scrim_plan.get_settings(guild_id)
        for page in ("this_week", "next_week"):
            plan = scrim_plan.build_plan(
                page, header=settings.get("header"), footer=settings.get("footer"),
                active_teams=settings.get("active_teams"),
                slot_choices=settings.get("slot_choices"))
            for item in plan.get("mercenary") or []:
                if str(item.get("key")) == key:
                    return item
        return None

    async def sync_merc_for_slot(self, guild_id: str, team: str, date_iso: str, slot: str,
                                 reason: str = "") -> dict:
        """그 시간대 투표를 다시 읽어 용병 모집 목록을 맞추고, 모집 글 하나를 갱신한다."""
        if not (team and date_iso and slot):
            return {"ok": False, "message": "팀·날짜·시간이 필요합니다."}
        key = f"{date_iso}|{slot}|{team}"
        existing = (merc.get_post(guild_id).get("slots") or {}).get(key)
        item = None if str(reason or "") == "cancel" else self._merc_item(guild_id, key)
        changed = False
        note = ""

        if item:
            if existing and str(existing.get("status") or "open") == "open":
                return {"ok": True, "message": "이미 모집 중입니다.", "changed": False}
            slot_rec = dict(existing or {})
            slot_rec.update({
                "key": key,
                "team": item.get("team") or "",
                "tier": item.get("tier") or "",
                "date_iso": item.get("date_iso") or "",
                "date": item.get("date") or "",
                "day": item.get("day") or "",
                "slot": item.get("slot") or "",
                "start": item.get("start") or "",
                "end": item.get("end") or "",
                "position": item.get("position") or "",
                "line": item.get("line") or "",
                "detail": item.get("detail") or "",
                "text": item.get("text") or "",
                "message_id": "",
                "status": "open",
                "cancel_reason": "",
                "selected_user": "",
                "done_at": "",
            })
            slots = dict((merc.get_post(guild_id).get("slots") or {}))
            slots[key] = slot_rec
            merc.save_post(guild_id, slots=slots)
            changed = True
            note = f"용병 모집에 추가했습니다. ({slot_rec.get('line')})"
        elif existing:
            merc.drop_slot(guild_id, key)
            changed = True
            note = "일정이 바뀌어 용병 모집에서 뺐습니다."
        else:
            return {"ok": True, "message": "이 시간대는 용병이 필요 없습니다.", "changed": False}

        cog = self.bot.get_cog("ScrimMercenaryCog")
        if cog is not None and changed:
            await cog.render(guild_id)
        return {"ok": True, "message": note, "changed": changed}

    async def _reconcile_mercs(self, guild_id: str, events) -> None:
        """캘린더 일정 기준으로 모집 목록을 맞춘다 — 없어진 일정은 빼고, 4/5 일정은 넣는다."""
        alive = set()
        changed = False
        for event in events or []:
            key = board.slot_key_of(event)
            if key.count("|") != 2:
                continue
            alive.add(key)
            if not self._merc_item(guild_id, key):
                continue
            if (merc.get_post(guild_id).get("slots") or {}).get(key):
                continue
            await self.sync_merc_for_slot(
                guild_id, str(event.get("team") or ""),
                key.split("|")[0], key.split("|")[1], reason="board")
            changed = True
        for key in list((merc.get_post(guild_id).get("slots") or {}).keys()):
            if key in alive:
                continue
            merc.drop_slot(guild_id, key)
            changed = True
        if changed:
            cog = self.bot.get_cog("ScrimMercenaryCog")
            if cog is not None:
                await cog.render(guild_id)

    @tasks.loop(minutes=BOARD_MINUTES)
    async def board_task(self):
        guild_id = SCRIM_GUILD_ID
        try:
            settings = scrim_plan.get_settings(guild_id)
            if settings.get("calendar_enabled"):
                for page in ("this_week", "next_week"):
                    plan = scrim_plan.build_plan(
                        page, header=settings.get("header"), footer=settings.get("footer"),
                        active_teams=settings.get("active_teams"),
                        slot_choices=settings.get("slot_choices"))
                    result = await scrim_calendar.sync_plan(guild_id, plan, settings)
                    if (result.get("created") or result.get("errors")):
                        print(f"[일정 보드] 캘린더 동기화 {page}: {result.get('summary')}")
            events = await booking.fetch_events(days=30)
            await self._reconcile_mercs(guild_id, events)
            await self.refresh_board(guild_id, events)
        except Exception as exc:
            print(f"[일정 보드] 주기 작업 오류: {type(exc).__name__}: {exc}")

    @board_task.before_loop
    async def before_board(self):
        await self.bot.wait_until_ready()

    # ────────────────────────────────────────────────────────
    # 채널 글 → 초안
    # ────────────────────────────────────────────────────────
    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        if message.author.bot or message.guild is None:
            return
        if str(message.channel.id) != booking.CHANNEL_ID:
            return
        guild_id = str(message.guild.id)
        # 보드 글에는 반응하지 않는다 (봇이 보낸 글은 위에서 걸러지지만, 안전하게 한 번 더)
        if str(message.id) == str(board.get(guild_id)["message_id"]):
            return
        text = (message.content or "").strip()
        links = [a.url for a in message.attachments]
        if not text and not links:
            return
        if booking.by_message(guild_id, message.id):
            return

        draft = booking.create_draft(
            guild_id, message.channel.id, message.id, message.author.id,
            getattr(message.author, "display_name", None) or message.author.name, text, links)
        draft["source"] = "post"
        booking.save(draft)
        author_name = getattr(message.author, "display_name", None) or message.author.name
        view = discord.ui.View(timeout=None)
        view.add_item(discord.ui.Button(
            label="일정 등록", style=discord.ButtonStyle.primary, emoji="📆",
            custom_id=f"{OPEN_PREFIX}{draft['id']}"[:100]))
        try:
            prompt = await message.reply(
                content=(f"📆 상대 정보 접수됨 — **{author_name}** 님이 [일정 등록] 을 누르면 "
                         "팀 → 캘린더 일정을 골라 상대 정보를 기록합니다. (본인에게만 보입니다)"),
                view=view, mention_author=False,
                allowed_mentions=discord.AllowedMentions.none())
            draft["prompt_message_id"] = str(prompt.id)
            booking.save(draft)
        except Exception as exc:
            print(f"[스크림 등록] 안내 글 실패: {type(exc).__name__}: {exc}")
            return
        try:
            await message.add_reaction("🗓")
        except Exception:
            pass

    # ────────────────────────────────────────────────────────
    # 상호작용
    # ────────────────────────────────────────────────────────
    @commands.Cog.listener()
    async def on_interaction(self, interaction: discord.Interaction):
        if interaction.type is not discord.InteractionType.component:
            return
        custom_id = str((interaction.data or {}).get("custom_id") or "")
        try:
            if custom_id == BOARD_OPEN:
                await self._open_board_panel(interaction)
            elif custom_id == BOARD_REFRESH:
                await self._board_refresh(interaction)
            elif custom_id == BOARD_CLOSE:
                await interaction.response.edit_message(content="패널을 닫았습니다.", embed=None, view=None)
            elif custom_id.startswith(BOARD_ADD):
                await self._board_add(interaction, custom_id[len(BOARD_ADD):])
            elif custom_id.startswith(BOARD_ATTACH):
                await self._board_attach(interaction, custom_id[len(BOARD_ATTACH):])
            elif custom_id.startswith(BOARD_DELETE):
                await self._board_delete(interaction, custom_id[len(BOARD_DELETE):])
            elif custom_id.startswith(OPEN_PREFIX):
                await self._open(interaction, custom_id[len(OPEN_PREFIX):])
            elif custom_id.startswith(TEAM_PREFIX):
                await self._pick(interaction, custom_id[len(TEAM_PREFIX):], "team")
            elif custom_id.startswith(EVENT_PREFIX):
                await self._pick(interaction, custom_id[len(EVENT_PREFIX):], "event")
            elif custom_id.startswith(DATE_PREFIX):
                await self._pick(interaction, custom_id[len(DATE_PREFIX):], "date_iso")
            elif custom_id.startswith(SLOT_PREFIX):
                await self._pick(interaction, custom_id[len(SLOT_PREFIX):], "slot")
            elif custom_id.startswith(OK_PREFIX):
                await self._confirm(interaction, custom_id[len(OK_PREFIX):])
            elif custom_id.startswith(NO_PREFIX):
                await self._cancel(interaction, custom_id[len(NO_PREFIX):])
        except Exception as exc:
            print(f"[스크림 등록] 상호작용 오류: {type(exc).__name__}: {exc}")
            try:
                if not interaction.response.is_done():
                    await interaction.response.send_message(
                        "처리 중 오류가 발생했습니다.", ephemeral=True)
            except Exception:
                pass

    # ── 보드 관리 패널 ───────────────────────────────────────
    async def _board_refresh(self, interaction: discord.Interaction):
        """🔄 새로고침 — 캘린더를 다시 읽어 보드 글을 즉시 갱신한다."""
        guild_id = str(interaction.guild_id or "")
        await interaction.response.defer(ephemeral=True)
        result = await self.refresh_board(guild_id)
        if result.get("ok"):
            text = f"🔄 보드를 새로고침했습니다 — 일정 **{result.get('count', 0)}건** 반영"
        else:
            text = f"⚠️ 새로고침 실패: {result.get('message') or '알 수 없는 오류'}"
        try:
            await interaction.followup.send(text, ephemeral=True)
        except Exception as exc:
            print(f"[보드 새로고침] 응답 실패: {type(exc).__name__}: {exc}")

    def _panel_id(self, guild_id: str, user_id) -> str:
        return f"board{guild_id}{user_id}"

    async def _open_board_panel(self, interaction: discord.Interaction):
        guild_id = str(interaction.guild_id or "")
        pid = self._panel_id(guild_id, interaction.user.id)
        draft = booking.get(guild_id, pid)
        if not draft:
            draft = booking.create_draft(guild_id, board.get(guild_id)["channel_id"],
                                         "board", interaction.user.id,
                                         getattr(interaction.user, "display_name",
                                                 getattr(interaction.user, "name", "")), "")
            draft["id"] = pid
            draft["source"] = "board"
            booking.save(draft)
        await interaction.response.defer(ephemeral=True)
        events = await booking.fetch_events(days=30)
        await interaction.followup.send(
            embed=build_embed(draft), view=build_view(draft, events, board_mode=True),
            ephemeral=True)

    async def _board_add(self, interaction: discord.Interaction, draft_id: str):
        guild_id = str(interaction.guild_id or "")
        draft = booking.get(guild_id, draft_id)
        if not draft:
            await interaction.response.send_message("세션이 만료되었습니다.", ephemeral=True)
            return
        if not (draft.get("team") and draft.get("date_iso") and draft.get("slot")):
            await interaction.response.defer()
            events = await self._events_for(draft)
            await interaction.edit_original_response(
                embed=build_embed(draft, note="팀·날짜·시간을 모두 골라 주세요."),
                view=build_view(draft, events, board_mode=True))
            return
        await interaction.response.defer()
        opponent = str(draft.get("opponent") or "")
        settings = scrim_plan.get_settings(guild_id)
        result = await booking.add_event(draft["team"], draft["date_iso"], draft["slot"],
                                         opponent,
                                         settings.get("calendar_title") or "{team}",
                                         guild_id=guild_id)
        merc_res = await self.sync_merc_for_slot(guild_id, draft["team"], draft["date_iso"],
                                                 draft["slot"])
        note = f"{result['message']}\n{merc_res.get('message', '')}".strip()
        if result["ok"]:
            draft.update(mode="", event_id="", event_start="", event_end="", event_title="",
                         event_desc="", date_iso="", slot="")
            booking.save(draft)
        events = await booking.fetch_events(days=30)
        await interaction.edit_original_response(
            embed=build_embed(draft, note=note),
            view=build_view(draft, events, board_mode=True))
        if result["ok"]:
            await self.refresh_board(guild_id)

    async def _board_attach(self, interaction: discord.Interaction, draft_id: str):
        guild_id = str(interaction.guild_id or "")
        draft = booking.get(guild_id, draft_id)
        if not draft or str(draft.get("mode")) != "existing" or not draft.get("event_id"):
            await interaction.response.send_message("② 일정을 먼저 골라 주세요.", ephemeral=True)
            return
        current = board.opponent_of({"description": draft.get("event_desc") or ""})
        await interaction.response.send_modal(
            OpponentModal(self, guild_id, draft_id, current))

    async def _board_delete(self, interaction: discord.Interaction, draft_id: str):
        guild_id = str(interaction.guild_id or "")
        draft = booking.get(guild_id, draft_id)
        if not draft or str(draft.get("mode")) != "existing" or not draft.get("event_id"):
            await interaction.response.send_message("② 일정을 먼저 골라 주세요.", ephemeral=True)
            return
        await interaction.response.defer()
        event = {"team": draft.get("team"), "eventId": draft.get("event_id"),
                 "title": draft.get("event_title"), "start": draft.get("event_start"),
                 "end": draft.get("event_end")}
        # 취소 전에 그 시간대 정보를 기억해 둔다(용병 글 정리용)
        date_iso = ""
        start_dt = booking.parse_iso(draft.get("event_start"))
        if start_dt:
            date_iso = start_dt.astimezone(scrim_calendar.KST).date().isoformat()
        slot = board.event_slot(event)

        result = await booking.delete_event(event, guild_id=guild_id,
                                            by=str(interaction.user.id))
        merc_note = ""
        if result["ok"]:
            merc_res = await self.sync_merc_for_slot(guild_id, str(draft.get("team") or ""),
                                                     date_iso, slot, reason="cancel")
            merc_note = merc_res.get("message", "")
            draft.update(mode="", event_id="", event_start="", event_end="", event_title="",
                         event_desc="", date_iso="", slot="")
            booking.save(draft)
        note = f"{result['message']}\n{merc_note}".strip()
        events = await booking.fetch_events([draft["team"]]) if draft.get("team") else []
        await interaction.edit_original_response(
            embed=build_embed(draft, note=note),
            view=build_view(draft, events, board_mode=True))
        if result["ok"]:
            await self.refresh_board(guild_id)

    # ── 글 흐름(상대 정보 등록) ──────────────────────────────
    async def _open(self, interaction: discord.Interaction, draft_id: str):
        guild_id = str(interaction.guild_id or "")
        draft = booking.get(guild_id, draft_id)
        if not draft:
            await interaction.response.send_message(
                "이 등록은 만료되었습니다. 채널에 다시 올려 주세요.", ephemeral=True)
            return
        if str(interaction.user.id) != str(draft.get("author_id")):
            await interaction.response.send_message(
                "이 글을 쓴 사람만 등록할 수 있습니다.", ephemeral=True)
            return
        if str(draft.get("status")) == "confirmed":
            await interaction.response.send_message(
                f"이미 처리된 등록입니다 — {booking.summary_line(draft)}", ephemeral=True)
            return
        await interaction.response.defer(ephemeral=True)
        events = await self._events_for(draft)
        await interaction.followup.send(
            embed=build_embed(draft), view=build_view(draft, events), ephemeral=True)

    def _owned(self, interaction: discord.Interaction, draft: dict) -> bool:
        if str(draft.get("source")) == "board":
            return True
        return str(interaction.user.id) == str(draft.get("author_id"))

    async def _pick(self, interaction: discord.Interaction, draft_id: str, field: str):
        guild_id = str(interaction.guild_id or "")
        values = (interaction.data or {}).get("values") or []
        if not values:
            await interaction.response.defer()
            return
        draft = booking.get(guild_id, draft_id)
        if not draft:
            await interaction.response.send_message(
                "이 등록은 만료되었습니다. 채널에 다시 올려 주세요.", ephemeral=True)
            return
        if not self._owned(interaction, draft):
            await interaction.response.send_message(
                "이 글을 쓴 사람만 등록할 수 있습니다.", ephemeral=True)
            return

        # 캘린더(GAS) 조회가 5~15초 걸린다 — 먼저 응답을 확정하지 않으면
        # 3초 제한을 넘겨 10062 Unknown interaction 이 나고 패널이 갱신되지 않는다.
        await interaction.response.defer()
        value = str(values[0])
        events = []
        if field == "team":
            draft["team"] = value
            draft.update(mode="", event_id="", event_start="", event_end="",
                         event_title="", event_desc="", date_iso="", slot="")
            events = await booking.fetch_events([value])
        elif field == "event":
            events = await self._events_for(draft)
            if value == NEW_VALUE:
                draft.update(mode="new", event_id="", event_start="", event_end="",
                             event_title="", event_desc="")
            else:
                picked = next((e for e in events if str(e.get("eventId")) == value), None)
                if not picked:
                    await interaction.followup.send(
                        "그 일정을 캘린더에서 찾지 못했습니다. 다시 골라 주세요.", ephemeral=True)
                    return
                draft.update(mode="existing", event_id=value,
                             event_start=str(picked.get("start") or ""),
                             event_end=str(picked.get("end") or ""),
                             event_title=str(picked.get("title") or ""),
                             event_desc=str(picked.get("description") or ""),
                             date_iso="", slot="")
        else:
            draft[field] = value
            if field == "date_iso":
                draft["slot"] = ""

        draft = booking.save(draft)
        if not events and draft.get("team"):
            events = await self._events_for(draft)
        await interaction.edit_original_response(
            embed=build_embed(draft),
            view=build_view(draft, events, board_mode=(str(draft.get("source")) == "board")))

    async def _confirm(self, interaction: discord.Interaction, draft_id: str):
        guild_id = str(interaction.guild_id or "")
        draft = booking.get(guild_id, draft_id)
        if not draft:
            await interaction.response.send_message(
                "이 등록은 만료되었습니다. 채널에 다시 올려 주세요.", ephemeral=True)
            return
        if not self._owned(interaction, draft):
            await interaction.response.send_message(
                "이 글을 쓴 사람만 등록할 수 있습니다.", ephemeral=True)
            return
        if str(draft.get("status")) == "confirmed":
            await interaction.response.send_message("이미 확정된 일정입니다.", ephemeral=True)
            return

        mode = str(draft.get("mode") or "")
        missing = []
        if not draft.get("team"):
            missing.append("팀")
        if mode == "existing" and not draft.get("event_id"):
            missing.append("일정")
        if mode == "new":
            if not draft.get("date_iso"):
                missing.append("날짜")
            if not draft.get("slot"):
                missing.append("시간")
        if not mode:
            missing.append("일정")
        if missing:
            await interaction.response.defer()
            events = await self._events_for(draft)
            await interaction.edit_original_response(
                embed=build_embed(draft, note=f"{', '.join(missing)}를 아직 고르지 않았습니다."),
                view=build_view(draft, events))
            return

        await interaction.response.defer()
        if mode == "existing":
            result = await booking.attach_opponent(draft)
        else:
            result = await booking.create_calendar_event(guild_id, draft)
            if result["ok"]:
                start = booking.parse_iso((result.get("event") or {}).get("start"))
                date_iso = start.astimezone(scrim_calendar.KST).date().isoformat() if start else ""
                await self.sync_merc_for_slot(guild_id, str(draft.get("team") or ""),
                                              date_iso, str(draft.get("slot") or ""))

        draft = booking.update(
            guild_id, draft_id,
            status="confirmed" if result["ok"] else "draft",
            event=result.get("event"),
            calendar_ok=bool(result["ok"]),
            calendar_message=result["message"],
            confirmed_at=booking._now() if result["ok"] else "",
        ) or draft
        events = await self._events_for(draft)

        if result["ok"]:
            note = f"{booking.summary_line(draft)}\n{result['message']}"
            await interaction.edit_original_response(
                embed=build_embed(draft, note=note),
                view=build_view(draft, events, disabled=True))
            await self._mark_source(draft)
            await self.refresh_board(guild_id)
        else:
            await interaction.edit_original_response(
                embed=build_embed(draft, note=result["message"] + "\n[확정] 을 다시 눌러 재시도할 수 있습니다."),
                view=build_view(draft, events))

    async def _cancel(self, interaction: discord.Interaction, draft_id: str):
        guild_id = str(interaction.guild_id or "")
        existing = booking.get(guild_id, draft_id)
        if existing and not self._owned(interaction, existing):
            await interaction.response.send_message(
                "이 글을 쓴 사람만 등록할 수 있습니다.", ephemeral=True)
            return
        draft = booking.update(guild_id, draft_id, status="cancelled")
        if not draft:
            await interaction.response.send_message("이미 만료된 등록입니다.", ephemeral=True)
            return
        await interaction.response.edit_message(
            embed=build_embed(draft, note="취소했습니다. 필요하면 채널에 다시 올려 주세요."),
            view=None)

    async def _mark_source(self, draft: dict):
        channel_id = str(draft.get("channel_id") or "")
        message_id = str(draft.get("message_id") or "")
        if not (channel_id.isdigit() and message_id.isdigit()):
            return
        try:
            channel = self.bot.get_channel(int(channel_id)) or \
                await self.bot.fetch_channel(int(channel_id))
            message = await channel.fetch_message(int(message_id))
            await message.add_reaction("✅")
        except Exception as exc:
            print(f"[스크림 등록] 원본 글 표시 실패: {type(exc).__name__}: {exc}")


async def setup(bot: commands.Bot):
    await bot.add_cog(ScrimBookingCog(bot))
