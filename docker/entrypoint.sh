#!/bin/sh
set -e

# Fix ownership of mounted volumes (running as root)
chown -R lobster:lobster /home/lobster/.openclaw 2>/dev/null || true
chown -R lobster:lobster /home/lobster/.vnc 2>/dev/null || true
chown -R lobster:lobster /home/lobster/.chrome-profile 2>/dev/null || true

# === Dotfiles persistence ===
# ~/.openclaw/ is on a persistent volume. We store dotfiles there and symlink
# standard paths so they survive container restarts.
DOTFILES_DIR="/home/lobster/.openclaw/dotfiles"
mkdir -p "$DOTFILES_DIR"

for pair in \
    ".ssh:ssh" \
    ".config/gh:config-gh" \
    ".gitconfig:gitconfig" \
    ".aws:aws" \
; do
    STD_PATH="/home/lobster/$(echo "$pair" | cut -d: -f1)"
    PERSIST_NAME="$(echo "$pair" | cut -d: -f2)"
    PERSIST_PATH="$DOTFILES_DIR/$PERSIST_NAME"

    # Create persistent location if needed
    case "$PERSIST_NAME" in
        gitconfig)
            [ -f "$PERSIST_PATH" ] || touch "$PERSIST_PATH" ;;
        *)
            mkdir -p "$PERSIST_PATH" ;;
    esac

    # Migrate existing data if not already a symlink
    if [ -e "$STD_PATH" ] && [ ! -L "$STD_PATH" ]; then
        case "$PERSIST_NAME" in
            gitconfig) cp -n "$STD_PATH" "$PERSIST_PATH" 2>/dev/null || true ;;
            *) cp -rn "$STD_PATH"/. "$PERSIST_PATH"/ 2>/dev/null || true ;;
        esac
        rm -rf "$STD_PATH"
    fi

    # Symlink
    mkdir -p "$(dirname "$STD_PATH")"
    [ -L "$STD_PATH" ] || ln -sf "$PERSIST_PATH" "$STD_PATH"
done

# SSH requires strict permissions
chmod 700 "$DOTFILES_DIR/ssh" 2>/dev/null || true
find "$DOTFILES_DIR/ssh" -type f -name "id_*" ! -name "*.pub" -exec chmod 600 {} \; 2>/dev/null || true
chown -R lobster:lobster "$DOTFILES_DIR"

# Fix ownership of intermediate dirs created by mkdir -p above
# Catch-all: any dir under /home/lobster that root accidentally created
for d in .config .cache .local; do
    chown lobster:lobster "/home/lobster/$d" 2>/dev/null || true
done

# Setup VNC password if not exists
if [ ! -f /home/lobster/.vnc/passwd ]; then
    VNC_PASS=$(head -c 12 /dev/urandom | base64 | head -c 10)
    echo "$VNC_PASS" > /home/lobster/.vnc/password-plain.txt
    gosu lobster sh -c "printf '$VNC_PASS\n$VNC_PASS\nn\n' | vncpasswd" 2>/dev/null
    chown lobster:lobster /home/lobster/.vnc/password-plain.txt
fi

# Setup VNC xstartup (v8: launch dbus session bus before xfce4)
cat > /home/lobster/.vnc/xstartup << 'XEOF'
#!/bin/sh
unset SESSION_MANAGER

# v8: Start a proper dbus session bus (fixes dbind-WARNING spam)
if command -v dbus-launch >/dev/null 2>&1; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS
fi

# Suppress accessibility bus warnings (no a11y needed in headless)
export NO_AT_BRIDGE=1

export XDG_SESSION_TYPE=x11
exec startxfce4
XEOF
chmod +x /home/lobster/.vnc/xstartup
chown lobster:lobster /home/lobster/.vnc/xstartup

# Clean stale state before VNC start
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 /tmp/dbus-* /tmp/tigervnc.* 2>/dev/null || true

# Ensure X11/ICE tmp dirs exist with correct perms
mkdir -p /tmp/.X11-unix /tmp/.ICE-unix
chmod 1777 /tmp/.X11-unix /tmp/.ICE-unix

# Start VNC server as lobster
gosu lobster vncserver :1 -geometry 1280x800 -depth 24 -localhost yes 2>/dev/null || true

# Start Chrome with CDP as lobster
gosu lobster sh -c '
  export DISPLAY=:1
  google-chrome \
    --no-first-run --no-default-browser-check \
    --no-sandbox --disable-dev-shm-usage \
    --enable-webgl --use-gl=swiftshader \
    --remote-debugging-port=9222 --remote-debugging-address=127.0.0.1 \
    --user-data-dir=/home/lobster/.chrome-profile \
    --crash-dumps-dir=/tmp/chrome-crashes \
    &>/tmp/chrome-cdp.log &
'

# Start noVNC
gosu lobster sh -c '
  /opt/noVNC/utils/novnc_proxy --vnc localhost:5901 --listen 6080 &>/tmp/novnc.log &
'

sleep 2

# === Sync company skills ===
# Create symlinks from company-skills/ to workspace/skills/ so OpenClaw discovers them
COMPANY_SKILLS="/home/lobster/.openclaw/workspace/company-skills"
WS_SKILLS="/home/lobster/.openclaw/workspace/skills"
if [ -d "$COMPANY_SKILLS" ]; then
    mkdir -p "$WS_SKILLS"
    chown lobster:lobster "$WS_SKILLS"
    for skill_dir in "$COMPANY_SKILLS"/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        link_path="$WS_SKILLS/$skill_name"
        if [ -L "$link_path" ] || [ ! -e "$link_path" ]; then
            ln -sfn "$COMPANY_SKILLS/$skill_name" "$link_path"
        fi
    done
    # Symlink policy files
    for f in SKILL_POLICY.md manifest.json; do
        [ -f "$COMPANY_SKILLS/$f" ] && ln -sfn "$COMPANY_SKILLS/$f" "$WS_SKILLS/$f"
    done
fi

# Clean up stale session lock files from previous crash
find /home/lobster/.openclaw/agents -name "*.lock" -delete 2>/dev/null || true

# Switch to lobster and run the main command (OpenClaw)
exec gosu lobster env HOME=/home/lobster "$@"
