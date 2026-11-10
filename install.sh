#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

trap 'echo ""; echo "ОШИБКА установки. Этап: $BASH_COMMAND"; echo "Проверьте подключение и попробуйте повторить установку."' ERR

echo "=== Telegram WS Proxy Installer ==="

# Обновление системы
pkg update -y
pkg upgrade -y

# Системные зависимости
pkg install -y git python python-pip openssl termux-tools libexpat

# Проверка Python и Expat
python -c "import pyexpat" || {
    echo "Python/Expat не работают. Повторная синхронизация пакетов..."
    pkg reinstall -y libexpat python
    python -c "import pyexpat"
}

# Загрузка проекта
if [ ! -d "$HOME/tg-ws-proxy" ]; then
    git clone https://github.com/Flowseal/tg-ws-proxy.git "$HOME/tg-ws-proxy"
fi

DIR="$HOME/tg-ws-proxy"
VENV="$DIR/venv"

# Создание виртуального окружения
python -m venv --system-site-packages "$VENV"

# Установка зависимостей
"$VENV/bin/python" -m pip install "httpx[http2]==0.28.1" certifi

# Проверка зависимостей
"$VENV/bin/python" -c "import httpx, certifi"

# Создание Secret, если его ещё нет
if [ ! -f "$HOME/tg-ws-proxy.secret" ]; then
    openssl rand -hex 16 > "$HOME/tg-ws-proxy.secret"
    chmod 600 "$HOME/tg-ws-proxy.secret"
fi

# Команда запуска
cat > "$PREFIX/bin/tgws-start" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

DIR="$HOME/tg-ws-proxy"
PYTHON="$DIR/venv/bin/python"
SCRIPT="$DIR/proxy/tg_ws_proxy.py"
PIDFILE="$HOME/tg-ws-proxy.pid"
LOGFILE="$HOME/tg-ws-proxy.log"
SECRET=$(cat "$HOME/tg-ws-proxy.secret")

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null && ps -p "$PID" -o args= | grep -Fq "$SCRIPT"; then
        echo "Proxy is already running"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

nohup "$PYTHON" "$SCRIPT" \
    --host 127.0.0.1 \
    --port 1443 \
    --secret "$SECRET" \
    > "$LOGFILE" 2>&1 &

echo $! > "$PIDFILE"
sleep 2

PID=$(cat "$PIDFILE")

if ! kill -0 "$PID" 2>/dev/null || ! ps -p "$PID" -o args= | grep -Fq "$SCRIPT"; then
    echo "Proxy failed to start:"
    cat "$LOGFILE"
    rm -f "$PIDFILE"
    exit 1
fi

termux-wake-lock

echo "Proxy started!"
echo "tg://proxy?server=127.0.0.1&port=1443&secret=dd${SECRET}"
EOF

# Команда остановки
cat > "$PREFIX/bin/tgws-stop" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

PIDFILE="$HOME/tg-ws-proxy.pid"
SCRIPT="$HOME/tg-ws-proxy/proxy/tg_ws_proxy.py"

if [ ! -f "$PIDFILE" ]; then
    echo "Proxy is not running"
    exit 0
fi

PID=$(cat "$PIDFILE")

if kill -0 "$PID" 2>/dev/null && ps -p "$PID" -o args= | grep -Fq "$SCRIPT"; then
    kill "$PID"
    echo "Proxy stopped!"
else
    echo "Proxy process not found"
fi

rm -f "$PIDFILE"
termux-wake-unlock
EOF

# Команда полного удаления
cat > "$PREFIX/bin/tgws-uninstall" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

echo "Stopping proxy..."

PIDFILE="$HOME/tg-ws-proxy.pid"
SCRIPT="$HOME/tg-ws-proxy/proxy/tg_ws_proxy.py"

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")

    if kill -0 "$PID" 2>/dev/null && ps -p "$PID" -o args= | grep -Fq "$SCRIPT"; then
        kill "$PID"
        sleep 2

        if kill -0 "$PID" 2>/dev/null; then
            kill -9 "$PID" 2>/dev/null || true
        fi
    fi
fi

termux-wake-unlock 2>/dev/null || true

echo "Removing proxy files..."

rm -rf "$HOME/tg-ws-proxy"
rm -f "$HOME/tg-ws-proxy.secret"
rm -f "$HOME/tg-ws-proxy.pid"
rm -f "$HOME/tg-ws-proxy.log"

# Удаление ярлыков Termux:Widget
rm -f "$HOME/.shortcuts/tgws-start"
rm -f "$HOME/.shortcuts/tgws-stop"

# Удаление команд
rm -f "$PREFIX/bin/tgws-start"
rm -f "$PREFIX/bin/tgws-stop"
rm -f "$PREFIX/bin/tgws-uninstall"

echo ""
echo "================================"
echo "       UNINSTALL COMPLETE"
echo "================================"
EOF

chmod +x "$PREFIX/bin/tgws-start" "$PREFIX/bin/tgws-stop" "$PREFIX/bin/tgws-uninstall"

mkdir -p "$HOME/.shortcuts"

cat > "$HOME/.shortcuts/tgws-start" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
tgws-start
EOF

cat > "$HOME/.shortcuts/tgws-stop" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
tgws-stop
EOF

chmod +x "$HOME/.shortcuts/tgws-start" "$HOME/.shortcuts/tgws-stop"

echo ""
echo "=================================="
echo "       INSTALLATION COMPLETE"
echo "=================================="
echo "Start: tgws-start"
echo "Stop:  tgws-stop"
echo "Uninstall: tgws-uninstall"
echo "=================================="
