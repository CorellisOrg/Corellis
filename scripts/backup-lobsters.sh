#!/bin/bash
# Lobster data backup script
# Runs daily, keeps the latest 2 backups per lobster

BACKUP_DIR="${BACKUP_DIR:-~/backups/lobsters}"
FARM_DIR="${LOBSTER_FARM_DIR:-~/corellis}"
MAX_BACKUPS=2
DATE=$(date +%Y-%m-%d)

mkdir -p "$BACKUP_DIR"

echo "=== Lobster backup started: $DATE ==="

# 1. Backup host files (configs, company-memory, company-skills, .env, docker-compose.yml)
FARM_BACKUP="$BACKUP_DIR/farm-$DATE.tar.gz"
tar czf "$FARM_BACKUP" -C "$FARM_DIR" configs company-memory company-skills .env docker-compose.yml 2>/dev/null
echo "✅ Lobster farm config backup: $FARM_BACKUP ($(du -sh "$FARM_BACKUP" | cut -f1))"

# Clean up old farm backups
ls -t "$BACKUP_DIR"/farm-*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f 2>/dev/null

# 2. Backup each lobster's Docker volume
for vol in $(docker volume ls -q | grep '_lobster-' 2>/dev/null); do
    LOBSTER_NAME=$(echo "$vol" | sed 's/.*_lobster-\(.*\)-data/\1/')
    LOBSTER_BACKUP_DIR="$BACKUP_DIR/$LOBSTER_NAME"
    mkdir -p "$LOBSTER_BACKUP_DIR"
    
    BACKUP_FILE="$LOBSTER_BACKUP_DIR/$DATE.tar.gz"
    
    # Use a temporary container to mount the volume and archive it
    docker run --rm \
        -v "$vol":/data:ro \
        -v "$LOBSTER_BACKUP_DIR":/backup \
        alpine tar czf "/backup/$DATE.tar.gz" -C /data . 2>/dev/null
    
    if [ -f "$BACKUP_FILE" ]; then
        SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
        echo "✅ $LOBSTER_NAME backup: $BACKUP_FILE ($SIZE)"
    else
        echo "❌ $LOBSTER_NAME backup failed"
    fi
    
    # Keep only the latest MAX_BACKUPS backups
    ls -t "$LOBSTER_BACKUP_DIR"/*.tar.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs rm -f 2>/dev/null
done

echo "=== Backup complete ==="
# Total size
TOTAL=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "Total backup size: $TOTAL"
