"""画像を Codex(OpenAI)と Gemini に見せて、厳しめの評価をもらう。

使い方(アルさんの PC):
    python tools/review/review_images.py --prompt-file tools/review/prompts/gun_model.md \
        --out tools/review/out/ak47.md tools/blender/renders/ak47_*.png

- Gemini … 環境変数 GEMINI_API_KEY で REST API を直接呼ぶ(追加のライブラリ不要)。
            モデルは GEMINI_MODEL(既定は下の候補を順に試す)。
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
import urllib.error
import urllib.request

GEMINI_MODELS = [m for m in [os.environ.get("GEMINI_MODEL")] if m] + [
    "gemini-3-pro-preview", "gemini-2.5-pro", "gemini-2.5-flash",
]


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
    for model in GEMINI_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "x-goog-api-key": key})
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                data = json.load(r)
            text = "".join(pt.get("text", "") for c in data.get("candidates", [])
                           for pt in c.get("content", {}).get("parts", []))
            return f"_モデル: {model}_\n\n{text}"
        except urllib.error.HTTPError as e:
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
    cmd.append(prompt)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", timeout=900)
    except Exception as e:  # noqa: BLE001
        return f"(Codex の実行に失敗: {e})"
    if r.returncode != 0:
        return f"(Codex が終了コード {r.returncode})\n{r.stderr[-2000:]}"
    return r.stdout.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("images", nargs="+")
    a = ap.parse_args()
    with open(a.prompt_file, encoding="utf-8") as f:
        prompt = f.read()
    images = [p for p in a.images if os.path.isfile(p)]
    print(f"[review] 画像 {len(images)} 枚")
    gem = ask_gemini(prompt, images)
    print("[review] Gemini 完了")
    cod = ask_codex(prompt, images)
    print("[review] Codex 完了")
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(f"# 評価: {os.path.basename(a.prompt_file)}\n\n画像: {', '.join(os.path.basename(p) for p in images)}\n\n")
        f.write("## Gemini\n\n" + gem + "\n\n## Codex\n\n" + cod + "\n")
    print(f"[review] 保存: {a.out}")


if __name__ == "__main__":
    sys.exit(main())
