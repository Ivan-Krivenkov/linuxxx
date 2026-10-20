#!/bin/bash
set -euo pipefail

BASE_DIR="$(pwd)/test_env"
LOG_DIR="${BASE_DIR}/log"
BACKUP_DIR="${BASE_DIR}/backup"
CLEANER="$(pwd)/cleaner.sh"
LIMIT_MB=1024

setup() {
    rm -rf "$BASE_DIR"
    mkdir -p "$LOG_DIR" "$BACKUP_DIR"
}

cleanup() {
    rm -rf "$BASE_DIR"
}
trap cleanup EXIT

get_current_pct() {
    local size_kb=$(du -sk "$LOG_DIR" | cut -f1)
    echo $((size_kb * 100 / (LIMIT_MB * 1024)))
}

run_cleaner() {
    if ! bash "$CLEANER" "$@"; then
        echo "cleaner завершился с ошибкой"
        exit 1
    fi
}

setup
fallocate -l 520M "${LOG_DIR}/file1.log"
export LAB1_MAX_COMPRESSION=0
run_cleaner "$LOG_DIR" 90 "$BACKUP_DIR"

if [ -f "${LOG_DIR}/file1.log" ] && [ -z "$(ls -A "$BACKUP_DIR")" ]; then
    echo "Тест 1 пройден"
else
    echo "Тест 1 провален"; exit 1
fi

setup
fallocate -l 800M "${LOG_DIR}/old.log"
export LAB1_MAX_COMPRESSION=0
run_cleaner "$LOG_DIR" 50 "$BACKUP_DIR"

ARCHIVE=$(ls "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | head -n 1) || true
if [ -n "$ARCHIVE" ] && tar -tzf "$ARCHIVE" > /dev/null 2>&1; then
    echo "Тест 2 пройден"
else
    echo "Тест 2 провален"; exit 1
fi

setup
fallocate -l 600M "${LOG_DIR}/oldest.log"
touch -d "5 days ago" "${LOG_DIR}/oldest.log"
fallocate -l 300M "${LOG_DIR}/newest.log"
touch -d "1 hour ago" "${LOG_DIR}/newest.log"
export LAB1_MAX_COMPRESSION=0
run_cleaner "$LOG_DIR" 50 "$BACKUP_DIR"

if [ ! -f "${LOG_DIR}/oldest.log" ] && [ -f "${LOG_DIR}/newest.log" ]; then
    echo "Тест 3 пройден"
else
    echo "Тест 3 провален"; exit 1
fi

if command -v xz >/dev/null 2>&1 || command -v lzma >/dev/null 2>&1; then
    setup
    fallocate -l 800M "${LOG_DIR}/data.log"
    export LAB1_MAX_COMPRESSION=1
    run_cleaner "$LOG_DIR" 50 "$BACKUP_DIR"
    
    ARCHIVE=$(ls "${BACKUP_DIR}"/backup_*.tar.lzma 2>/dev/null | head -n 1) || true
    if [ -n "$ARCHIVE" ] && tar --lzma -tf "$ARCHIVE" > /dev/null 2>&1; then
        echo "Тест 4 пройден"
    else
        echo "Тест 4 провален"; exit 1
    fi
else
    echo "Тест 4 пропущен (нет xz/lzma)"
fi

echo "Все тесты пройдены!"
