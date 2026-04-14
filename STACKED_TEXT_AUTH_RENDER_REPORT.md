# Stacked Text Auth Render Investigation

## Baseline That Worked

The last committed version before the later experiments used:

- template-based stacked text image
- provider logo on the left
- stacked text on the right
- no colored indicators

That version behaved correctly with AppKit menu bar tinting, including white-on-blue selected state.

## Goal of the Later Experiments

The later work tried to add per-line severity indicators for stacked mode while preserving:

- white logo/text during selected menu bar state
- correct light/dark adaptation
- colored or more expressive per-line status signals

The hard constraint discovered during testing was that AppKit handles template images and non-template images very differently inside `NSStatusItem`.

## Attempt Log

### 1. Colored dots inside a non-template composite image

Implementation:

- switched stacked mode from template image to custom rendered non-template image
- drew provider logo and text manually
- added colored dots beside `S` and `W`

Expected result:

- keep white/black menu bar adaptation for logo/text
- allow true green/orange/red dots

Observed result:

- logo/text repeatedly turned black during auth flow, keychain prompts, browser cookie import, and later async redraws
- selected blue menu bar background remained visible while custom image often rendered as non-selected black

Why it failed:

- AppKit does not preserve template-style selected rendering for custom non-template status item images
- multiple async redraw paths during auth/import/refresh caused the icon to be regenerated outside a stable selected-state signal

### 2. Appearance-aware manual coloring

Implementation:

- rendered non-template logo/text with resolved `labelColor`
- later switched highlighted text to explicit white
- later tried `selectedMenuItemTextColor`, `alternateSelectedControlTextColor`, and direct `contentTintColor`

Observed result:

- improved some cases, but did not remain stable during the whole auth flow
- icon could still be black while the menu bar stayed visibly selected/blue

Why it failed:

- AppKit’s selected-state signaling for the status item was not stable across all auth-flow redraw paths
- manual color selection could not reliably mirror template-image behavior

### 3. Menu highlight and open-menu tracking

Implementation:

- used `openMenus`, `button.isHighlighted`, and `button.cell?.isHighlighted`
- forced redraw on `menuWillOpen` and `menuDidClose`
- added follow-up redraw on the next main-actor turn

Observed result:

- fixed some stale-image cases
- did not fix auth-flow black rendering

Why it failed:

- keychain prompts and OpenAI web refreshes continued after AppKit had already dropped menu tracking
- redraws during those phases were no longer happening in a state that looked "selected" to the code

### 4. Latch-based selected appearance preservation

Implementation:

- introduced temporary selected-appearance latches tied to:
  - menu open
  - keychain prompt presentation
  - OpenAI cookie import start/end
  - OpenAI web refresh start/end
  - recent interaction grace windows

Observed result:

- some phases improved
- auth completion often turned the icon white immediately
- later background redraws could still turn it black again

Why it failed:

- this became a state-reconstruction system layered on top of AppKit instead of using AppKit’s template behavior directly
- too many redraw entry points existed, and they were not all aligned with the visible selected state the user saw

### 5. Template image plus template-safe markers

Implementation:

- reverted to template rendering
- tried template-safe side markers:
  - faces
  - open circle / dash / exclamation

Observed result:

- white-on-blue selected rendering worked again because the icon returned to template behavior
- markers were too small or not legible enough at menu bar scale

Why it was rejected:

- readability was not good enough in the actual menu bar

## Main Technical Conclusion

The combination that did **not** work reliably was:

- non-template stacked composite image
- manually colored logo/text
- colored per-line indicators
- AppKit selected menu bar rendering during async auth/import/refresh work

The combination that **did** work reliably was:

- single template image for the whole stacked icon

That means:

- if the icon must always adapt correctly to white-on-blue selected state, keep the whole stacked icon template-based
- if per-line indicators are added, they must also be template-safe and legible at very small size
- independently colored indicators should be treated as incompatible with the current single-image `NSStatusItem` approach

## Recommended Path Forward

Recommended next implementation direction:

1. Keep stacked mode fully template-based.
2. Avoid colored dots.
3. If indicators are revisited, prefer the simplest possible template-safe marks and test them directly in the real menu bar before adding more logic.
4. If truly colored indicators are required, that should be treated as a larger architectural change, likely requiring a custom status item view rather than a single template image.

## Current Repository State

After reverting the uncommitted experiments, the repo is back to the last committed stacked-text implementation:

- template-based stacked icon
- stable white/black AppKit rendering
- no later marker experiment changes
