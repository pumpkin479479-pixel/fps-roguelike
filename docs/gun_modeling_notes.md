# 銃モデル作りの覚え書き

調べたことと、このプロジェクトで決めたやり方のまとめです。新しい銃を作るときに読んでください。

## 画風(2026-11-19 決定)
- SULFUR 寄りのデフォルメ。全体の形・比率は設定画の「中くらい」、照準器・ハンドル・ピンなどの部品は「強め」くらい太く大きく。
- 設定画を先に画像生成して(docs/concept/)、それに寄せてモデルを作る。
- ゴア表現は無し。

## 照準器は「構えた画面」から逆算する
- 実銃の照準器はゲームでは小さく細すぎる。構えたときに見やすい大きさへ広げるのが定番。
  照準器の周りが混み合うと狙いにくいという不満が多いので、柱の左右は広く空ける。
- やり方(tools/blender/ak47.py の「照準像の設計」):
  1. 構え中の視野角(縦 52°)と画面の高さ(900px)から、1ラジアンあたりのピクセル数を出す。
  2. 画面上の大きさをピクセルで決める(例: 溝の幅 90px、溝の深さ 45px、柱の太さ 14px、耳の内側の空き 72px)。
  3. 目からの距離で実寸に直す: 実寸 = px / PX_PER_RAD × 距離。照門は目に近いので小さく、照星は遠いので太くなる。
  4. 銃ごとに数値を変えれば、狙いやすさの差を意図して付けられる。
- 照準線の高さは、上蓋などから十分上げる。低いと、構えたとき手前の本体が画面の下半分を塞ぐ。
- 目から照門までの距離は data/guns/*.tres の ads_eye_dist と、モデルのスクリプトの EYE_DIST をそろえる。

## 可動部と排莢
- 動く部品は別の部品として書き出し、Godot 側のコードで動かす(Blender のアニメーションは使わない)。
  - "bolt": ボルトとコッキングハンドル。撃つたびに後ろへ下がって戻る(gun_holder.gd の _update_bolt)。
  - "ejection_port": 薬莢が出る位置。ここから右上へ薬莢を飛ばす(gun_holder.gd の Casing)。
  - "magazine": リロードで抜き差しする予定。
- 動きが見えるように、ボルトやハンドルが一人称で見える側(右)に来るようにしておく。

## 形の作り方
- 面取り(ベベル)で角に光を拾わせる。大きな平面に斜めの陰が出たら、
  平面ばかりの部品は面ごとに平らに塗る(gunlib.bevel の flat=True)か、Weighted Normal で面の向きを整える。
- 座標を入れ替えて作った形は面が裏返ることがある。裏返ると、削り(ブーリアン)が失敗し、
  Godot では裏面が描かれないので面が消える。gunlib._new_object で必ず外向きに直している。
- 削りで、削る形どうしの面がぴったり重なると失敗しやすい。わずかにずらす。
- 細部は一人称でよく見える上面・右側面・照準器に集中させる。ストックの後端など目に入らない所は控えめでよい。

## 素材
- 単色の部品に、シェーダー(shaders/gun_surface.gdshader)で角の擦れ・傷・色むら・木目を付ける。
  使い込み具合と模様の位置は銃のシード値とレア度で決まる。
- 自動の擦れは機械的に見えやすい。手描き風にするなら、傷や塗りムラの画像(Codex / Gemini で作る)を重ねる。

## 今後試すとよいこと
- 一人称の銃を、世界とは別の視野角で描く(Godot ではシェーダーで投影を差し替える方法が定番)。
  壁へのめり込みも防げる。
- 輪郭線(設定画の太い黒い線)。
- ツール: Blender の Python に Pillow を入れると、確認用の一覧画像が自動で作られる。
  手描き風テクスチャには Material Maker(無料、Godot 製)が候補。手で操作する人向けの有料アドオンは、このやり方では効果が薄い。

## 参考
- 照準器を見やすく大きくする、可動部を見せる、自動の擦れは手直しする: https://80.lv/articles/thoughts-on-weapons-for-games
- AAA の銃の作り方(参照集め、シルエット優先、汚れは段階的に): https://cubebrush.co/blog/fps-weapon-creation-how-to-match-aaa-standards
- 照準器周りが混み合うと狙いにくい: https://allthings.how/borderlands-4s-busy-scopes-why-ads-feels-worse-than-hip-fire
- 面取りと Weighted Normal: https://80.lv/articles/hard-surface-modeling-tips-tricks-for-creating-a-vintage-quirky-looking-gun
- 一人称の銃を別の視野角で描く Godot のシェーダー: https://godotshaders.com/shader/first-person-view-model-shader-updated-for-godot-4-3/
- 薬莢の飛び方: https://forum.godotengine.org/t/realistic-cartridge-case-ejection/125513
