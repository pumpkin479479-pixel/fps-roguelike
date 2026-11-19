#!/bin/sh
# 弾幕の負荷テスト(Linux / macOS / CI)。--headless を付けると描画なしで弾の計算だけを測る。
cd "$(dirname "$0")/../.." || exit 1
exec "${GODOT:-godot}" --path . res://scenes/bench.tscn -- --quit "$@"
