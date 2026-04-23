#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${PADDLEOCR_VENV_DIR:-$ROOT_DIR/.venv-paddleocr}"
HOST="${PADDLEOCR_HOST:-0.0.0.0}"
PORT="${PADDLEOCR_PORT:-8080}"
DEVICE="${PADDLEOCR_DEVICE:-cpu}"

if [[ ! -d "$VENV_DIR" ]]; then
  python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

python -m pip install --upgrade pip
python -m pip install "paddlex[ocr]"
paddlex --install serving

echo "Starting PaddleOCR server on http://$HOST:$PORT/ocr using device=$DEVICE"
exec paddlex --serve --pipeline OCR --host "$HOST" --port "$PORT" --device "$DEVICE"
