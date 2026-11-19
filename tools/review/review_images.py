"""画像を Codex(OpenAI)に見せて、厳しめの評価をもらう(--gemini を付けると Gemini にも)。
既定は Codex だけ(2026-11-19 アルさんの方針)。

使い方(アルさんの PC):
    python tools/review/review_images.py --prompt-file tools/review/prompts/gun_model.md \
        --out tools/review/out/ak47.md tools/blender/renders/ak47_*.png

- Gemini … 環境変数 GEMINI_API_KEY で REST API を直接呼ぶ(追加のライブラリ不要)。
            コストを抑えるため安いモデルを使う(既定は下の CHEAP_MODELS を順に試す。GEMINI_MODEL で上書き可)。
            1回ごとのトークン数と概算金額を結果の Markdown と tools/review/out/usage.jsonl に残す。
            (2026-11-19 アルさんの方針: Gemini の評価は安いモデルで。画像生成は Codex だけで行い、Gemini では作らない)
- Codex  … PC にログイン済みの `codex exec` に画像を渡す(読み取り専用で実行)。
どちらか片方が失敗しても、もう片方の結果は出す。結果は1つの Markdown にまとめる。
"""

import argparse
import base64
import json
import mimetypes
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://generativelanguage.googleapis.com/v1beta"

## 安い順の候補と単価(USD / 100万トークン: 入力, 出力)。出典: https://ai.google.dev/gemini-api/docs/pricing(2026-11-19 時点)
CHEAP_MODELS = [
    ("gemini-3.1-flash-lite", 0.25, 1.50),
    ("gemini-3.5-flash-lite", 0.30, 2.50),  # 公式の料金表に未掲載。単価は外部サイトの値
    ("gemini-2.5-flash-lite", 0.10, 0.40),
    ("gemini-3-flash", 0.50, 3.00),
    ("gemini-2.5-flash", 0.30, 2.50),
]
USAGE_LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "usage.jsonl")


def _price(model):
    for prefix, pin, pout in CHEAP_MODELS:
        if model.startswith(prefix):
            return pin, pout
    return None


def _log_usage(entry):
    os.makedirs(os.path.dirname(USAGE_LOG), exist_ok=True)
    with open(USAGE_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def gemini_models(key):
    """使えるモデルのうち、CHEAP_MODELS に当てはまるものを安い候補の順に返す。GEMINI_MODEL があれば最優先。"""
    available = []
    try:
        req = urllib.request.Request(f"{API}/models?pageSize=200", headers={"x-goog-api-key": key})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = json.load(r)
        for m in data.get("models", []):
            n = m.get("name", "").removeprefix("models/")
            if "generateContent" in m.get("supportedGenerationMethods", []):
                available.append(n)
    except Exception as e:  # noqa: BLE001
        print(f"[review] モデル一覧の取得に失敗: {e}")
    picked = []
    for prefix, _pin, _pout in CHEAP_MODELS:
        # 正式版(名前がそのもの)を先に、無ければ -preview などの付いたもの
        cands = sorted((n for n in available if n.startswith(prefix) and not any(x in n for x in ("tts", "image", "live", "audio"))),
                       key=lambda n: (n != prefix, len(n)))
        if cands:
            picked.append(cands[0])
    if not available:  # 一覧が取れなかったときは名前をそのまま試す
        picked = [p for p, _a, _b in CHEAP_MODELS]
    env = os.environ.get("GEMINI_MODEL")
    return ([env] if env else []) + picked[:3]


def ask_gemini(prompt, images):
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        return "(GEMINI_API_KEY が無いので実行しなかった)"
    parts = [{"text": prompt}]
    for p in images:
        mime = mimetypes.guess_type(p)[0] or "image/png"
        with open(p, "rb") as f:
            parts.append({"inline_data": {"mime_type": mime, "data": base64.b64encode(f.read()).decode()}})
        parts.append({"text": f"(上の画像のファイル名: {os.path.basename(p)})"})
    body = json.dumps({"contents": [{"role": "user", "parts": parts}],
                       "generationConfig": {"temperature": 0.4}}).encode()
    errors = []
    models = gemini_models(key)
    if not models:
        return "(使える Gemini モデルが見つからない)"
    for model in models:
        url = f"{API}/models/{model}:generateContent"
        req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "x-goog-api-key": key})
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                data = json.load(r)
            text = "".join(pt.get("text", "") for c in data.get("candidates", [])
                           for pt in c.get("content", {}).get("parts", []))
            u = data.get("usageMetadata", {})
            tin = u.get("promptTokenCount", 0)
            tout = u.get("candidatesTokenCount", 0) + u.get("thoughtsTokenCount", 0)  # 考えた分も出力として課金
            price = _price(model)
            cost = (tin * price[0] + tout * price[1]) / 1e6 if price else None
            _log_usage({"time": time.strftime("%Y-%m-%dT%H:%M:%S"), "kind": "review", "model": model,
                        "images": len(images), "input_tokens": tin, "output_tokens": tout,
                        "thoughts_tokens": u.get("thoughtsTokenCount", 0), "usd": cost})
            cost_s = f"約 ${cost:.4f}(約 {cost * 155:.1f} 円)" if cost is not None else "単価不明"
            print(f"[review] Gemini {model}: 入力 {tin} / 出力 {tout} トークン → {cost_s}")
            return f"_モデル: {model} / 入力 {tin} トークン・出力 {tout} トークン / {cost_s}_\n\n{text}"
        except urllib.error.HTTPError as e:
            _log_usage({"time": time.strftime("%Y-%m-%dT%H:%M:%S"), "kind": "review", "model": model, "error": e.code})
            errors.append(f"{model}: HTTP {e.code} {e.read()[:200]!r}")
        except Exception as e:  # noqa: BLE001
            errors.append(f"{model}: {e}")
    return "(Gemini の呼び出しに失敗)\n" + "\n".join(errors)


def ask_codex(prompt, images):
    exe = shutil.which("codex") or shutil.which("codex.cmd")
    if not exe:
        return "(codex コマンドが見つからない)"
    cmd = [exe, "exec", "--skip-git-repo-check", "-s", "read-only"]
    for p in images:
        cmd += ["-i", os.path.abspath(p)]
    # Windows の codex.cmd は複数行の引数を正しく渡せないので、質問文は標準入力から渡す("-")
    cmd.append("-")
    try:
        r = subprocess.run(cmd, input=prompt, capture_output=True, text=True, encoding="utf-8", timeout=900)
    except Exception as e:  # noqa: BLE001
        return f"(Codex の実行に失敗: {e})"
    if r.returncode != 0:
        return f"(Codex が終了コード {r.returncode})\n{r.stderr[-2000:]}"
    return r.stdout.strip()


def show_usage():
    if not os.path.isfile(USAGE_LOG):
        print("(まだ記録がありません)")
        return
    n, tin, tout, usd = 0, 0, 0, 0.0
    with open(USAGE_LOG, encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            if "error" in e or e.get("kind") != "review":  # Gemini の評価の行だけ数える
                continue
            n += 1
            tin += e.get("input_tokens", 0)
            tout += e.get("output_tokens", 0)
            usd += e.get("usd") or 0.0
    print(f"[usage] 成功 {n} 回 / 入力 {tin} トークン / 出力 {tout} トークン / 約 ${usd:.3f}(約 {usd * 155:.0f} 円)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt-file")
    ap.add_argument("--out")
    ap.add_argument("--gemini", action="store_true", help="Gemini にも評価させる(既定は Codex だけ)")
    ap.add_argument("--usage", action="store_true", help="これまでの Gemini の使用量と概算金額の合計を表示する")
    ap.add_argument("images", nargs="*")
    a = ap.parse_args()
    if a.usage:
        return show_usage()
    if not (a.prompt_file and a.out and a.images):
        ap.error("--prompt-file と --out と画像が必要です")
    with open(a.prompt_file, encoding="utf-8") as f:
        prompt = f.read()
    images = [p for p in a.images if os.path.isfile(p)]
    print(f"[review] 画像 {len(images)} 枚")
    # 2026-11-19 アルさんの方針: モデルの評価は Codex だけで行う(Gemini は今後ゲーム部分で使う)
    gem = ask_gemini(prompt, images) if a.gemini else None
    if gem is not None:
        print("[review] Gemini 完了")
    cod = ask_codex(prompt, images)
    print("[review] Codex 完了")
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(f"# 評価: {os.path.basename(a.prompt_file)}\n\n画像: {', '.join(os.path.basename(p) for p in images)}\n\n")
        if gem is not None:
            f.write("## Gemini\n\n" + gem + "\n\n")
        f.write("## Codex\n\n" + cod + "\n")
    print(f"[review] 保存: {a.out}")


if __name__ == "__main__":
    sys.exit(main())
