# Pixel art procedural em HTML5 canvas para o "Café Girassol"

> Research-access note (read first): in this session direct page fetches were blocked (lospec.com, developer.mozilla.org and GitHub repos other than the project's were outside the allowed network), so every "Cited Finding" below comes from web-search result extracts of the linked pages, not from a full read of the page. Anything I could not confirm that way is placed under "Inferences" or "Gaps" and explicitly labelled `UNVERIFIED (recall)`. The palette hex lists in particular must be checked against Lospec before shipping.

## 1. Internal resolution and scaling (crisp pixels on desktop, phone, high-DPI, mobile Safari)

### Takeaway
Render the whole game into a small fixed-height buffer (320x180 is the safest 16:9 base; 384x216 and 480x270 are fine for 1080p/4K but not 1440p) and upscale by an integer factor with smoothing off, letterboxing the remainder. Compute the integer factor in device pixels (CSS px x `devicePixelRatio`), and do not rely on CSS `image-rendering: pixelated` alone on Safari, where blurry-canvas reports exist.

### Cited Findings
- MDN's technique for crisp pixel art is to set CSS `image-rendering: pixelated` on the `<canvas>` so the browser upscales with a hard-edge algorithm instead of smoothing. — [MDN: Crisp pixel art look](https://developer.mozilla.org/en-US/docs/Games/Techniques/Crisp_pixel_art_look)
- MDN's worked example of the fractional-scale problem: drawing a 128x128 image into a 100x100 area makes each image pixel 0.78x0.78 canvas pixels, which causes blur; image pixels should always be drawn at integer multiples of canvas pixels. — [MDN: Crisp pixel art look](https://developer.mozilla.org/en-US/docs/Games/Techniques/Crisp_pixel_art_look)
- MDN also states it is impossible to fill device pixels precisely when CSS pixels cannot map accurately onto them (the non-integer `devicePixelRatio` case). — [MDN: Crisp pixel art look](https://developer.mozilla.org/en-US/docs/Games/Techniques/Crisp_pixel_art_look)
- A third-party tutorial pairs the CSS with `ctx.imageSmoothingEnabled = false` on the 2D context and suggests `image-rendering: crisp-edges` as a Firefox fallback. — [Cinevva: pixel art rendering](https://app.cinevva.com/tutorials/pixel-art-rendering)
- A mirror of the MDN `image-rendering` reference carries a note that, as of January 2020, no browser actually used a pixel-art scaling algorithm for `crisp-edges`; `pixelated` is the value to prefer. — [w3cub mirror of MDN image-rendering](https://docs.w3cub.com/css/image-rendering)
- The standard high-DPI canvas recipe (multiply the backing store by `devicePixelRatio`, then `ctx.scale(dpr, dpr)`) is designed for sharp vector/text drawing. — [web.dev: High DPI Canvas](https://web.dev/articles/canvas-hidipi)
- A base resolution fits 16:9 screens cleanly only if its height divides the display height: 320x180 gives 4x/6x/8x/12x for 720p/1080p/1440p/4K; 640x360 gives 2x/3x/4x/6x; 384x216 and 480x270 fill 1080p (5x, 4x) and 4K (10x, 8x) but leave bars on 1440p. — [Bugnet: choosing a pixel art resolution](https://bugnet.io/blog/choosing-a-pixel-art-resolution-for-your-game); [Ziva pixel-perfect resolution calculator](https://ziva.sh/tools/pixel-perfect-resolution-calculator)
- Integer scaling means choosing the largest whole-number factor that fits and filling the rest with black bars; non-integer factors (e.g. 1.5x from 720p to 1080p) make some art pixels wider than others. — [Tanalin: Integer scaling](https://tanalin.com/en/articles/integer-scaling/); [Godot forum thread](https://forum.godotengine.org/t/trouble-with-pixel-perfect-scaling-from-640-x-360-to-1920-x-1080/13733)
- Safari pitfalls reported by developers: (a) Stack Overflow questions where a scaled canvas stays blurry on Safari macOS/iOS even with `image-rendering: pixelated`; (b) a WebKit bug describing a Safari 16 regression where a canvas intermittently comes up blurry and stays blurry on iOS devices; (c) an older (2016) thread saying Safari did not honour `pixelated` on a WebGL canvas. — [SO mirror: scaled canvas pixelated bug on Safari](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/75590028/scaled-canvas-pixelated-bug-on-safari); [SO mirror: canvas pixellation issue on Safari](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/73765771/html5-canvas-pixellation-issue-on-safari-blurry); [WebKit bug 256260](https://bugs.webkit.org/show_bug.cgi?id=256260); [html5gamedevs thread](https://www.html5gamedevs.com/topic/24089-crisp-rendering-on-safari-100-macos/)
- An older but still-referenced write-up on the general difficulty of crisp pixel scaling in browsers is Dominic Szablewski's "Drawing pixels is hard". — [phoboslab](https://phoboslab.org/log/2012/09/drawing-pixels-is-hard)

### Inferences
- Recommended pipeline (my synthesis; avoids depending on CSS scaling quality in Safari): draw every frame 1:1 into an offscreen 320x180 buffer canvas, then blit it once to the visible canvas whose backing store is `W*s x H*s` device pixels, with `imageSmoothingEnabled = false`:
  ```js
  const W = 320, H = 180;
  const buf = document.createElement('canvas'); buf.width = W; buf.height = H;
  const g = buf.getContext('2d');                    // all game drawing goes here
  const cv = document.getElementById('game');
  const ctx = cv.getContext('2d', { alpha: false });
  function resize() {
    const dpr = window.devicePixelRatio || 1;
    const pw = Math.floor(innerWidth * dpr), ph = Math.floor(innerHeight * dpr);
    const s = Math.max(1, Math.floor(Math.min(pw / W, ph / H))); // integer, in DEVICE px
    cv.width = W * s; cv.height = H * s;             // backing store
    cv.style.width = (W * s / dpr) + 'px';           // CSS size = device px / dpr
    cv.style.height = (H * s / dpr) + 'px';
    ctx.imageSmoothingEnabled = false;               // must be re-set after every resize
  }
  addEventListener('resize', resize); resize();
  // per frame: ctx.drawImage(buf, 0, 0, cv.width, cv.height);
  ```
  Keep `image-rendering: pixelated; image-rendering: crisp-edges;` on the canvas as a belt-and-braces fallback. Setting `canvas.width/height` resets context state, so `imageSmoothingEnabled` has to be re-applied in `resize()` (general canvas behaviour, UNVERIFIED in this session).
- Because the factor is computed in device pixels, non-integer DPRs (common on Android and on Windows at 125%/150% zoom) still get whole device pixels per art pixel; the CSS size simply becomes fractional. Also snap the canvas's left/top offset to a multiple of `1/dpr` CSS px, otherwise centring can land it on a half device pixel and reintroduce blur (inference from the MDN device-pixel statement).
- Arithmetic for phones: a phone in landscape is roughly 640-930 CSS px wide by 360-430 CSS px tall; at DPR 2-3 a 320x180 buffer gets 4x-7x in device pixels, i.e. about 2 CSS px per art pixel. In portrait the width limit gives only about 1.1-1.3 CSS px per art pixel, which is too small for a 16:9 scene. Options: require/encourage landscape, or give portrait its own layout (e.g. a 180-wide by 320-tall buffer: facade/scene on top, UI below).
- To avoid large letterbox bars on odd aspect ratios (phones are about 19.5:9), keep the height fixed at 180 and let the internal width vary, e.g. `W = clamp(floor(pw / s), 320, 400)`; a side-view café tolerates showing a little more wall or street on each side better than black bars.
- For this game 320x180 is the best default: characters 24-32 px tall remain readable, and it is the only listed base that scales cleanly to 720p, 1080p, 1440p and 4K. 480x270 would need about twice the art detail and gives under 1.5 CSS px per art pixel on small phones.

### Gaps
- I could not read the current MDN pages directly, so the exact wording of MDN's `devicePixelRatio` advice and the current browser-compat table for `image-rendering` (Safari version support for `pixelated`) are unconfirmed.
- No authoritative statement was found on the present status of the Safari blurry-canvas reports (WebKit bug 256260 and the Stack Overflow cases); test on a real iPhone.
- No source was retrieved on iOS canvas memory limits or on `visualViewport`/safe-area handling (`viewport-fit=cover`, `env(safe-area-inset-*)`); both matter for a full-screen phone layout and need separate confirmation.

## 2. Limited palettes for a warm café (sunflower yellow, coffee brown, terracotta, teal)

### Takeaway
Apollo (46 colours, six hue ramps plus a grey ramp) is the best structural fit because it has dedicated brown, gold and red-orange ramps; Endesga 32 is a punchier alternative; Sweetie 16 is friendly but has no true browns. Only fragments of the hex lists could be verified in-session, so the full lists below are recall and must be checked against Lospec.

### Cited Findings
- Sweetie 16 is a 16-colour palette and is the default palette of every new TIC-80 cartridge; the TIC-80 wiki table gives index 0 `1A1C2C` (black), 1 `5D275D` (purple), 2 `B13E53` (red), 3 `EF7D57` (orange), 14 `566C86` (grey), 15 `333C57`. — [TIC-80 wiki: Palette](https://github-wiki-see.page/m/nesbox/TIC-80/wiki/Palette)
- A palette guide lists Sweetie 16 with `#566c86` and `#333c57` among its colours and recommends it for casual, friendly-looking games. — [Sprite AI: pixel art colour palettes](https://www.sprite-ai.art/guides/pixel-art-color-palettes)
- Endesga 32 is a 32-colour palette by ENDESGA, originally created for the game NYKRA, tagged `#edg32` on Lospec; Lospec also lists a later successor palette described as having higher contrast, range and saturation. — [Lospec: Endesga tag page](https://lospec.com/palette-list/tag/endesga)
- Raymond Schlitter (Slynyrd) builds large palettes from several hue-shifted ramps and pulls small subsets per piece; because of the hue shift, each colour sits next to colours it can work with. — [Slynyrd Pixelblog 1: Color Palettes](https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes)

### Inferences
- `UNVERIFIED (recall)` full hex lists. I am confident in these from prior knowledge, but only the six Sweetie 16 entries above were confirmed in-session. Verify at the Lospec pages (`https://lospec.com/palette-list/sweetie-16`, `/endesga-32`, `/apollo`) before use.
  - Sweetie 16 (GrafxKid): `1a1c2c 5d275d b13e53 ef7d57 ffcd75 a7f070 38b764 257179 29366f 3b5dc9 41a6f6 73eff7 f4f4f4 94b0c2 566c86 333c57`
  - Endesga 32 (ENDESGA): `be4a2f d77643 ead4aa e4a672 b86f50 733e39 3e2731 a22633 e43b44 f77622 feae34 fee761 63c74d 3e8948 265c42 193c3e 124e89 0099db 2ce8f5 ffffff c0cbdc 8b9bb4 5a6988 3a4466 262b44 181425 ff0044 68386c b55088 f6757a e8b796 c28569`
  - Apollo (AdamCYounis), 46 colours in ramps, dark to light:
    - blue/teal: `172038 253a5e 3c5e8b 4f8fba 73bed3 a4dddb`
    - green: `19332d 25562e 468232 75a743 a8ca58 d0da91`
    - brown/skin: `4d2b32 7a4841 ad7757 c09473 d7b594 e7d5b3`
    - orange/gold: `341c27 602c2c 884b2b be772b de9e41 e8c170`
    - red/terracotta: `241527 411d31 752438 a53030 cf573c da863e`
    - purple/pink: `1e1d39 402751 7a367b a23e8c c65197 df84a5`
    - neutral (teal-tinted greys): `090a14 10141f 151d28 202e37 394a50 577277 819796 a8b5b2 c7cfcc ebede9`
- Mapping to the café brief (my proposal, using the recalled values):
  - With Apollo: sunflower = `be772b de9e41 e8c170` (+ `e7d5b3` as petal highlight); coffee and wood = `341c27 4d2b32 602c2c 7a4841 ad7757 c09473`; terracotta tiles and pots = `752438 a53030 cf573c da863e`; teal accents (apron, door, azulejo trim) = `253a5e 3c5e8b 4f8fba 73bed3` or the cooler greys `394a50 577277 819796`; plants = `25562e 468232 75a743`; outlines = `241527` or `341c27` instead of pure black; cream walls = `d7b594 e7d5b3 ebede9`. Apollo has no saturated teal-green; if the brand teal must be greener, add one custom colour between the green and blue ramps and keep it to a single 3-step ramp.
  - With Endesga 32: sunflower = `f77622 feae34 fee761`; coffee and wood = `3e2731 733e39 b86f50 c28569 e4a672 ead4aa`; terracotta = `a22633 be4a2f d77643`; teal = `193c3e 265c42 3e8948` (green-teal) or `124e89 0099db 2ce8f5` (cyan); outline = `181425` or `262b44`. This reads brighter and more arcade-like than Apollo.
  - With Sweetie 16: yellow `ffcd75`, orange `ef7d57`, red `b13e53`, teal `257179`, green `38b764`, darks `1a1c2c 333c57`. It lacks a brown ramp, so wood and coffee would have to be faked with `5d275d`/`b13e53`/`ef7d57`; it suits only a deliberately minimal look.
- Whatever base palette is chosen, restrict each sprite to a small subset (roughly 4-6 colours per material ramp, in line with the per-sprite limits other pixel teams cite in section 4) and store the palette as a single JS array so time-of-day and palette-swap effects operate on indices.

### Gaps
- No page listing the Endesga 32 or Apollo hex values could be retrieved (Lospec was unreachable and search engines did not index the hex strings), so those lists are unverified recall.
- No information was retrieved on Resurrect 64, AAP-64, Pear36 or Zughy 32 (authors, hex values, suitability). From recall only: Resurrect 64 is by Kerrie Lake, AAP-64 by Adigun A. Polack, Pear36 by PineTreePizza, Zughy 32 by Zughy; all are popular on Lospec and have warm ramps, but I cannot supply verified hex values.
- No source ranks these palettes specifically for "cozy" scenes; the suitability judgements above are mine.

## 3. Core pixel-art craft rules for readability

### Takeaway
The rules with the highest payoff at this scale are: hue-shifted ramps (not straight brightness ramps), one consistent light direction with no pillow shading or banding, no orphan pixels, anti-aliasing kept inside the silhouette, and chibi 2-3-head characters whose identity lives in hair and silhouette rather than facial detail.

### Cited Findings
- Slynyrd works in HSB (hue = base colour, saturation = intensity/purity, brightness = amount of black/white) and defines a colour ramp as a range of colours arranged by brightness that work together; hue shifting across the ramp is the central idea. — [Slynyrd Pixelblog 1: Color Palettes](https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes)
- In the GameDev.net republication of that article, saturation peaks in the middle swatch of the example ramp, and "straight ramps" that change only brightness and saturation are called out as a common beginner mistake. — [GameDev.net: Color Palettes](https://www.gamedev.net/articles/visual-arts/color-palettes-r4964/)
- General guidance repeated across tutorials: shadows shift toward blue/cool hues and highlights toward yellow/warm hues; saturation is kept lower at the bright end of a ramp. — [Pixnote: Pixel Art Color Guide](https://pixnote.net/en/learn/color-palette); [OpenGameArt: Chapter 5 Color Palettes](https://opengameart.org/content/chapter-5-color-palettes)
- Pillow shading is shading placed uniformly along the outline with no discernible light source; the quick test is to ask where the light is coming from. One guide calls hue shifting the most important technique for attractive shadows. — [Pixnote: Shading & Lighting](https://pixnote.net/en/learn/shading)
- Pillow shading tends to bring gradient shading and banding with it. — [Medium, Pixel Grimoire: How to start making pixel art #4](https://medium.com/pixel-grimoire/how-to-start-making-pixel-art-4-f57f51dcfa02)
- Slynyrd's light-and-shadow post opens from the premise that pixel art looks flat unless light is handled with care. — [Slynyrd Pixelblog 6: Light and Shadow](https://www.slynyrd.com/blog/2018/6/15/pixelblog-6-light-and-shadow)
- Banding is rows of colour bands that hug each other in parallel and flatten or blur the form; careless anti-aliasing produces it, and even separated clusters read as joined when they are the same length and parallel ("tangents"). — [Pixel Parmesan: Anti-Aliasing Fundamentals for Pixel Artists](https://pixelparmesan.com/anti-aliasing-fundamentals-for-pixel-artists)
- Do not anti-alias outside the outline unless the output supports translucent pixels, because the AA colour will clash with whatever background ends up behind the sprite. — [Pixel Parmesan: Anti-Aliasing Fundamentals](https://pixelparmesan.com/anti-aliasing-fundamentals-for-pixel-artists)
- Selective outlining (sel-out) on the PixelJoint forum is described as pushing the internal anti-aliasing into the outline ("internal thinning") while never adding external AA; the same discussion notes that documentation of sel-out is sparse and contradictory. — [PixelJoint forum thread 19164](https://pixeljoint.com/forum/forum_posts.asp?TID=19164)
- Single stray pixels that do not belong to a cluster read as noise ("orphan pixels"); stair-stepped "jaggies" are an accepted part of the medium and are only fixed where the line fails to read. One rule-of-thumb list: anti-alias curves, large circles and diagonals longer than about 4 px; leave horizontal/vertical lines, very small (8x8) sprites and interior detail sharp. This last list comes from a low-authority aggregated skill page, so treat the numbers as a starting point. — [Pixel Parmesan: Anti-Aliasing Fundamentals](https://pixelparmesan.com/anti-aliasing-fundamentals-for-pixel-artists); [skillselion pixel-art skill page](https://skillselion.com/skills/omer-metin/skills-for-antigravity/pixel-art)
- Derek Yu's pixel-art tutorial (originally a 10-step guide from about 2005, later rebooted with an orc as subject) covers lines, shading and dithering and has a companion tutorial on common mistakes. — [GBGames: Derek Yu's updated pixel art tutorial](https://gbgames.com/2019/12/19/derek-yus-updated-pixel-art-tutorial)
- Character proportions: 16x16 sprites are effectively pictograms where only the silhouette is recognisable; at 32x32 a 2-3-head chibi works, with a head of up to about 16 px giving room for two eyes with a shine, a mouth and a distinct hairstyle; realistic 6-7-head anime proportions need 64 px or more. Distinguishing detail should go into the hair, which reads at 32 px when facial features do not. — [Pixnote: How to Draw Pixel Art Characters](https://pixnote.net/en/learn/character); [Sprite AI: anime pixel art](https://www.sprite-ai.art/blog/anime-pixel-art)
- Slynyrd has a dedicated post on human anatomy at sprite scale. — [Slynyrd Pixelblog 17: Human Anatomy](https://www.slynyrd.com/blog/2019/5/21/pixelblog-17-human-anatomy)

### Inferences
- Practical ramp recipe for code-defined palettes (my synthesis of the cited rules): 4-5 steps per material; from the base colour go darker by lowering brightness about 12-18 points per step while rotating hue 8-15 degrees toward blue/purple and raising saturation slightly; go lighter by rotating hue toward yellow and lowering saturation. Brown wood should therefore shade toward plum (`341c27`-like) and highlight toward gold, never toward grey.
- Fix one light for the whole game: top-left key light from the windows for the interior, sun from the top for the facade. Every sprite then has its lit edge on the same side, which also makes procedural rim highlights a one-line rule (lighten the top/left edge pixel of each cluster).
- Outline policy for 320x180: dark, hue-tinted outlines (not `#000`) around characters and interactive items so they separate from the background; no outlines, or only darker same-hue edges, on background furniture. This doubles as affordance: outlined means tappable.
- Dithering: at 2-6 device pixels per art pixel, checkerboard dither reads as texture rather than gradient. Use it deliberately for materials (window light shafts fading out, sky gradient on the facade, steam) and avoid it on small sprites and faces.
- Character size for this game: 16-18 px wide by 28-32 px tall customers (head about 10-12 px, i.e. roughly 2.5 heads), seated customers cropped by the counter or table. Give each customer one strong silhouette feature (hair shape, hat, bag) and one saturated colour block so they stay distinguishable at phone size.
- Silhouette test that is cheap to automate in code: draw the sprite with every non-transparent pixel in one flat colour and check that the pose and character are still identifiable.

### Gaps
- Pedro Medeiros (saint11) and AdamCYounis material could not be retrieved, so nothing is cited from them; their tutorials on outlines, sub-pixel animation and character design should be consulted directly.
- Derek Yu's own pages were not retrieved; only a secondary description of their contents is cited.
- No source gave numeric hue-shift amounts; the degree values above are my working numbers, not cited figures.
- No reliable source was found for exact cluster-size rules or for when dithering is appropriate at a given resolution.

## 4. How cozy pixel games handle lighting, time of day, weather and idle motion

### Takeaway
Documented practice in the reference games is thin on implementation detail: the confirmed pattern is hand-authored, limited-palette pixel art with lighting added as a separate layer (global tint or fade for time of day, additive glows and rim light for lamps), and character life coming from small looping animations. Specific particle and light-shaft recipes below are my own proposals, not sourced.

### Cited Findings
- Coffee Talk: lead artist/art director Dio Mahesa aimed for a 90s-anime look in pixel art, citing PC-98 visual novels as the reference, combined with a colour palette and modern technical-art features that PC-98 games lacked. Workflow: sketch, team feedback, pixel render (a day or two per character), then animation in Spine (about another day). — [Coffee Talk Devlog #2: Bringing Doodles to Life](https://togeproductions.itch.io/coffee-talk-demo/devlog/66764/coffee-talk-devlog-2-bringing-doodles-to-life); [Wikipedia: Coffee Talk](https://en.wikipedia.org/wiki/Coffee_Talk_(video_game))
- Coffee Talk is described as using a deliberately limited colour palette and resolution, and its press kit pitches a "chill" palette with 90s-anime-inspired pixel art. — [MoeGamer review](https://moegamer.net/2020/01/28/coffee-talk-its-a-brewtiful-day/); [Coffee Talk press kit](https://togepresskit.notion.site/Coffee-Talk-Press-Kit-9eb99876a5b44f70804e6ec862105dfb)
- A Space for the Unbound: Toge Productions' Kris Antoni said it was inspired by Makoto Shinkai's films with an Indonesian spin; director Dimas Novan Delfiano's team photographed real places as reference but took creative liberties; reviewers note the emphasis is on shading and colour choice rather than fine detail. — [Push Square](https://www.pushsquare.com/news/2020/08/beautiful_indie_game_a_space_for_the_unbound_is_one_to_keep_your_eye_on); [Virtual SEA](https://virtualseasia.com/a-space-for-the-unbound-is-a-pixel-art-adventure-that-brings-90s-indonesia-to-life/); [SUPERJUMP review](https://superjumpmagazine.com/a-space-for-the-unbound)
- Unpacking: artist Wren Brier grey-boxed every room in Aseprite before final art and marked grids showing where items may sit on floors, shelves and in cupboards; nearly everything was drawn as pixel art and placed directly in the game; the team says 2D pixel art let them "map things perfectly". — [Game Developer: Intimacy from the inanimate](https://gamedeveloper.com/design/intimacy-from-the-inanimate-in-house-moving-puzzler-unpacking); [Kotaku](https://kotaku.com/some-pixel-art-from-the-team-behind-unpacking-1848072044); [Nintendo Life](https://www.nintendolife.com/features/how-lemmings-chuchu-rocket-and-nintendo-inspired-unpacking-devs-next-game)
- Eastward: known for combining 2D pixel art with 3D lighting effects, built on a homebrew Pixpil engine plus the open-source MOAI framework. Whether it uses normal maps is disputed among commenters, with no developer statement found. — [Red Bull interview](https://www.redbull.com/my-en/eastward-interview); [itch.io discussion](https://itch.io/post/9039152)
- A pixel-art devlog lists the four additions that fixed a flat look caused by 4-6 colours per sprite and simple shapes: diffuse lights, a rim-light pass on the outermost sprite pixels, subtle shadows and drop shadows under characters, and normal maps on a few objects. — [xDasher devlog: 4 things we did to add light and depth](https://pixel-beef.itch.io/xdasher/devlog/192949/4-things-we-did-to-add-light-and-depth-to-our-pixel-art-game)
- Graveyard Keeper's team gave every sprite its own normal map for its lighting effects. — [Game Developer: Graveyard Keeper graphics effects](https://www.gamedeveloper.com/programming/graveyard-keeper-how-the-graphics-effects-are-made)
- Stardew Valley: mod descriptions characterise the vanilla day-to-night transition as a simple lighting fade with sunset fixed at 6:00 PM on the game's 10-minute clock; lighting mods add colour overlays for rain and light rays that fade with time. A forum commenter guesses that night is a filter applied over all tiles; this is speculation, not confirmed. — [Dynamic Dusk mod](https://www.curseforge.com/stardewvalley/mods/dynamic-dusk); [Dynamic Night Time](https://forums.stardewvalley.net/resources/dynamic-night-time.41); [Immersive Lighting mod](https://www.curseforge.com/stardewvalley/mods/immersive-lighting/install); [itch.io comment](https://itch.io/post/13924352)
- RPG Maker's own tutorial documents screen tints plus picture overlays as the standard cheap way to do time-of-day and light effects in 2D pixel games. — [RPG Maker Web: Basics of Tints & Picture Overlays](https://rpgmakerweb.com/blog/the-basics-of-tints-picture-overlays)

### Inferences
- Canvas 2D implementation of time of day (my proposal; uses standard `globalCompositeOperation` modes, UNVERIFIED in this session): after drawing the scene into the 320x180 buffer, (1) `g.globalCompositeOperation = 'multiply'` and fill the whole buffer with a tint colour; (2) switch to `'lighter'` or `'screen'` and draw pre-rendered glow sprites for lamps, the espresso machine and windows; (3) restore `'source-over'` for UI so text is never tinted. Starting tints to tune: morning `#ffe8c8`, midday `#ffffff` (no tint), golden hour `#ffc890`, dusk `#c890a8`, night `#6070b0`. Interpolate between two neighbouring tints over the in-game hour rather than switching abruptly.
- A more "pixel-pure" alternative is to precompute 4-5 complete palette variants (one per time of day) and re-render the cached sprite canvases when the period changes; this keeps the on-screen colour count strictly limited and avoids blend-mode artefacts, at the cost of a re-cache (cheap at this resolution).
- Window light shafts: pre-render a parallelogram per window into an offscreen canvas using 2-3 alpha steps with a checkerboard-dithered trailing edge, draw it with `'lighter'` at low alpha, and modulate alpha slowly (period 6-10 s). Add 6-10 single-pixel dust motes drifting inside the shaft only.
- Steam: per cup, 3-5 particles of 1-2 px, rising about 4-6 px/s, x offset `sin(t*2 + phase) * 1.5`, lifetime 1.5-2.5 s, colour stepping through 3 palette entries from light to transparent instead of smooth alpha. Rain on the facade: 40-80 streaks of 1x3 px at a fixed slant, two speeds for parallax, plus 2-frame splash sprites on the pavement and a cooler `multiply` tint.
- Idle animation: 2-frame "breathing" (torso and head shift 1 px) at 2-3 fps, blink for about 120 ms every 3-6 s at randomised intervals, occasional sip gesture; offset each customer's animation phase so they never move in sync. Environment loops (pendulum clock, ceiling fan, plant sway, steam, flickering neon on the facade) do more for coziness than complex character animation.
- Normal-mapped lighting as in Graveyard Keeper or the Eastward recreations is out of scope for Canvas 2D without per-pixel shaders; the tint + additive-glow + hand-placed rim-light approach gets most of the look.

### Gaps
- No developer-authored source was found describing the implementation of time-of-day tinting, light shafts, steam or rain particles in Coffee Talk, Stardew Valley, Eastward, Unpacking, A Space for the Unbound or Moonlighter. An 80.lv article on Moonlighter's pixel art exists (https://80.lv/articles/moonlighter-building-pixel-art-preparing-for-switch/) but its content was not retrieved.
- Native resolutions of these games were not confirmed by any source in this session.
- The tint colours and particle parameters above are my own starting values, not taken from any game.
- An article titled "Pixel-Art Light: Day, Night, Weather and Shadows" (blakecrosley.com) appeared in results but could not be read; it may contain directly relevant recipes.

## 5. Defining sprites in code (char maps, caching, palette swaps, layers, fonts, UI panels)

### Takeaway
Store each sprite as rows of single characters indexing into a palette, rasterise each sprite/palette combination once into a small offscreen canvas, and draw those canvases with `drawImage`; separating pixel indices from colours makes recolouring and customisation nearly free.

### Cited Findings
- A js13k postmortem describes converting each image into a palette list plus an array of palette indices; because colour is detached from pixel data, reusing the same sprite in different colours becomes trivial. — [dev.to: Meow Mountain, postmortem of a 13kb game](https://dev.to/lopis/meow-mountain-postmortem-of-a-13kb-game-5fb6)
- A canvas tutorial on string-encoded sprites: decode the string to an array, map each character to a palette colour, derive x/y from the index and the sprite width, and paint each pixel with `fillRect`. — [Level Up Coding: Run-Length Encoded Sprites](https://levelup.gitconnected.com/having-fun-with-run-length-encoded-sprites-662d6a8147c8)
- A js13k graphics tutorial uses a short string as the colour lookup table with colour 0 reserved as transparent, so the table needs one entry fewer than the palette size. — [js13k graphics tutorial (group post)](https://groups.google.com/g/tisinordka/c/lPQul0C0eIo)
- Existing small libraries use the same model: Sprig defines palettes as pairs of a single-character key and an RGBA value; PixelRendr stores sprites under string keys with a lookup API; the `pixels` library takes a palette array and a 2D index array. — [Sprig README](https://cdn.jsdelivr.net/npm/sprig@1.1.3/README.md); [PixelRendr](https://www.npmjs.com/package/pixelrendr); [brookesb91/pixels](https://github.com/brookesb91/pixels)
- MDN recommends moving repeated drawing operations to an offscreen canvas and then rendering that canvas to the main one as often as needed. — [MDN: Optimizing canvas](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Optimizing_canvas)
- When pre-rendering, the temporary canvas should fit snugly around the drawn image, since copying an oversized canvas wastes time. — [web.dev: Improving HTML5 Canvas performance](https://web.dev/articles/canvas-performance/)

### Inferences
- Concrete format and baker (my synthesis of the cited pattern):
  ```js
  const PAL = ['', '#341c27', '#7a4841', '#ad7757', '#e8c170', '#cf573c', '#4f8fba']; // index 0 = transparent
  const CUP = ['..1111..',
               '.144441.',
               '.133331.',
               '..1331..'];          // '.' = transparent, digits/letters = palette index (base 36)
  function bake(rows, pal, remap) {  // remap: optional {from: to} index swap
    const c = document.createElement('canvas');
    c.width = rows[0].length; c.height = rows.length;
    const x = c.getContext('2d');
    rows.forEach((r, j) => [...r].forEach((ch, i) => {
      if (ch === '.') return;
      let k = parseInt(ch, 36); if (remap && remap[k] != null) k = remap[k];
      x.fillStyle = pal[k]; x.fillRect(i, j, 1, 1);
    }));
    return c;
  }
  ```
  Bake at load time (or lazily) and keep results in a `Map` keyed by `spriteName + '|' + paletteKey`. Per frame, only `drawImage(cached, x | 0, y | 0)` is executed.
- Palette swaps for customer variety: reserve fixed index ranges per material (e.g. indices 10-12 = skin ramp, 13-15 = hair ramp, 16-18 = clothing ramp) and bake with a different `remap` per customer. With about 6 skin, 8 hair and 10 clothing ramps, one body sprite yields hundreds of distinct customers.
- Layered sprites: bake separate canvases for body, clothes, hair (back and front), face and accessory, all on the same frame grid and anchored at the feet; draw in a fixed order. For animation, let layers that do not deform (hair, hat, accessory) follow a per-frame y-offset table instead of redrawing them per frame; this makes 2-4-frame walk and idle cycles cheap to author as text.
- Horizontal flip: bake the mirrored version once (`x.translate(w, 0); x.scale(-1, 1)`) rather than transforming every frame; when a design has asymmetric lighting, prefer a separately lit mirrored sprite for main characters.
- Procedural furniture and backgrounds: write small generators (`plank(x, y, w)`, `tile(x, y)`, `shelf(...)`, `window(...)`) that draw with `fillRect` from the same palette indices and pre-render the whole static interior and the facade to one background canvas each; add a seeded pseudo-random 1-pixel variation (knots in wood, chipped tiles) so large surfaces do not look flat.
- Text: web fonts rendered at tiny sizes on a low-resolution canvas come out anti-aliased and blurry after nearest-neighbour upscaling, so use a bitmap font defined in code (e.g. 5x7 or 4x6 glyphs as bit rows, baked per colour like sprites). Portuguese needs the accented set `á à â ã é ê í ó ô õ ú ç` and capitals; reserve 2-3 extra rows above cap height for accents and a line height of about 10-11 px. If long dialogue text is needed, an alternative is a DOM text overlay above the canvas using a pixel-style web font at an integer multiple of its design size, which stays crisp and accessible.
- 9-slice panels: bake a small source tile (e.g. 12x12 with 4 px corners) and draw nine `drawImage(src, sx, sy, sw, sh, dx, dy, dw, dh)` calls: corners 1:1, edges and centre tiled (not stretched) to keep pixel patterns intact; cache each resulting panel size in an offscreen canvas because panels rarely change.

### Gaps
- No source was retrieved that documents offscreen-canvas palette swapping, layered paper-doll sprites, bitmap fonts or 9-slice drawing specifically for Canvas 2D; those recipes are standard practice presented from my own knowledge.
- No measured data on the cost of `fillRect`-per-pixel baking versus `putImageData`; at these sprite sizes either is negligible, but that is an assumption.
- The Google Groups link for the js13k graphics tutorial looks like a repost of unknown provenance; treat it as low authority.

## 6. Performance, input and audio on mobile

### Takeaway
Cache everything static in offscreen canvases, draw at integer coordinates in a `requestAnimationFrame` loop, use Pointer Events with `touch-action: none` on the canvas, keep tappable areas at least 44 CSS px, and create/resume the `AudioContext` synchronously inside the first tap, re-resuming after the tab returns from the background.

### Cited Findings
- MDN's canvas optimisation advice: pre-render repeated primitives to an offscreen canvas; use several layered canvases for complex scenes; create the context with `canvas.getContext("2d", { alpha: false })` when transparency is not needed so the browser can optimise compositing. — [MDN: Optimizing canvas](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Optimizing_canvas)
- An older revision of the same MDN page advises whole-number coordinates because drawing at fractional positions (its example is `drawImage` at 0.3, 0.5) forces sub-pixel rendering; I could not confirm this section is still in the live page. — [MDN Optimizing canvas (mirror)](https://docs.w3cub.com/dom/canvas_api/tutorial/optimizing_canvas)
- web.dev gives the layered example of rendering the foreground every frame but the background only every Nth frame. — [web.dev: Improving HTML5 Canvas performance](https://web.dev/articles/canvas-performance/)
- MDN's pointer-events guide sets `touch-action: none` on the canvas so the browser does not apply its default touch behaviours; the W3C spec uses the same example, disabling panning and zooming so all events on the canvas reach the application. — [MDN: Using Pointer Events](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events/Using_Pointer_Events); [W3C Pointer Events](https://www.w3.org/TR/2020/WD-pointerevents3-20201001)
- `setPointerCapture()` designates an element as the capture target for subsequent events of that pointer, which keeps a drag working when the finger leaves the element; `touch-action: none` should be scoped to the element that needs it because it also disables touch scrolling there. — [MDN: Pointer events](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events); [javascript.info pointer events (mirror)](https://git.jeena.net/jeena/en.javascript.info/raw/branch/master/2-ui/3-event-details/6-pointer-events/article.md)
- Touch target sizes: WCAG 2.2 SC 2.5.8 (AA) requires at least 24x24 CSS px or equivalent spacing; SC 2.5.5 (AAA) asks for 44x44 CSS px; Apple's Human Interface Guidelines recommend 44x44 pt; Material Design recommends 48x48 dp. — [Deque axe rule: target-size](https://dequeuniversity.com/rules/axe/4.8/target-size); [NZ Government web accessibility guidance](https://govtnz.github.io/web-a11y-guidance/ka/accessible-ux-best-practices/mobile-apps/mobile-app-a11y-by-feature-type/touch-and-pointer-target-sizing.html); [AllAccessible: WCAG 2.5.8 guide](https://allaccessible.org/blog/wcag-258-target-size-minimum-implementation-guide)
- Web Audio autoplay policy: an `AudioContext` created before a user gesture starts in the `suspended` state and must be resumed (or created) after a user gesture; Chrome logs a warning to that effect. — [Chrome for Developers: Web Audio, Autoplay Policy and Games](https://developer.chrome.com/blog/web-audio-autoplay)
- iOS has always required a user gesture to start an `AudioContext` or media element. — [WebKit bug 180522](https://bugs.webkit.org/show_bug.cgi?id=180522)
- iOS-specific reports from library maintainers and forums: create or resume the context synchronously inside the touch/click handler (resuming later in async code can give silent playback); call `resume()` in the gesture even if `state` already reads `"running"`; audio can stop after Safari is backgrounded and come back only after another tap. These are practitioner reports, not specification text. — [Scandit Howler context manager notes](https://cdn.jsdelivr.net/npm/@scandit/web-datacapture-core@8.3.1/build/js/private/customHowler/WebAudioContextManager.d.ts); [Babylon.js forum](https://forum.babylonjs.com/t/audio-is-not-resuming-to-play-after-visibilitychange-in-iphone-browsers-works-on-android-and-desktop/54164); [html5gamedevs thread](https://html5gamedevs.com/topic/48284-solved-webaudio-on-ios-still-no-solution-in-2022)
- MDN's "Advanced techniques" tutorial builds synthesised sounds from an `OscillatorNode` with a custom `PeriodicWave` ("sweep"), multiple oscillators with a square-wave LFO gating a `GainNode` ("pulse"), and a random-filled `AudioBuffer` played through an `AudioBufferSourceNode` and `BiquadFilterNode` ("noise"); `OscillatorNode` ships with `sine`, `square`, `sawtooth` and `triangle` waveforms, and the tutorial builds an amplitude envelope with a gain node. Samples are in the range -1.0 to 1.0. — [MDN: Advanced techniques, creating and sequencing audio](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Advanced_techniques)

### Inferences
- Render loop (standard practice, not sourced in this session): one `requestAnimationFrame` loop; compute `dt` from the timestamp and clamp it (e.g. to 50 ms) so a backgrounded tab does not produce a huge step; advance sprite animations on their own low-rate timers (2-8 fps) so that 60 Hz and 120 Hz displays look the same; pause the simulation and suspend audio on `document.visibilitychange`.
- With a 320x180 buffer the per-frame cost is one background `drawImage`, a few dozen sprite blits and one upscale blit, which is far below any mobile budget. The main risks are accidental per-frame re-baking, per-frame `getImageData`, and creating canvases or gradients inside the loop.
- Input mapping: convert pointer coordinates with `const r = cv.getBoundingClientRect(); const gx = (e.clientX - r.left) * W / r.width | 0;` (same for y) so hit-testing is done in art pixels. Hit boxes should be larger than the sprite: at about 2 CSS px per art pixel, a 44 CSS px target is roughly 22x22 art pixels, so pad small items (cups, coins) to at least that and resolve overlaps by nearest centre.
- CSS to add around the canvas (property names from general knowledge, UNVERIFIED here): `touch-action: none; user-select: none; -webkit-user-select: none; -webkit-touch-callout: none; -webkit-tap-highlight-color: transparent;` plus a viewport meta tag with `width=device-width, initial-scale=1, viewport-fit=cover`. Listen for `pointerdown`, `pointermove`, `pointerup` and `pointercancel`.
- Audio unlock pattern: on the title screen show "Toque para começar"; in that `pointerdown`/`click` handler synchronously run `ac = ac || new (window.AudioContext || window.webkitAudioContext)(); ac.resume();` and play a very short quiet blip. Re-run `ac.resume()` on every later user gesture while `ac.state !== 'running'`, and on `visibilitychange` back to visible.
- Chiptune and ambience recipes with oscillators (my proposals built on the MDN building blocks):
  - Note: `OscillatorNode` (`square` for melody, `triangle` for bass) into a `GainNode`; envelope `gain.setValueAtTime(0.0001, t); gain.exponentialRampToValueAtTime(0.2, t + 0.01); gain.exponentialRampToValueAtTime(0.0001, t + dur);` then `osc.start(t); osc.stop(t + dur)`. Exponential ramps cannot reach 0, so use 0.0001.
  - Scheduling: a look-ahead scheduler (timer every 25 ms scheduling notes about 100 ms ahead on `ac.currentTime`) for a short bossa-nova-style loop; keep the pattern as arrays of note numbers and convert with `440 * 2 ** ((n - 69) / 12)`.
  - Café ambience: looped white-noise buffer through a `lowpass` `BiquadFilterNode` at roughly 400-800 Hz and very low gain for room tone; band-passed noise bursts for the milk steamer; a short high `triangle` blip for the door bell; filtered noise with a higher cutoff for rain on the facade.
  - Route everything through one master `GainNode` so a mute button and a volume setting are a single parameter; persist the mute choice in `localStorage`.

### Gaps
- No MDN text on `requestAnimationFrame` behaviour (throttling in background tabs, 120 Hz displays) was retrieved; the loop advice is standard practice from my own knowledge.
- The iOS hardware silent switch behaviour for Web Audio and the current state of iOS audio re-locking after backgrounding were not confirmed by an authoritative source.
- No source was retrieved on `OffscreenCanvas` (the worker-capable API) support on iOS; the notes above use plain `document.createElement('canvas')` buffers, which avoid that question.
- No benchmark data for Canvas 2D on low-end Android devices was found.
