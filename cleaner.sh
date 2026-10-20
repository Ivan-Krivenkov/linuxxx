#!/bin/bash
set -euo pipefail

LOG_DIR="$1"
THRESHOLD="$2"
BACKUP_DIR="$3"
LIMIT_MB=1024
LIMIT_KB=$((LIMIT_MB * 1024))

mkdir -p "$BACKUP_DIR"

SIZE_KB=$(du -sk "$LOG_DIR" | cut -f1)
PERCENT=$((SIZE_KB * 100 / LIMIT_KB))

echo "Папка: $LOG_DIR | Занято: ${PERCENT}% | Порог: ${THRESHOLD}%"

if [ "$PERCENT" -le "$THRESHOLD" ]; then
    echo "Порог не превышен. Выход."
    exit 0
fi

echo "Порог превышен! Начинаем архивацию."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ "${LAB1_MAX_COMPRESSION:-0}" == "1" ]; then
    EXT="tar.lzma"
    TAR_OPTS="--lzma -cf"
else
    EXT="tar.gz"
    TAR_OPTS="-czf"
fi
ARCHIVE="$BACKUP_DIR/backup_${TIMESTAMP}.${EXT}"

TARGET_KB=$((LIMIT_KB * THRESHOLD / 100))
NEED_TO_FREE_KB=$((SIZE_KB - TARGET_KB))

FILES=()
FREED_KB=0

while IFS= read -r line; do
    if [ "$FREED_KB" -ge "$NEED_TO_FREE_KB" ]; then break; fi
    FILE_SIZE=$(echo "$line" | awk '{print $2}')
    FILE_NAME=$(echo "$line" | cut -d' ' -f3-)

    FILES+=("$FILE_NAME")
    FREED_KB=$((FREED_KB + FILE_SIZE / 1024))
done < <(find "$LOG_DIR" -maxdepth 1 -type f -printf '%T@ %s %f\n' | sort -n)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "Файлов для архивации нет."
    exit 0
fi

tar $TAR_OPTS "$ARCHIVE" -C "$LOG_DIR" "${FILES[@]}"

for f in "${FILES[@]}"; do
    rm -f "$LOG_DIR/$f"
done

echo "Архив создан: $ARCHIVE"
