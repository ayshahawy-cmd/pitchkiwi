# Design system

## 1. Visual intent

VibeFlow should feel like a quiet instrument for thought: warm, precise, and native to the Mac. The supplied references demonstrate useful hierarchy—airy panels, restrained navigation, large readable metrics, and a compact recording surface—but the implementation must use original colors, layout, copy, iconography, and motion.

Avoid a pixel-for-pixel reproduction of Wispr Flow. Do not use its logo, waveform mark, cream/teal palette, promotional banners, wording, or sidebar composition.

## 2. Product personality

- Calm rather than gamified.
- Technical without looking like a terminal theme.
- Private without looking alarming.
- Fast without frantic animation.
- Friendly without mascot copy.

## 3. Foundations

### Color tokens

Use semantic colors and verify final values for WCAG contrast in both appearances.

```text
surface.canvas.light    #F5F6F3
surface.panel.light     #FFFFFF
surface.elevated.light  #ECEEE8
text.primary.light      #171A17
text.secondary.light    #5D635E

surface.canvas.dark     #101210
surface.panel.dark      #181B18
surface.elevated.dark   #222622
text.primary.dark       #F4F6F2
text.secondary.dark     #AFB6AF

accent.primary          #B9F542  // verify contrast before use with text
accent.listening        #71D6C1
accent.processing       #A9A7FF
status.warning          #F4B860
status.error            #F06A6A
```

Accent never carries meaning alone. Use it for focus, waveform energy, active controls, and concise highlights—not large backgrounds.

### Typography

- SF Pro / system font for navigation, labels, and body.
- New York/system serif may be used sparingly for one empty-state headline only if it remains original and legible.
- SF Mono/system monospaced for shortcuts, identifiers, model hashes, filenames, and code samples.
- Prefer platform text styles and Dynamic Type behavior over fixed sizes.

### Shape and spacing

- 8-point spacing system with 4-point optical adjustments.
- Panels: 16-20 pt corner radius.
- Controls: 10-12 pt corner radius.
- HUD capsule: continuous 24-28 pt radius.
- Thin semantic separators; avoid shadows except the floating HUD and transient popovers.

## 4. Main window

Use a native split view.

Sidebar sections:

```text
VibeFlow
  Home
  Dictionary
  Snippets
  Styles
  Transforms
  Insights

System
  Settings
  Help
```

No billing, referrals, team sharing, notifications, or account avatar. A compact privacy status belongs at the sidebar bottom:

```text
LOCAL MODE
History off · Context off
```

Content width should remain readable on large displays. Cards may be used for coherent objects, not every line of settings.

## 5. Floating HUD

Default position: centered 44 pt above the bottom safe edge of the active display. It must not steal keyboard focus.

Suggested layouts:

```text
Idle (optional)          [● Ready]
Listening          [waveform  Listening  00:12   Esc]
Transcribing       [spinner   Transcribing locally]
Refining           [spark     Cleaning up]
Inserted           [check     Inserted]  (auto-dismiss)
Needs action       [warning   Couldn't insert] [View] [Copy]
```

The live waveform is based only on recent RMS amplitude and is discarded. With Reduce Motion, replace waveform animation with a static microphone icon and updating timer.

The shipped compact HUD is a 168 × 42 pt Liquid Glass capsule on macOS 26, with an Ultra Thin Material fallback on older supported releases. Its seven bars are driven by normalized microphone RMS values, not a decorative looping animation.

## 6. Key screens

### Home

- Primary readiness card: shortcut, microphone, model, Accessibility status.
- Try-it field for safe in-app dictation.
- History appears only when enabled; an empty state explains the privacy default.
- Small local privacy summary and clear data action.

### Dictionary

- Segmented control: Words / Corrections.
- Search and Add button.
- Plain rows with spoken form, exact output, enabled state, edit/delete actions.
- Never imply that the app has learned entries automatically in v1.

### Snippets

- Trigger and expansion preview.
- Highlight multiline and terminal-sensitive expansions.
- Import/export and collision warnings.

### Styles

- Categories in a sidebar/list.
- Bounded controls for tone, punctuation, paragraphing, Markdown, and filler removal.
- Live local preview using synthetic sample text; do not place user transcript in screenshots or fixtures.

### Transforms

- Cards for Polish, Prompt Builder, and custom transforms.
- Shortcut badge and preview toggle.
- Selected-text diff uses clear additions/removals and Preserve/Replace/Copy actions.

### Insights

- Local-only label.
- Words, dictations, WPM, and fixes.
- App category bars and activity heatmap.
- No competitive percentile, fake equivalence, or mobile breakdown.

### Privacy

Start with a plain-language data flow:

```text
Microphone -> This Mac -> Your cursor
```

Expose History retention, Context level, Clear Last Result, Delete History, Delete All Data, model locations, and Open Data Folder. Explain each consequence precisely.

## 7. Motion

- HUD appearance: 120-160 ms scale 0.98 -> 1 plus fade.
- State crossfade: 100-140 ms.
- Success: one restrained check stroke, no confetti.
- Error: no shake; use a stable message.
- Respect Reduce Motion by using opacity-only changes.
- Never delay transcription or insertion for animation completion.

## 8. Sound and haptics

- Optional subtle start and stop tones, off independently.
- No spoken system feedback.
- Avoid sounds similar to macOS alerts or other dictation products.
- Macs generally lack a general haptic API for this use; do not invent unsupported behavior.

## 9. Copy style

Use short factual language:

- `Listening`
- `Transcribing locally`
- `Inserted`
- `No speech detected`
- `Accessibility is off. Your text is ready to copy.`
- `This model is stored on your Mac (466 MB).`
- `Nearby text is never read while Context is off.`

Avoid absolute claims that the OS cannot guarantee, manipulative upgrade language, productivity comparisons, and anthropomorphic claims such as “VibeFlow learned you” unless the product truly implements that behavior.

## 10. Accessibility checklist

- VoiceOver order follows visual order.
- HUD state changes use polite announcements and do not repeat continuously.
- Shortcut badges have spoken equivalents.
- Minimum 44x44 pt interactive targets where layout permits.
- Text and essential icons meet contrast requirements.
- Charts have tabular/summary alternatives.
- Full Keyboard Access works on every screen.
- Focus is restored after dialogs and sheets.
- Status is never communicated only by color, waveform, or animation.
