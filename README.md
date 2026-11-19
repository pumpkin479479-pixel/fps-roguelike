# fps-roguelike

マルチプレイ対応の FPS ローグライク(開発中)。

## 開発環境

- Godot 4.7.2(Forward+ レンダラー)
- Blender 5.3.0(3D アセット制作)
- Git + Git LFS(画像・音声・モデルなどのバイナリは LFS で管理)

## はじめかた

1. `git lfs install` を一度実行しておく
2. このリポジトリをクローンする
3. Godot で `project.godot` を開く

メインシーンは試射場 `scenes/test_range.tscn` です(F5 で起動)。

- M1(銃と弾幕の試作)の内容、操作、負荷テストの使い方: [docs/M1.md](docs/M1.md)
- 弾幕の負荷テスト: `tools\bench\run_bench.bat`
- 銃モデルの作り直し: `tools\blender\build_all.bat`
