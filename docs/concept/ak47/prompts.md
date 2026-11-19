# AK 設定画(デフォルメ3段階)の指示文

- 生成モデル: Gemini `gemini-3-pro-image`(API のモデル一覧で画像を出せるもののうち、最新の正式版)
- 設定: `responseModalities: ["IMAGE"]`、`imageConfig.aspectRatio: "16:9"`(出力 1376×768)
- Gemini は JPEG を返すので、PNG に変換して保存している。
- 指示文は「共通」+「段階」+「視点」をつなげたもの。斜め後ろ上(rear)と一人称(ads)は、その段階の真横(side)の画像を参考画像として一緒に渡し、末尾に「参考画像への指示」を付けた。

## 共通

```
Concept art for a first-person shooter game weapon: an AK-47 Type 3 (milled receiver, wooden fixed stock, wooden handguards and pistol grip, curved 30-round steel magazine). Stylized like the indie game SULFUR: chunky, readable, slightly toy-like stylization with believable mechanics. Hand-painted look, clear color separation: dark blued/black steel, reddish-brown wood. Worn edges with lighter bare-metal scuffs on corners, fine scratches, subtle dirt. No text, no letters, no logos, no markings, no watermark, no gore, no hands or people unless stated. Single weapon only.
```

## 段階

| 段階 | 指示文 |
|---|---|
| low(控えめ) | `Stylization: LOW. Proportions close to the real rifle; parts only slightly thicker and edges slightly softened; most real details kept.` |
| mid(中くらい) | `Stylization: MEDIUM. Iron sights, magazine and charging handle about 20-30% larger than real; small details (pins, rivets, small screws) simplified or removed; thicker, chunkier parts with bold bevels.` |
| high(強め) | `Stylization: HIGH. Toy-like chunky blocky shapes, very thick parts, oversized sights, magazine and charging handle, big rounded bevels, very few small details, strong silhouette; still clearly recognizable as an AK.` |

## 視点

### side(真横・右側面)

```
View: exact orthographic view of the rifle's RIGHT side (the side with the charging handle and the selector lever), so the muzzle points to the LEFT of the image and the stock is on the right. The long flat selector lever on the receiver side and the charging handle sticking out near the rear sight must be clearly visible; the ENTIRE rifle from muzzle to buttstock fits inside the frame with generous white margin on all sides, nothing cropped, centered, plain pure white background, even studio lighting.
```

### rear(斜め後ろ上から)

```
View: three-quarter view from behind and above the rifle (looking down at the top cover and right side from the rear), whole rifle visible, plain light grey background.
```

### ads(一人称で構えた視点)

```
View: first-person aim-down-sights view in a game, the shooter's eye placed exactly at the height of the rear sight notch, a few centimeters behind it, looking straight forward along the barrel (not from above). The rear sight leaf with its U-notch is large in the foreground, and the front sight post sits inside the notch, exactly at the center of the image. Only the rear end of the top cover and the rear sight are visible in the lower center; slightly zoomed in so the iron sights are big and easy to read. Background: a simple sunlit concrete test range with targets, softly out of focus. No HUD, no crosshair, no hands.
```

### 参考画像への指示(rear / ads のみ)

```
Use the attached image as the exact design reference: keep the same rifle design, proportions, colors and level of stylization, only change the view.
```

## 作り直しの記録

- side の最初の指示は「muzzle pointing to the right」だった。これだと、右側面の部品(セレクター・コッキングハンドル)を描いたまま銃口が右を向く、左右反転した銃が出た。そこで「右側面なので銃口は左」と明示し、セレクターとハンドルを必ず描くよう指示を足した。
- それでもモデルは銃口を右に向けがちで、mid と high の side は、右側面の部品付きのまま銃口が右向きで出た。この2枚は**左右反転して保存**している(反転すると正しい右側面・銃口が左になる)。low の side は指示どおり銃口が左向きで出たのでそのまま。
- mid の side は1回目で銃口側が画面外に切れたため、「銃全体を余白付きで収める」指示を足して作り直した。
- low の ads は1回目がカメラ高めの見下ろし構図だったため、ads の指示を上の「目の高さをリアサイトの切り欠きに合わせる」版に直して作り直した(mid / high の ads は直した版で1回で生成)。
- mid の rear は1回目に関係のない木の部品がもう1本写り込んだため、同じ指示文で引き直した。
- rear は3段階とも、ストックの後端が画面の左外に少し切れている。
