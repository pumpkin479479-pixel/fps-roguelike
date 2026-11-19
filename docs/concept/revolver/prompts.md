# リボルバー設定画の指示文

- 生成モデル: Gemini `gemini-3-pro-image`(`responseModalities: ["IMAGE"]`、`aspectRatio: "16:9"`、出力 1376×768)。Gemini は JPEG を返すので PNG に変換して保存。
- 指示文は「共通」+「視点」。rear / ads / open は、`rev_side.png` を参考画像として渡し、末尾に「参考画像への指示」を付けた。

## 共通

```
Concept art for a first-person shooter game weapon: a medium-frame swing-out-cylinder .357 double-action revolver with a 4-inch barrel, a full-length underlug under the barrel that shrouds the ejector rod, a vented rib on top of the barrel, a square adjustable rear sight, a ramp front sight, a six-round cylinder with flutes, an exposed hammer, and wooden grips. Do not depict any specific real-world brand or model, no logos, no engravings, no text. Stylized like the indie game SULFUR: overall shape moderately stylized, parts chunky and thick with big rounded bevels and few small details, slightly toy-like but mechanically believable. Hand-painted look, clear color separation: dark blued/black steel and reddish-brown wood, brass cartridge cases. Worn edges with lighter bare-metal scuffs on corners, fine scratches. No text, no letters, no logos, no watermark, no gore. Single weapon only.
```

## 視点

### side(真横)

```
View: exact orthographic view of the revolver's RIGHT side (the side WITHOUT the cylinder release thumb latch; the cylinder swings out to the other side). IMPORTANT: the muzzle points to the RIGHT of the image and the grip is at the lower left; hammer down, cylinder closed; whole gun inside the frame with generous margin, nothing cropped, plain pure white background, even studio lighting. No hands.
```

### rear(斜め後ろ上から)

```
View: a NEW camera angle (do not reuse the side-view layout of the reference): a three-quarter view from behind and above the revolver, the muzzle pointing away from the viewer into the distance toward the upper right (looking down at the top rib, rear sight, hammer and the right side), exactly one revolver, the whole gun visible inside the frame, plain light grey background. No hands.
```

### ads(構えた視点・照門越し)

```
View: first-person aim-down-sights view in a game, the shooter's eye exactly at the height of the rear sight notch, a few centimeters behind it, looking straight along the top rib. The square rear sight notch is large in the foreground and the front sight post sits inside the notch exactly at the center of the image, tops level. The hammer spur and the top of the frame are visible at the bottom center; slightly zoomed in so the sights are big and easy to read. Background: a simple sunlit concrete test range with targets, softly out of focus. No HUD, no crosshair, no hands.
```

### open(シリンダー振り出し・排莢中)

```
View: three-quarter view from the LEFT FRONT of the revolver. The cylinder is swung out to the LEFT side of the frame on its crane (yoke); the ejector rod is pushed in, so the star-shaped extractor stands out from the rear of the cylinder and six empty brass cases are being pushed out and flying away from the cylinder. The empty cylinder chambers are visible. Whole gun inside the frame, plain white background. No hands.
```

### 参考画像への指示(rear / ads / open)

```
Use the attached image as the exact design reference: keep the same revolver design, proportions, colors and level of stylization, only change the view and state.
```

## 結果と作り直しの記録

- **rev_side.png は右側面ではなく左側面の絵。** 右側面を2回指示した(2回目は「シリンダーの留め金が無い側」「銃口は右」と明示)。それでも2回とも、銃口が左向きで、シリンダーの留め金と押し棒(エジェクターロッド)の見える左側面が出た。左右反転すると留め金が右に付いた鏡写しの銃になるので、反転せずに「左側面」として採用した。留め金・押し棒・下のラグが見えるので、モデル作りの資料としてはむしろ情報が多い。
- 向きの確認: 右側面を見る人は銃の右側に立つので、**右側面の真横図では銃口は画面の右を向く**(左側面なら左)。
- rear: 1回目は、参考画像の真横の構図を引きずって、リボルバー2丁が重なった絵になった。「新しいカメラ角度で」「銃口は奥の右上へ」と足して作り直した(2回目を採用。グリップの下端が少し切れている)。
- ads: 1回で採用。四角い照門の切り欠きの中に照星が入り、撃鉄とシリンダーの縁も見える。
- open: 1回で採用。指示した左斜め前ではなく、真横(左側面)寄りの構図。シリンダーが手前(左)へ振り出され、押し棒が押し込まれて6つの薬莢が飛び出している。
