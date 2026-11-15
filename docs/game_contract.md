# 클라이언트 ↔ 서버 계약

게임 클라이언트가 지키는 불변식(invariant)과 서버 응답 계약입니다.

## 불변식

1. **서버가 유일한 판정자.** 클라이언트는 보상·가격·확률을 계산하지 않는다.
2. **액션 후 재부트스트랩.** 응답을 화면에 낙관적으로 반영하지 않고 `/api/game/bootstrap`을 다시 읽는다.
3. **재화는 XP 하나.** 별도 코인은 없다. 봇·웹·게임이 같은 `xp` / `total_xp` 필드를 쓴다.
4. **음수 불가.** 확인과 차감은 서버의 같은 mutator 안에서 일어난다.
5. **클라이언트 전용 데이터 최소화.** 게임 내 씨앗은 클라이언트 전용이며 서버 재화로 정산되지 않는다.

## 세션

웹 빌드에서 `HTTPRequest`는 세션 쿠키를 자동으로 보내지 않는다.
따라서 인증이 필요한 호출은 `JavaScriptBridge.eval` + `fetch(credentials:'include')`를 사용한다.

| 실행 환경 | 전송 경로 |
|---|---|
| 웹 (WASM) | `JavaScriptBridge.eval` → 브라우저 `fetch` → `window.<key>` 폴링 |
| 네이티브 | `HTTPRequest` (`_base_url()` = `http://127.0.0.1:8000`) |

인증 실패는 두 경로 모두 `code == 401` 로 통일해 처리한다.

## `GET /api/game/bootstrap`

한 번에 게임에 필요한 상태 전부를 내려준다. 응답 필드:

| 필드 | 타입 | 의미 |
|---|---|---|
| `ok` | bool | 성공 여부 |
| `guild_id`, `user_id`, `name` | str | 대상 서버·유저 |
| `xp`, `level` | int | 잔액·레벨 |
| `plot` | obj | 영토 슬롯·건설 남은 시간 |
| `farm` | obj | 밭·작물·성장 단계 |
| `fishing.spots` | array | 낚시터별 스태미나 비용 |
| `fishing.bait` | str | 장착 미끼 |
| `skills` | obj | 5종 숙련도·직업 |
| `hp` / `stamina` | obj | `cur`/`max`, `refill_cost` |
| `shop` / `sell_prices` / `cooking` | obj/array | 서버 config 기반 가격표 |
| `strengthen` | obj | 낚시대·무기 단계와 구간 |
| `potions` | obj | 카탈로그·보유 |
| `dungeon_kills` | int | 누적 처치 (영토 퀘스트 조건) |

`seeds_note: "게임 내 씨앗은 클라이언트 전용"` — 의도된 주석이다.

## `/api/game/plot/*`

| 상수 | 값 | 의미 |
|---|---|---|
| `PLOT_COST_BUY` | 4,000 XP | 목수에게 영토 구매 |
| `PLOT_COST_BUILD` | 3,000 XP | 집 건설 |
| `PLOT_SLOTS` | 4 | 유저당 최대 슬롯 |
| `PLOT_BUILD_SECONDS` | 180 | 건설 대기 시간 |

건설은 즉시 완료되지 않는다. 재화를 시간 축에 분산시키는 장치다.

## `/dashboard/{guild_id}/api/minigame/*` (29개)

던전(`enter`/`turn`), 낚시(`cast`/`resolve`), 농사(`till`/`water`/`plant`/`harvest`/`ship`/`day`),
포션(`buy`/`use`), 스태미나(`refill`), 숙련도(`skills`, `skills/profession`) 등.

모든 변경은 `_mg_mutate()` → `db.change_user()` 의 원자적 read-modify-write를 통과한다.
