#!/data/data/com.termux/files/usr/bin/bash
# HA.NA 자동 복구 워치독
# - 봇(main.py)과 웹(uvicorn)이 죽으면 20초 안에 다시 올린다
# - termux-wake-lock 으로 안드로이드 절전 종료를 막는다

BASE=/data/data/com.termux/files/home/discord-bot
PY=/data/data/com.termux/files/usr/bin/python
PY3=/data/data/com.termux/files/usr/bin/python3
LOG=$HOME/keepalive.log
LOCK=$HOME/keepalive.pid

# 이미 실행 중이면 즉시 종료 (부팅 스크립트 + 수동 실행이 겹쳐도 안전)
# PID 재사용 대비: 해당 PID 의 cmdline 에 keepalive.sh 가 있는지까지 확인
if [ -f "$LOCK" ]; then
  OLD=$(cat "$LOCK" 2>/dev/null)
  if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null && tr '\0' ' ' < "/proc/$OLD/cmdline" 2>/dev/null | grep -q "keepalive.sh"; then
    exit 0
  fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT INT TERM

[ -x "$(command -v termux-wake-lock 2>/dev/null)" ] && termux-wake-lock 2>/dev/null

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

is_running() {
  local pat="$1" p c
  for p in /proc/[0-9]*; do
    c=$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null) || continue
    case "$c" in
      *"$pat"*) return 0 ;;
    esac
  done
  return 1
}

start_bot() {
  cd "$BASE" || return 1
  nohup "$PY" main.py >> "$HOME/bot.log" 2>&1 &
  log "bot started (pid $!)"
}

start_web() {
  cd "$BASE" || return 1
  nohup "$PY3" -m uvicorn web.main:app --host 127.0.0.1 --port 8000 >> "$BASE/web.log" 2>&1 &
  log "web started (pid $!)"
}

log "watchdog started (pid $$)"

while true; do
  is_running "$PY main.py " || start_bot
  is_running "$PY3 -m uvicorn web.main:app " || start_web
  sleep 20
done
