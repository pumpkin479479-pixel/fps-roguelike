"""Codex(codex-cli、ChatGPT ログイン)で設定画などの画像を作る。

2026-11-19 アルさんの方針: 画像生成は Codex だけで行う(Gemini の画像生成は使わない。費用がかかるため)。

使い方(アルさんの PC):
    python tools/concept/gen_image_codex.py --prompt-file docs/concept/revolver/prompt_side.md \
        -i docs/concept/revolver/rev_side.png --out docs/concept/revolver/rev_side_v2.png

- 指示文(--prompt か --prompt-file)と参考画像(-i、複数可)を `codex exec` に渡し、画像を1枚作ってもらう。
- Codex が作った画像は ~/.codex/generated_images に出るので、実行中に新しくできたファイルを --out へコピーする。
  2枚以上できたときは out_1.png, out_2.png … とする。
- 実行の記録(日時・枚数・成功/失敗)を tools/review/out/usage.jsonl に残す(Codex はプランの利用枠なので金額は無し)。
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time

GEN_DIR = os.path.join(os.path.expanduser("~"), ".codex", "generated_images")
USAGE_LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "review", "out", "usage.jsonl")


def _log(entry):
    os.makedirs(os.path.dirname(USAGE_LOG), exist_ok=True)
    with open(USAGE_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _new_images(since):
    found = []
    for root, _dirs, files in os.walk(GEN_DIR):
        for n in files:
            p = os.path.join(root, n)
            if n.lower().endswith((".png", ".jpg", ".jpeg", ".webp")) and os.path.getmtime(p) >= since:
                found.append(p)
    return sorted(found, key=os.path.getmtime)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt")
    ap.add_argument("--prompt-file")
    ap.add_argument("-i", "--image", action="append", default=[], help="参考画像(複数可)")
    ap.add_argument("--out", required=True, help="保存先(.png)")
    a = ap.parse_args()
    prompt = a.prompt or ""
    if a.prompt_file:
        with open(a.prompt_file, encoding="utf-8") as f:
            prompt = f.read()
    if not prompt.strip():
        ap.error("--prompt か --prompt-file が必要です")
    exe = shutil.which("codex") or shutil.which("codex.cmd")
    if not exe:
        print("[gen] codex コマンドが見つからない")
        return 1
    prompt = ("画像生成の機能を使って、次の指示どおりの画像を1枚作ってください。ファイルの編集やコマンドの実行はしないでください。\n\n"
              + prompt)
    cmd = [exe, "exec", "--skip-git-repo-check", "-s", "read-only"]
    for p in a.image:
        cmd += ["-i", os.path.abspath(p)]
    cmd.append("-")  # Windows の codex.cmd は複数行の引数を渡せないので、指示文は標準入力から
    start = time.time() - 1
    print(f"[gen] codex で生成中(参考画像 {len(a.image)} 枚)…")
    r = subprocess.run(cmd, input=prompt, capture_output=True, text=True, encoding="utf-8", timeout=1800)
    imgs = _new_images(start)
    entry = {"time": time.strftime("%Y-%m-%dT%H:%M:%S"), "kind": "image_codex", "out": a.out,
             "ref_images": len(a.image), "images": len(imgs), "returncode": r.returncode}
    _log(entry)
    if not imgs:
        print(f"[gen] 画像ができなかった(終了コード {r.returncode})")
        print(r.stdout[-2000:])
        print(r.stderr[-2000:])
        return 1
    os.makedirs(os.path.dirname(os.path.abspath(a.out)) or ".", exist_ok=True)
    base, ext = os.path.splitext(a.out)
    for k, src in enumerate(imgs):
        dst = a.out if len(imgs) == 1 else f"{base}_{k + 1}{os.path.splitext(src)[1] or ext}"
        shutil.copy2(src, dst)
        print(f"[gen] 保存: {dst}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
