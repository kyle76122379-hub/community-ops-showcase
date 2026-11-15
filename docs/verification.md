# 어떻게 검증했는가

"돌아간다"를 주장하지 않고, 확인한 방법을 남깁니다.

## 1. 무인 운영 (자동 복구)

| 확인 항목 | 방법 | 결과 |
|---|---|---|
| 프로세스 사망 시 재기동 | 워치독이 20초 주기로 상태를 확인하고 죽은 프로세스만 재시작 | 봇·웹 모두 자동 복구 |
| 재부팅 후 자동 기동 | 기기 재부팅 후 부팅 스크립트 실행 로그 확인 | `start.sh ran` 로그로 확인 |
| 중복 실행 방지 | 워치독 2개가 동시에 뜨지 않도록 PID + cmdline 검사 | 중복 기동 없음 |

실제 부팅 로그(발췌):

```
[2026-11-07 10:51:28] start.sh ran (pid 17044)
[2026-11-10 16:37:08] start.sh ran (pid 13686)
```

## 2. 배포 전 확인 절차

1. 증상 재현 → 로그에서 첫 에러 지점 확인
2. 가설 하나만 세우고 그 가설만 검증
3. 수정 후 **재기동 시험**(죽여서 다시 올라오는지)까지 수행
4. 성공/실패를 로그로 남겨 다음 판단의 근거로 사용

## 3. 단위 테스트 (저장소에서 직접 실행 가능)

숙련도·채집·농사 시스템은 DB·웹에 의존하지 않는 순수 로직으로 분리해 두어,
화면이나 서버 없이도 표준 라이브러리만으로 검증됩니다.

```bash
cd src
python test_skills.py      # === 17개 테스트 전부 통과 ===
python test_gathering.py   # === 13개 테스트 전부 통과 ===
```

실제 출력(발췌):

```
OK cumulative table 100/380/2150/15000
OK normalize handles bad data
OK profession_choices 2 each
=== 17개 테스트 전부 통과 ===

OK gather level gate
OK quality_roll (lv10 gold > lv0)
OK node tables (10 forage / 11 mine)
=== 13개 테스트 전부 통과 ===
```

농사(`test_farming.py`)까지 합쳐 **총 60개 테스트가 통과**합니다.
테스트는 "실패할 수 있는" 항목만 넣었습니다 — 레벨 경계값, 잘못된 입력 거부,
원작 규칙표의 누적 경험치 값(100/380/2150/15000)처럼 틀리면 즉시 깨지는 값입니다.

## 4. 화면 검증

- 34개 관리 화면을 실제 계정으로 열어 값 변경 → 봇 명령에서 즉시 반영되는지 확인
- 로그인(OAuth) 후 관리자 화면 접근 권한 확인
- 모바일 화면 폭에서 목록·정렬·검색 동작 확인

## 5. 수치 재측정

문서에 쓰는 수치는 작성 시점에 다시 잽니다(2026-11-15 기준).

```bash
find . -name "*.py" -not -path "*/__pycache__/*" -not -path "*/bak/*" -not -path "*/tmp/*" | wc -l   # 132
find . -name "*.py" -not -path "*/__pycache__/*" -not -path "*/bak/*" -not -path "*/tmp/*" -exec cat {} + | wc -l   # 57,860
ls web/templates/*.html | grep -v bak | wc -l                       # 34
sqlite3 user_data.db "select count(*) from users"                   # 220
sqlite3 market.db "select count(*) from stocks; select count(*) from trades;"  # 40 / 206
```

## 6. 검증하지 못한 것

- 외부 인터넷에서의 부하 테스트는 하지 않았습니다(단일 커뮤니티 환경).
- 결제·정산 기능은 없습니다(모의 주문만 존재).
- "총 220명"은 가입 누적이며, 실제 활동 기준(경험치 보유)은 193명입니다. 두 수치를 구분해 표기합니다.
