class_name GunType
extends Resource
## 銃種(レシーバー)の基礎データ。1銃種 = data/guns/ のファイル1枚。
## ドロップした銃は、この基礎値にランダムなばらつきを掛けて作る(GunInstance)。

enum FireMode { AUTO, SEMI, CHARGE }

@export var id := ""
## ゲーム内の名前(架空名)
@export var display_name := ""
## 元ネタ(開発用。画面には出さない)
@export var reference := ""
@export_enum("古式", "19世紀", "世界大戦期", "冷戦期", "現代", "未来") var era := 0
@export var fire_mode := FireMode.AUTO

@export_group("性能")
@export var damage := 10.0
## 毎分の発射数
@export var rpm := 600.0
@export var magazine := 30
@export var reload_time := 2.0
## 1回の発射で出る弾の数(散弾など)
@export var pellets := 1
## 拡散(度)
@export var spread_deg := 2.0
@export var bullet_speed := 60.0
@export var bullet_size := 0.25
@export var bullet_color := Color(1.0, 0.8, 0.35)
@export var bullet_life := 2.5
## 反動(1発あたりの視点の跳ね上がり、度)
@export var recoil := 1.0
## 重さ(kg)。移動速度・回避距離・持ち替え時間に効く
@export var weight := 3.0
## チャージ式の溜め時間(秒)
@export var charge_time := 0.0
## true なら弾を飛ばさず撃った瞬間に着弾判定する(レールガンなど)
@export var hitscan := false
## 貫通できる敵の数(-1 で無制限)
@export var pierce := 0

@export_group("見た目")
## Blender スクリプトで作ったモデル。無ければ下の寸法から仮の箱モデルを組み立てる
@export_file("*.glb") var model_path := ""
## 仮モデル用の寸法(m): 本体の長さ, 本体の高さ, 銃身の長さ
@export var placeholder_dims := Vector3(0.4, 0.12, 0.35)
@export var body_color := Color(0.25, 0.25, 0.27)
@export var accent_color := Color(0.45, 0.30, 0.18)
## 銃口がラッパ型に広がる(ブランダーバス)
@export var flared_muzzle := false
## マガジンの形 0=箱 1=ドラム 2=なし(チューブ/単発) 3=エネルギーセル
@export var mag_shape := 0
## 構えたときの目から照門までの距離(m)。照門が銃の後ろ寄りなら短く、前寄り(AK など)なら長く
@export var ads_eye_dist := 0.2
