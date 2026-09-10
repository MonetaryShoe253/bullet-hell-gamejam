# Art Prompts

Ready-to-paste prompts for the art the game still needs. Read
[art_spec.md](art_spec.md) first -- these prompts assume the conform pipeline
exists, and they are deliberately *loose* about grid, palette and edges because
`tools/conform_art.py` enforces all three afterwards.

**The generator only has to get two things right: silhouette and content.**
Everything else is fixed downstream. Do not waste prompt tokens asking a model
for "16x16 pixel art with a 40 colour palette" -- it cannot count pixels or
colours, and the pipeline overrules it anyway. Ask for a clean, bold, readable
subject on a flat background.

---

## 0. The loop

```bash
# 1. Generate. Save the raw output anywhere under assets/, correct filename.
# 2. Add or extend a manifest group in tools/art_manifest.json (see below).
python tools/conform_art.py conform --only <group>
python tools/conform_art.py verify
# 3. Wire it into the game (each prompt below names the file to edit).
```

### Manifest entry for generated art

Generated art needs one extra field the hand-made assets did not:

```json
{
  "name": "kitchen_props",
  "glob": "assets/Dungeon/decorations/fryer.png,assets/Dungeon/decorations/hood.png",
  "canvas": [32, 48],
  "fit": "trim_pad",
  "anchor": "bottom",
  "key_background": true,
  "key_tolerance": 40,
  "despeckle_fraction": 0.10
}
```

- `key_background` floods the flat backdrop in from the border and clears it.
  Image generators return an **opaque** canvas, so without this every prop
  arrives as a solid rectangle. Keying from the border (rather than by exact
  colour) survives the soft gradient a model puts in a "flat" background and
  will not punch holes in matching colours inside the subject.
- `anchor: "bottom"` for anything that stands on the floor, so it sits on its
  tile instead of floating. `"center"` for enemies and projectiles.
- `despeckle_fraction` culls the stray fragments models love to leave. Watch
  the `despeckle dropped N island(s)` lines -- if a prop legitimately has
  separate parts, lower it. (`saucy_wing`'s sauce drips get culled at 0.03,
  which is the right call at 48px.)
- `exclude_ramps` is **required**, not optional. Keying leaves a blended rim on
  the silhouette that snaps to whichever ramp your key colour is nearest --
  magenta lands on `VIOLET` and every sprite gets a purple halo. Exclude the
  ramp nearest your key colour.

---

## 1. Style preamble

Paste this **above every prompt below**, unchanged. It is the consistency
anchor.

> Retro 16-bit pixel art game sprite, single centered object, orthographic
> three-quarter top-down view as in a SNES action RPG, camera looking down at
> roughly 60 degrees. Chunky readable forms, thick dark outline around the
> whole silhouette, hard-edged cel shading with two or three flat tones per
> surface, no gradients, no anti-aliasing. Warm greasy fast-food colour scheme:
> deep fried gold, hot-sauce red, stainless steel grey, cardboard brown.
> Single light source from directly above and slightly in front. Flat solid
> magenta background (#FF00FF), subject fully inside frame with a small margin,
> nothing touching the edges.

### Negative prompt

> photorealistic, 3d render, blurry, soft shading, gradient, glow, bloom,
> anti-aliased edges, drop shadow, cast shadow, text, watermark, signature,
> logo, UI frame, border, multiple objects, collage, sprite sheet, grid,
> character turnaround, isometric, side view, front view, busy background,
> scenery, white background, transparent checkerboard

### Style reference images

Both tools below accept reference images, and this matters more than any
adjective in the prompt. Attach:

1. `assets/palette/wingpunk40.png` -- the palette swatch.
2. Two or three existing sprites from `assets/enemies/` or
   `assets/Dungeon/decorations/` as the style target.

For Google AI Studio, say: *"Match the exact art style, outline weight and
colour palette of the attached reference images."*

---

## 2. Settings

**Local ComfyUI / A1111 (SD1.5 + a pixel-art LoRA)** — free and unlimited on
your GTX 1660.

| Setting | Value |
|---|---|
| Resolution | 512×512 (768×512 for wide props) |
| Steps | 28–32 |
| CFG | 7 |
| Sampler | DPM++ 2M Karras |
| LoRA weight | 0.7–0.9 |
| Batch | 4 per prompt, pick the best silhouette |

Downscaling to 32/48px destroys fine detail regardless, so favour **bold
shapes over detail** when picking from a batch. Squint at the thumbnail: if you
can't tell what it is, the model can't either once it's 32px.

**Google AI Studio (Gemini image generation)** — free tier, no setup, and much
better at *"match the attached style"*. Use it for the hero pieces (the boss,
the wing enemies); use ComfyUI for volume.

---

> **Status:** sections 4-6 have been generated and wired in; see
> `art_spec.md` section 6b. The **extractor hood (5.2)** is the one asset still
> outstanding. Keep these prompts for regenerating or extending the set.
>
> Two lessons from the first batch, now folded into section 0:
> always set `exclude_ramps` for the ramp nearest your key colour, and expect
> the model to sometimes return a **variant sheet** instead of one object --
> `freezer_door` came back as three doors and had to be cropped.

## 3. The gap worth filling first

`DungeonGenerator.RoomTheme` is `{ NONE, BURGER, TACO, PIZZA }` and the enemy
roster is slime / burger / taco / pizza. **There is no chicken or wing content
anywhere in a chicken-wing game.** The jam theme is currently carried only by
the Cluck Cola pickups and a crate. Filling that is worth more than any amount
of extra polish elsewhere.

Adding a `WING` theme touches three files, all trivially:

- `scenes/dungeon/dungeon_generator.gd` — add `WING` to the `RoomTheme` enum.
- `scenes/dungeon/dungeon_decorator.gd` — add a `WING` entry to
  `THEME_DECORATIONS`.
- `scenes/dungeon/enemy_catalog.gd` — add the enemy dicts with
  `"theme": DungeonGenerator.RoomTheme.WING`.

---

## 4. Enemies

**48×48, `anchor: center`.** Each enemy is a **single frame** — one PNG in a
one-frame `idle` animation (see `scenes/enemies/burger/burger.tscn`). No
animation set required.

House style, from the existing roster: anthropomorphic food with an angry
cartoon face, stubby arms and legs, a wide stable base, and a slightly bulging
"heavy" silhouette. Keep the face large — at 48px, eyes and mouth are most of
the read.

### 4.1 Wing Trooper — the basic chicken enemy

> An angry anthropomorphic fried chicken wing character. A single plump
> breaded drumstick with a white bone handle at the bottom, standing upright on
> two stubby chicken feet. Two tiny wing-stubs for arms held out at its sides.
> A furious scowling face with big white angry eyes and a jagged frown pressed
> into the crispy golden batter. Crunchy irregular breadcrumb texture over the
> whole body. Colours: deep fried gold and amber batter, cream-white bone,
> dark brown crispy edges.

### 4.2 Saucy Wing — the ranged variant

> An angry anthropomorphic chicken wing drenched in glossy buffalo hot sauce.
> A plump wing segment standing on two stubby feet, the whole body coated in
> dripping bright red sauce with wet highlights, thick sauce drips running down
> and pooling at its feet. A snarling face with narrow furious white eyes and a
> wide open mouth showing it mid-shout. Small wing-stub arms flung outward.
> Colours: hot-sauce red and dark crimson over deep fried gold, cream
> highlights on the wet sauce.

### 4.3 Bucket Brute — the wing-theme boss

Same 48×48 file; the boss reuses enemy art at integer `scale = 2` (see
`enemy_catalog.gd`). Make the silhouette **wide and heavy** so it still reads
when doubled.

> A hulking angry anthropomorphic fried chicken bucket, wide and squat like a
> boss monster. A big red-and-white striped paper bucket forming the body, its
> rim torn and jagged like a snarling mouth full of teeth. Fried chicken pieces
> and drumsticks heaped out of the top and spilling over the rim. Two thick
> muscular arms made of chicken wings, fists clenched, and two stubby feet.
> Huge furious glowing eyes set into the front of the bucket. Colours:
> hot-sauce red and cream-white bucket stripes, deep fried gold chicken, dark
> outline.

### 4.4 Celery Skirmisher — the fast flanker

> An angry anthropomorphic celery stick character, tall thin and fast-looking.
> A single ribbed green celery stalk standing upright with leafy green fronds
> sprouting from its head, standing on two thin stubby legs. A sneering
> mischievous face with narrow eyes. One arm smeared with a dollop of thick
> white ranch dip. Colours: fresh green and deep forest green stalk,
> cream-white ranch, dark outline.

---

## 5. Kitchen props

**32×32 (or 32×48 for tall items), `anchor: bottom`.** These go in
`assets/Dungeon/decorations/` and get added to `DECORATION_PATHS` in
`scenes/dungeon/dungeon_decorator.gd`.

Props are scenery, so keep them **lower contrast than the enemies** — they must
not compete with bullets. Avoid pure white and avoid saturated red on props;
the spec reserves the `SAUCE_*` ramp for enemy-owned things.

Add to the preamble for every prop in this section:

> Object viewed from a three-quarter top-down angle, resting flat on the
> ground, base of the object at the bottom of the frame.

### 5.1 Deep fryer — `assets/Dungeon/decorations/deep_fryer.png` (32×48)

> A commercial stainless steel deep fryer unit. A tall brushed-metal cabinet
> with a rectangular vat of bubbling golden oil recessed in the top, a wire
> fry basket with a long handle hooked over one side, and a small control dial
> on the front panel. Faint steam wisps rising from the oil. Colours: cool
> stainless grey steel, deep fried gold oil, dark grey shadows.

### 5.2 Extractor hood — `assets/Dungeon/decorations/extractor_hood.png` (32×48)

> A large stainless steel commercial kitchen extractor hood mounted over a
> cooking range. A wide angled sheet-metal canopy with a riveted rim and a
> grease filter grille of diagonal slats underneath, a short duct rising from
> the top. Grease staining darkening the lower edge. Colours: cool stainless
> grey, dark slate grille, warm brown grease staining.

### 5.3 Sauce vat — `assets/Dungeon/decorations/sauce_vat.png` (32×32)

> A big open metal drum of hot wing sauce on a low steel stand. A dented
> galvanised barrel filled to the brim with thick glossy dark red sauce, a
> wooden paddle standing upright in it, and sauce splattered down the outside
> of the drum. Colours: dull galvanised grey metal, dark crimson sauce, brown
> wooden paddle.

### 5.4 Walk-in freezer door — `assets/Dungeon/decorations/freezer_door.png` (32×48)

> A heavy insulated walk-in freezer door set in a steel frame. A thick
> brushed-metal slab door with a large chrome lever handle, a small square
> frosted window at head height, and a rim of white frost and icicles around
> the edges. Colours: cool stainless grey, pale icy blue-white frost, dark
> outline.

### 5.5 Prep counter — `assets/Dungeon/decorations/prep_counter.png` (32×32)

> A stainless steel kitchen prep counter. A low rectangular steel table with a
> scratched worktop, a wooden chopping board and a scatter of chopped
> vegetables on top, and a wire undershelf stacked with metal pans. Colours:
> cool stainless grey, warm brown chopping board, muted green vegetables.

### 5.6 Heat lamp station — `assets/Dungeon/decorations/heat_lamp.png` (32×48)

> A fast-food heat lamp holding station. A steel frame supporting a horizontal
> row of glowing orange heat bulbs above a shallow tray of fried chicken
> pieces, warm light pooling on the food below. Colours: cool stainless grey
> frame, warm amber glow, deep fried gold chicken.

### 5.7 Mop and bucket — `assets/Dungeon/decorations/mop_bucket.png` (32×32)

> A yellow wheeled mop bucket with a wringer, a wooden-handled mop leaning
> into it, and a small puddle of grey soapy water spreading at its base.
> Colours: muted mustard yellow plastic, dull grey water, brown wooden handle.

---

## 6. Wing-theme room props

Two props for the new `WING` entry in `THEME_DECORATIONS`. **32×32,
`anchor: bottom`.** These may be a little bolder than the generic props since
they signal the room theme.

### 6.1 Wing warmer — `assets/Dungeon/decorations/wing_warmer.png`

> A glass-fronted heated display cabinet packed with fried chicken wings. A
> small steel-framed cabinet with a warm glowing interior, two shelves crammed
> with piles of golden breaded wings behind the glass. Colours: cool stainless
> frame, warm amber interior glow, deep fried gold wings.

### 6.2 Sauce tap wall — `assets/Dungeon/decorations/sauce_taps.png`

> A row of three self-serve sauce dispenser taps on a small steel counter. Three
> chrome pump nozzles over labelled tubs, one dripping a thick bead of dark red
> sauce into a paper cup below. Colours: cool chrome grey, dark crimson sauce,
> cream-white paper cup.

---

## 7. Optional: the UI pass

The largest remaining inconsistency, deferred in `art_spec.md §7` because menu
buttons have text baked into the texture and `panel.png` is 9-sliced.

**Do not generate these as images.** A 210×55 button with baked-in text cannot
be palette-conformed without wrecking the letterforms, and a generated 9-slice
will not stretch cleanly. The right fix is a Godot `Theme` resource with
`StyleBoxFlat` panels drawn from the `wingpunk40` ramps and a real bitmap font,
so buttons scale and the text stays crisp. That is a code task, not an art one.

If you do want generated UI, generate only the **decorative frame** with no
text, at 3× the final size, and let Godot draw the labels on top.

---

## 8. Quality bar

Before you conform a generated image, check:

- [ ] **Silhouette reads at thumbnail size.** Shrink it to 48px in any viewer.
      If you can't identify it, neither will the player.
- [ ] **Single subject, nothing clipped at the frame edge** — `trim_pad` needs
      a clean margin to find the content box.
- [ ] **Background is genuinely flat** and does not appear inside the subject.
- [ ] **No baked drop shadow.** The pipeline's alpha threshold turns a soft
      shadow into an ugly hard blob.
- [ ] **Face and key details are large.** Detail below about 3px of source per
      1px of target is lost in the downscale.

Then:

```bash
python tools/conform_art.py conform --only <group>   # watch the despeckle lines
python tools/conform_art.py verify
```
