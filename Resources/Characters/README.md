# Portrait assets

One `portrait.png` per persona. **1504×1046** (the source frame), transparent
background, no frame, no text. The app renders it full-bleed at the original aspect
ratio, so the character's composition is preserved — do not crop it to a square.

The app falls back to the procedural `InkFace` renderer when a portrait is missing.
The portraits are static; the voice drives breathing and sway, not the lips.

The untouched originals (green-screen backgrounds included) are in
`../../art-sources/`. Generation prompts live in
[`../../image-prompts.md`](../../image-prompts.md).
