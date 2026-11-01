#!/usr/bin/env python3
"""Generate the cartoon placeholder bases and face layout files.

Uses the free Pollinations classic endpoint (one image per 45 s, 768 px, small
logo). The logo strip is cropped, the background is cut with Vision, and the
result is resized to the app's 1024 px slot. Re-runnable: existing files are
kept unless --force is passed.

    python3 scripts/make-cartoon-art.py
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.join(os.path.dirname(__file__), "..", "Resources", "Characters")
RAW = os.path.join(os.path.dirname(__file__), "..", "build", "cartoon-raw")
ENDPOINT = "https://image.pollinations.ai/prompt/"
STYLE = (
    "stylized 3D animated family film character bust portrait, cinematic soft "
    "global illumination, rounded appealing shapes, expressive eyes, detailed "
    "materials, centered, plain light gray background, high quality, no text, "
    "no watermark"
)

PROMPTS = {
    "silas": "male weathered pirate captain, tricorn hat, gray beard, navy coat with gold trim, stern but warm, sea-worn skin",
    "morwenna": "sea witch woman, pale teal skin, long dark wet hair, shell and kelp ornaments, calm unsettling gaze, deep teal palette",
    "mortlake": "old gravedigger man, wide-brim black hat, long gray beard, earth-brown coat, dry kind eyes",
    "azgorath": "male demon prince, deep red skin, curved black horns, orange slit eyes, dark armor, theatrical menace",
    "fennick": "young boy elf scout, masculine boyish face, pointed ears, short auburn hair, green tunic, leaf pin, bright curious eyes",
    "vyrmathrax": "a golden dragon, close-up of its face, fantasy creature, reptilian scales, long snout, sharp teeth, curved horns, glowing amber eyes, smoke, no humans, no person, no skull, no helmet, dark background",
    "grub": "gentle ogre man, olive skin, big round ears, small tusks, topknot, simple brown clothes, curious expression",
    "aldric": "old male wizard scholar, pointed purple hat, long white beard, violet robe, wise dry smile, tower library",
    "snowqueen": "female ice queen, pale skin, silver crown, long black hair, blue and silver gown, cold elegant expression",
    "bramwell": "young man in blue and gold medieval plate armor, bare head, short brown hair, friendly smile, no helmet, heroic, cartoon",
    "godmother": "older fairy godmother woman, pink and plum gown, small tiara, warm theatrical smile, sparkling magic",
    "thing": "hooded shadow creature under the stairs, no human face, glowing green eyes, soft unsettling presence, not gory",
}


def image_url(prompt: str, seed: int) -> str:
    query = urllib.parse.urlencode({"seed": seed, "nologo": "true"})
    return ENDPOINT + urllib.parse.quote(prompt) + "?" + query


def download(url: str, path: str) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=240) as response:
        data = response.read()
    if not data.startswith(b"\xff\xd8"):
        raise RuntimeError(f"not a JPEG ({len(data)} bytes)")
    with open(path, "wb") as file:
        file.write(data)


def run(script: str, *args: str) -> str:
    result = subprocess.run(
        ["swift", script, *args],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"{script} failed")
    return result.stdout.strip()


def process(character: str, raw: str) -> None:
    folder = os.path.join(ROOT, character)
    os.makedirs(folder, exist_ok=True)

    source = Image.open(raw).convert("RGB")
    # The classic endpoint stamps a small logo in the bottom-right corner.
    source = source.crop((0, 0, source.width, source.height - 38))
    source = ImageOps.expand(source, border=(0, 0, 0, 38), fill=(200, 200, 200))
    padded = os.path.join(RAW, f"{character}-padded.png")
    source.save(padded)

    layout = run(os.path.join(os.path.dirname(__file__), "face-landmarks.swift"), padded)
    if layout and layout != "{}":
        with open(os.path.join(folder, "face.json"), "w") as file:
            json.dump(json.loads(layout), file, indent=2)

    image = Image.open(padded).convert("RGBA").resize((1024, 1024), Image.LANCZOS)
    medallion = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(medallion).ellipse([18, 0, 1006, 1000], fill=255)
    medallion = medallion.filter(ImageFilter.GaussianBlur(26))
    image.putalpha(medallion)

    shadow = medallion.filter(ImageFilter.GaussianBlur(26)).point(lambda v: v * 50 // 255)
    shadow = ImageChops.offset(shadow, 3, 8)
    shadow_layer = Image.new("RGBA", image.size, (0, 0, 0))
    shadow_layer.putalpha(shadow)
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out.alpha_composite(shadow_layer)
    out.alpha_composite(image)
    cartoon = os.path.join(folder, "cartoon.png")
    out.save(cartoon, optimize=True)
    print(f"{character}: cartoon.png")

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--only", default="", help="comma-separated character ids")
    args = parser.parse_args()
    only = {item.strip() for item in args.only.split(",") if item.strip()}
    os.makedirs(RAW, exist_ok=True)

    for index, (character, description) in enumerate(PROMPTS.items()):
        if only and character not in only:
            continue
        folder = os.path.join(ROOT, character)
        target = os.path.join(folder, "cartoon.png")
        if os.path.exists(target) and not args.force:
            print(f"{character}: exists")
            continue

        raw = os.path.join(RAW, f"{character}.jpg")
        if args.force or not os.path.exists(raw):
            url = image_url(f"{description}, {STYLE}", 1000 + index)
            print(f"{character}: fetching")
            downloaded = False
            for attempt in range(3):
                try:
                    download(url, raw)
                    downloaded = True
                    break
                except urllib.error.HTTPError as error:
                    retry = float(error.headers.get("Retry-After", "60"))
                    wait = max(retry + 15, 70)
                    print(
                        f"{character}: HTTP {error.code}, retry {attempt + 1}/3 in {wait:.0f}s",
                        file=sys.stderr,
                    )
                    time.sleep(wait)
                except Exception as error:
                    print(f"{character}: failed ({error})", file=sys.stderr)
                    break
            if not downloaded:
                continue
            time.sleep(70)

        try:
            process(character, raw)
        except Exception as error:
            print(f"{character}: process failed ({error})", file=sys.stderr)


if __name__ == "__main__":
    main()
