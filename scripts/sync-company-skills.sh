#!/bin/bash
# Sync company skills to all lobster containers
# Creates a REAL skills/ directory with individual symlinks to company-skills/
# This makes OpenClaw auto-discover company skills while keeping skills/ writable

COMPANY_SKILLS_PATH="/home/lobster/.openclaw/workspace/company-skills"
SKILLS_PATH="/home/lobster/.openclaw/workspace/skills"

sync_one_lobster() {
    local name="$1"
    local container="lobster-${name}"
    
    if ! sudo docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q true; then
        echo "⏭️  $container not running, skipping"
        return
    fi
    
    sudo docker exec "$container" bash -c "
        # If skills is a symlink to company-skills, replace with real dir
        if [ -L '$SKILLS_PATH' ]; then
            rm '$SKILLS_PATH'
            echo '  🔧 Removed symlink, creating real dir'
        fi
        
        mkdir -p '$SKILLS_PATH'
        chown lobster:lobster '$SKILLS_PATH'
        
        # Create individual symlinks for each company skill
        for skill_dir in $COMPANY_SKILLS_PATH/*/; do
            skill_name=\$(basename \"\$skill_dir\")
            link_path=\"$SKILLS_PATH/\$skill_name\"
            if [ -L \"\$link_path\" ] || [ ! -e \"\$link_path\" ]; then
                ln -sf \"$COMPANY_SKILLS_PATH/\$skill_name\" \"\$link_path\"
                echo \"  ✅ Linked: \$skill_name\"
            else
                echo \"  ⏭️  Exists (not symlink): \$skill_name\"
            fi
        done
        
        # Symlink policy files
        for f in SKILL_POLICY.md manifest.json; do
            if [ -f \"$COMPANY_SKILLS_PATH/\$f\" ]; then
                ln -sf \"$COMPANY_SKILLS_PATH/\$f\" \"$SKILLS_PATH/\$f\"
            fi
        done
    "
    echo "✅ $container synced"
}

if [ -n "$1" ]; then
    sync_one_lobster "$1"
else
    echo "🔄 Syncing company skills to all lobsters..."
    for container in $(sudo docker ps --format '{{.Names}}' | grep '^lobster-'); do
        name="${container#lobster-}"
        echo ""
        echo "📦 $container:"
        sync_one_lobster "$name"
    done
    echo ""
    echo "Done!"
fi
