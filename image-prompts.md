# Image prompts — Phonon Characters

Copy one block per character into ChatGPT (or any image model). The app expects
one square portrait per character; it adds the aura, ring and emblem badge.

## Rules for every image

- **1:1 square**, 1024×1024 or larger. The app scales it down.
- **Front-facing, symmetrical bust**. Not 3/4, not side profile. The jaw puppet
  needs a frontal mouth.
- **Full head and shoulders visible**, generous headroom, face centered.
- **Eyes and mouth fully visible**. No closed visor, no hand over the mouth, no
  mustache covering the lips.
- **Simple neutral studio background** with a soft vignette. The app crops it
  into a soft circular medallion, so the background stays visible. A plain
  gray, teal, or warm-dark backdrop is ideal.
- **No text, no watermark, no logo, no frame, no emblem/badge.** The app draws
  its own emblem badge on the chest.
- Keep the same camera height, lens, lighting and framing across all 12.

## Global style suffix

Add this to the end of every character prompt:

> stylized 3D animated family film character, DreamWorks / Kung Fu Panda-inspired
> cartoon proportions, soft global illumination, rounded appealing shapes, big
> expressive eyes, detailed materials, front-facing symmetrical bust portrait,
> centered, full head and shoulders, generous headroom, simple neutral studio
> background with a soft vignette, 1:1, high quality, no text, no watermark, no
> logo, no frame, no emblem

## Negative prompt

> photorealistic, live action, flat vector, doodle, sketch, line art, anime, 2D,
> chibi, text, watermark, logo, frame, border, cropped head, helmet covering the
> face, mask, hand over mouth, extreme three-quarter view, side profile, multiple
> characters, busy background, duplicate emblem

## Character prompts

### silas — Captain Silas Blackwater

> Weathered male pirate captain in his 50s, dark navy tricorn hat, short gray
> beard and mustache that leave the mouth clearly visible, navy coat with muted
> gold trim, sea-worn skin, stern but warm, confident half-smile, deep navy and
> antique gold palette, [GLOBAL STYLE SUFFIX]

Palette: ink `#1B2A33`, aura `#2E5A6B`, accent `#C9A227`.

### morwenna — Morwenna of the Deep

> Elegant sea witch woman, pale teal skin, long dark wet hair, shell and kelp
> ornaments, deep teal and seafoam palette, calm unsettling gaze, lips visible,
> mysterious underwater light, [GLOBAL STYLE SUFFIX]

Palette: ink `#10333A`, aura `#1F7A6E`, accent `#9FE3C8`.

### mortlake — Old Mortlake

> Old gravedigger man in his 70s, wide-brim black hat, long gray beard and
> mustache with the mouth clearly visible, earth-brown coat, dry kind eyes,
> weathered face, warm candlelit churchyard palette, [GLOBAL STYLE SUFFIX]

Palette: ink `#2A2318`, aura `#6B5A3E`, accent `#C9B458`.

### azgorath — Azgorath

> Male demon prince, deep crimson skin, curved black horns, orange slit eyes,
> dark armor with ember accents, theatrical menace, mouth visible, proud and
> bored expression, not gory, [GLOBAL STYLE SUFFIX]

Palette: ink `#240F0F`, aura `#7A1F14`, accent `#E0662B`.

### fennick — Fennick the Young Elf

> Young male elf scout, boyish face, pointed ears, short auburn hair, green tunic
> with a leaf pin, bright curious eyes, friendly open expression, forest light,
> [GLOBAL STYLE SUFFIX]

Palette: ink `#1D2A1A`, aura `#5C8A3C`, accent `#D8C46A`.

### vyrmathrax — Vyrmathrax the Ancient

> Enormous ancient golden dragon, reptilian scales, long snout, sharp teeth,
> curved horns, amber slit eyes, smoke and embers, majestic and ancient, full
> dragon head and neck, no human, no person, [GLOBAL STYLE SUFFIX]

Palette: ink `#2A1608`, aura `#8A3A12`, accent `#E8A33D`.

### grub — Grub the Ogre

> Gentle ogre, olive-green skin, big round ears, small lower tusks, topknot,
> simple brown clothes, huge shoulders, curious kind expression, mouth visible,
> [GLOBAL STYLE SUFFIX]

Palette: ink `#241E12`, aura `#6E5A2A`, accent `#A8B45C`.

### aldric — Master Aldric

> Old male wizard scholar, pointed purple hat, long white beard and mustache with
> the mouth clearly visible, violet robe, wise dry smile, warm candlelight and
> old books, [GLOBAL STYLE SUFFIX]

Palette: ink `#211A2E`, aura `#4B3A78`, accent `#CBB26A`.

### snowqueen — The Snow Queen

> Elegant ice queen, pale skin, silver crown, long black hair, blue and silver
> gown, cold composed expression, lips visible, frost and snow, [GLOBAL STYLE SUFFIX]

Palette: ink `#14202B`, aura `#4E7C96`, accent `#CFE6F2`.

### bramwell — Sir Bramwell

> Young male knight, bare head, short brown hair, friendly brave smile, blue and
> gold plate armor, **no helmet**, heroic, [GLOBAL STYLE SUFFIX]

Palette: ink `#1B2430`, aura `#3F5E7A`, accent `#D4AF37`.

### godmother — Fairy Godmother

> Warm fairy godmother woman in her 50s, pink and plum gown, small tiara,
> theatrical smile, sparkling magic, kind eyes, [GLOBAL STYLE SUFFIX]

Palette: ink `#2C1A26`, aura `#8A5570`, accent `#F2C6D8`.

### thing — The Thing Under the Stairs

> Hooded shadow creature, dark teal-gray hood, glowing green eyes, shadowy face
> with a visible mouth, soft unsettling presence, not gory, not scary,
> [GLOBAL STYLE SUFFIX]

Palette: ink `#14101C`, aura `#3A2450`, accent `#8FBF3F`.

## Consistency pass

1. Generate **Silas** first. If the style is right, attach that image to the
   next prompts as a **style reference** and say: "Use the attached image only
   for rendering style, lighting, camera and framing. Do not copy the character."
2. If a result is too realistic, add: "more exaggerated cartoon proportions,
   bigger eyes, softer shapes, less realistic skin texture."
3. If a result is too 3/4, add: "straight-on symmetrical front view, both eyes
   equally visible, nose centered."
4. If the mouth is hidden, add: "mouth fully visible, lips slightly parted, no
   mustache or hand covering the mouth."
5. If a helmet or mask appears, add: "bare face, no helmet, no mask, no visor."

## Saving the images

Save each result as:

```      
Resources/Characters/<id>/cartoon.png
```

Then regenerate the face layout used by the jaw puppet:

```bash
swift scripts/face-landmarks.swift Resources/Characters/silas/cartoon.png \
  > Resources/Characters/silas/face.json
```

Repeat per character. If Vision cannot find a face (for example, a dragon), the
app shows a static portrait; that is fine.

Finally:

```bash
make check-art    
make run
```

The app prefers `cartoon.png`; if it is missing it falls back to the old
layered/procedural portrait.
