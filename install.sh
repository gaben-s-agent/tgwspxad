pkg update -y
pkg install -y git python openssl termux-tools openssl-tool

python -m pip install "httpx[http2]==0.28.1" certifi

if [ ! -d "$HOME/tg-ws-proxy" ]; then
    git clone https://github.com/Flowseal/tg-ws-proxy.git "$HOME/tg-ws-proxy"
fi

# Создание постоянного Secret
if [ ! -f "$HOME/tg-ws-proxy.secret" ]; then
    openssl rand -hex 16 > "$HOME/tg-ws-proxy.secret"
fi

# Команда запуска
cat > "$PREFIX/bin/proxy-start" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

DIR="$HOME/tg-ws-proxy"
PIDFILE="$HOME/tg-ws-proxy.pid"
LOGFILE="$HOME/tg-ws-proxy.log"
SECRET=$(cat "$HOME/tg-ws-proxy.secret")

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Proxy is already running"
    exit 0
fi

nohup python "$DIR/proxy/tg_ws_proxy.py" \
    --host 127.0.0.1 \
    --port 1443 \
    --secret "$SECRET" \
    > "$LOGFILE" 2>&1 &

echo $! > "$PIDFILE"

sleep 2

if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
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
cat > "$PREFIX/bin/proxy-stop" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash

PIDFILE="$HOME/tg-ws-proxy.pid"

if [ ! -f "$PIDFILE" ]; then
    echo "Proxy is not running"
    exit 0
fi

PID=$(cat "$PIDFILE")

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "Proxy stopped!"
else
    echo "Proxy process not found"
fi

rm -f "$PIDFILE"
termux-wake-unlock
EOF

chmod +x "$PREFIX/bin/proxy-start" "$PREFIX/bin/proxy-stop"

echo ""
echo "================================"
echo "Installation completed!"
echo "Start proxy: proxy-start"
echo "Stop proxy:  proxy-stop"
echo "================================"
