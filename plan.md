# Phonon Characters — build plan

Native macOS character-chat app. Twelve Gradium character voices, an on-device brain,
on-device live speech recognition, and a space-bar push-to-talk loop that interrupts the
character mid-sentence.

- **Target:** macOS 15+, arm64 only (Phonon's Core ML core is arm64).
- **Hardware:** MacBook Pro M1 Pro / 16 GB. Measured peak well under budget.
- **Distribution:** `.dmg` with code only (~25 MB). Weights and the optional ear runtime download
  on first launch.
- **App:** `Phonon Characters`, `com.sharath.phononcharacters`.

---

## 0. Decisions (final)

| Area | Decision | Why |
|---|---|---|
| UI | SwiftUI, single window, no sandbox | Native, small, spawns helper processes |
| TTS | `PhononTTS` Swift package (Core ML) | 31M model, 95 MB app footprint, streams 80 ms |
| TTS weights | `phonon-31m-en-coreml.zip` v0.6.0 (131 MB) | Verified: contains all 12 character voices |
| Brain | `LFM3-1.7B-Q4_K_M.gguf` (1.05 GB) via `llama serve` | LFM3 reference; 83–85 tok/s on this M1 Pro |
| Ears | `Phonon-2.5-English` (158 MB) via Fermion engine | User request; 4.82 % WER, MLX, streaming |
| Live STT | `ws://…/v1/audio/stream`, PCM16 frames | Partials ~0.5 s while speaking |
| Characters | 2D ink drawing in code (`InkFace` + `CharacterLook`), mouth driven by the spoken text | no art assets, matches the paper/ink stage, lips follow words |
| Signing | Hardened runtime, ad-hoc; notarize script ready | No Developer ID cert on this Mac |

### Model endpoints (pinned)

| Model | URL | Size | SHA-256 |
|---|---|---|---|
| Voice | `github.com/gradium-ai/xn-ptts/releases/download/v0.6.0/phonon-31m-en-coreml.zip` | 131 MB | `2869326a…c4218` |
| Brain | `huggingface.co/LiquidAI/LFM3-1.7B-GGUF/resolve/main/LFM3-1.7B-Q4_K_M.gguf` | 1.05 GB | `3793e1e6…5c93c4` |
| Ears model | Fermion `phonon-2.5-en` (auto-fetched into `~/.cache/fermion`) | 158 MB | `87dacb41…bdadd` |
| Ears engine | `fermion-research[mlx]==0.2.15` installed by `uv` | ~456 MB | — |
| llama.cpp | b12032 / v0.8.0 macOS arm64, bundled | 31 MB | — |

---

## 1. Phase A — Project skeleton

- [x] A1. `project.yml` (XcodeGen): macOS 15, Swift 5 mode, arm64, hardened runtime
- [x] A2. Layout: `App/`, `Core/`, `Services/`, `Features/{Onboarding,Stage,Conversation,Settings}`, `Resources/`, `Packaging/`
- [x] A3. `PhononCharactersApp.swift` — single window, hidden title bar, 1180×820
- [x] A4. `Info.plist` — mic usage string, min system, no window restoration
- [x] A5. Entitlements — no sandbox, audio input, network client, library validation off
- [x] A6. `xcodegen generate` + Debug/Release builds succeed
- [x] A7. Theme: paper, grain, ink rules, serif display type

## 2. Phase B — Core

- [x] B1. `Persona` — all 12 characters (voice, tagline, greeting, persona, palette, emblem)
- [x] B2. Catalog order, wrap-around, short names
- [x] B3. `AppPaths` — Application Support, Models, Downloads, Logs, space checks
- [x] B4. `ModelCatalog` — voice + brain, pinned sizes and hashes
- [x] B5. `Preferences` — auto-speak, onboarding, selected character

## 3. Phase C — Model downloads

- [x] C1. `ModelStore` with per-artifact state
- [x] C2. Resumable `URLSessionDownloadTask` (resume data persisted)
- [x] C3. Progress (bytes, %, speed), free-space gate
- [x] C4. SHA-256 verification (`CryptoKit`)
- [x] C5. `ditto` extraction + `PhononModels.install(bundled:)`
- [x] C6. Delete / re-download, disk usage
- [ ] C7. *Not clicked through end-to-end from a blank disk* (models were staged for testing); code path mirrors the verified install.

## 4. Phase D — TTS

- [x] D1. Resolved `PhononTTS` and read the real API from the SPM checkout
- [x] D2. `PhononService`: install + `Phonon.load`, compile note on first run
- [x] D3. Voice switching (`setVoice`), cached
- [x] D4. Sentence streaming into a custom `VoicePlayer`
- [x] D5. Playback-amplitude tap drives the mouth and aura
- [x] D6. Cancel/interrupt: generation task + `player.stop()`
- [x] D7. Graceful missing-bundle error

## 5. Phase E — llama.cpp sidecar

- [x] E1. `Resources/llama` (llama + dylibs), folder reference in the app
- [x] E2. `LlamaServer`: free port, `serve -m … -c 4096 --jinja -ngl 99`, log file
- [x] E3. Health polling, crash detection, log tail in errors
- [x] E4. Single shared startup (fixed a race that spawned four 1.2 GB processes)
- [x] E5. Cleanup on Cmd+Q verified (no orphan processes)
- [x] E6. Actionable errors in the banner

## 6. Phase F — Brain

- [x] F1. OpenAI-compatible streaming chat
- [x] F2. SSE parser with `[DONE]`
- [x] F3. Per-character history + persona prompts
- [x] F4. Cancellation
- [x] F5. **Fixed:** LFM3 thinks by default; `chat_template_kwargs.enable_thinking=false` so the reply is the spoken line
- [x] F6. Reply streams into the card while TTS speaks sentence 1

## 7. Phase G — Stage UI

- [x] G1. Sketch layout: name above portrait, mid-height chevrons, reply card bottom-left, composer bottom-right
- [x] G2. Procedural portrait: ink head, hair cap + strands, eyes/nose/mouth, emblem, aura
- [x] G3. Idle breathing, dashed rotating ring, reduced-motion support
- [x] G4. Speaking mouth/halo from real playback amplitude; listening ring
- [x] G5. Slide/fade switch, ←/→, wrap-around, speech stops on switch
- [x] G6. Streaming reply card with stop control
- [x] G7. Composer with label, prompt, send/mic states
- [x] G8. "my message" echo pill above the composer
- [x] G9. Return sends, Esc stops, Space PTT
- [x] G11. Footer microphone switcher with the live input name
- [x] G12. Ink character rig: `InkFace` paths + 12 `CharacterLook` records (head,
  hair, beard, accessory, ears, shoulders); `MouthTrack` shapes the mouth from the
  reply text, advanced on voiced playback frames
- [x] G13. Stage scenes: `CharacterScene` + `SceneLayer` draw a per-character backdrop,
  prop, motes and wind behind the face; idle motion, voice-reactive breeze, reduced-motion still
- [x] G10. Accessibility labels, contrast, keyboard paths

## 8. Phase H — Push-to-talk & live transcription

- [x] H1. `KeyMonitor` (local key events, repeat suppression, text-field exemption)
- [x] H2. `AudioCapture` — AVAudioEngine tap → mono PCM16 @ 16 kHz
- [x] H3. `RealtimeTranscriber` — Fermion `/v1/audio/stream` (config text frame + binary PCM)
- [x] H4. `partial` replaces hypothesis; `final` commits; `done` is authoritative
- [x] H5. Space down → interrupt → listen → connect
- [x] H6. Space up → `{"type":"end"}` → transcript → send
- [x] H7. Tap cancel, Esc cancel, one-stream-at-a-time respected (stale stream race fixed)
- [x] H8. Listening UI: halo, waveform, live transcript, footer hints
- [x] H9. Missing ears → install prompt; interruption still works
- [x] H10. Permission requested at launch; 45 s timeout; silent-mic hint after 2.5 s
- [x] H11. **Verified** app WebSocket client end-to-end with a WAV harness: live partials + accurate final transcript
- [ ] H12. *Live microphone speech on this machine could not be verified:* the built-in input reports digital silence (−91 dB) even to `ffmpeg`. The app detects and reports "No microphone signal". The client/server path itself is proven (H11).

## 9. Phase I — Onboarding & settings

- [x] I1. Welcome screen with privacy, features, disk space
- [x] I2. Voice / Brain / Ears rows with state, progress, delete
- [x] I3. Voice + brain required; "Enter the stage" enabled when ready
- [x] I4. Settings: models, ears, microphone input, auto-speak, credits
- [x] I5. Onboarding replay (`onboarded` flag)

## 10. Phase J — Packaging

- [x] J1. `Packaging/build.sh` — Release build, nested signing, llama entitlements, verify
- [x] J2. `Packaging/make-dmg.sh` — DMG with Applications symlink
- [x] J3. `Packaging/notarize.sh` — one command with a Developer ID + notary profile
- [x] J4. No weights in the app bundle; DMG mounts and launches
- [x] J5. README with build, models, limits

## 11. Verification results

- [x] K1. Clean Release build; zero errors
- [x] K2. Onboarding renders with installed state
- [x] K3. Voice greeting plays on first visit (Snow Queen, Mortlake, Bramwell observed)
- [x] K4. Character switch stops speech and re-voices
- [x] K5. Chat: streamed, in-character reply on the first sentence
- [x] K6. Space hold: live transcript while speaking, release sends, reply speaks
- [x] K7. Space/Esc interruption stops audio and generation
- [x] K8. Measured: brain 83–85 tok/s, 1.14 GB RSS, prompt 127 tok/s; app footprint 95 MB; TTS streams; ear partials ~0.5 s
- [x] K9. Quit leaves no orphan `llama`/`fermion`
- [x] K10. DMG built, mounted, app copied out and launched
- [x] K11. Ink stage: all 12 characters render from `CharacterLook`; mouth shapes
  (closed, open, wide, tongue) verified offscreen and driven by `MouthTrack` on
  voiced frames; `#if DEBUG` asserts every persona has a look
- [x] K12. All 12 stage scenes render offscreen (`CharacterScene`); backdrops, props and
  motes sit behind the bust without crowding it; reduced motion is a still composition

---

## Known limits / fallbacks

1. **The system default input on this Mac is a silent USB device.** The footer microphone menu (also in Settings) switches to the built-in mic; the app detects silence and points at the switcher.
2. **arm64 only** — Phonon's Core ML core.
3. **Ad-hoc signed** — first open needs right-click → Open until `notarize.sh` is run with a
   Developer ID certificate.
4. **Ears engine** installs Python/MLX via `uv` (uses an existing `uv`, else a pinned 14 MB
   binary). ~456 MB on disk; torch/sympy/networkx are removed after install.
5. **Character art** — the cast is drawn, not painted: 12 `CharacterLook` records
   over one ink renderer. The mouth is letter-to-shape, not phoneme-accurate lip-sync;
   a real phonemizer or a rigged 3D runtime is the upgrade path.
