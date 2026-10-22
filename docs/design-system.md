# TrapShooterPro design system (black & white)

Source: `bw-theme.css` and `login.css` (the Prethyega black‑and‑white system), translated into iOS terms.
Code: `Packages/TrapDesign` (SwiftUI). This document is the mapping and the reasons behind it.

## 1. Principles kept from the reference

- **Pure black and white with precision greys.** One ink colour, one paper colour, a grey scale between them. Colour appears only for status.
- **Structure through rules, not colour.** 2 pt ink rules under section labels, a 3 pt ink rule on top of KPI tiles, a 4 pt rule on the leading edge of identity banners, 1.5 pt borders on cards and pills.
- **Dense, quiet typography.** Small uppercase tracked labels over strong values; monospaced digits for anything numeric.
- **Capsule badges with an 8 pt dot** for live status.
- **Flat surfaces with very soft shadows** (1 to 3 pt blur at 4 to 6 % opacity), one large shadow for sheets.

## 2. Principles changed for iOS

| Reference | iOS version | Why |
|---|---|---|
| Fixed light theme | Light **and dark**; every token is dynamic | iOS apps are expected to follow the system appearance (App Review and user expectation). Ink and paper swap; the status colours lighten in dark mode. |
| Bebas Neue display, Inter body | **SF Pro condensed, bold, uppercase, tracked** for display; **SF Pro** body; **SF Mono** values | Decision of 22 Oct: SF only. The condensed width gives the same tall, narrow display feel without bundling fonts. |
| Pixel sizes (11, 13, 14, 28 px) | **Dynamic Type text styles** (caption2, subheadline, body, title) | Accessibility and App Review. Only the timer readout and the scorecard keep fixed sizes. |
| Hover states | **Pressed states** (opacity 0.9, scale 0.98) | No hover on touch. |
| 28 to 38 px icon buttons | **44 pt** | Apple's minimum tap target. |
| 240 px sidebar | **Tab bar** on iPhone, **NavigationSplitView** sidebar on iPad | Native navigation; the sidebar rhythm (ink background, white text, 12 % active fill) survives on iPad. |
| Modal boxes, 14 px radius, dark header | **Sheets** with `presentationCornerRadius(14)` and an ink header panel | Native presentation, same look. |
| Table headers in ink with white uppercase text | Same, built as a SwiftUI row | Keeps the signature table look for ledgers and scheme tables. |
| Letter‑spacing on body text | Tracking only on display and labels | SF is already tuned; tracking body text hurts legibility. |
| CSS transitions | `BWMotion` animations, `Reduce Motion` respected | Same durations and curves. |

## 3. Colour tokens

Light values are from `login.css` (the zinc scale). Dark values read the same scale from the other end.

| Token | Role in reference | Light | Dark |
|---|---|---|---|
| `BW.ink` | `--clr-black`: text, filled buttons, table headers, rules | `#000000` | `#FFFFFF` |
| `BW.paper` | `--clr-card-bg`: cards, sheets | `#FFFFFF` | `#18181B` |
| `BW.surface` | `--clr-surface` grey‑100: page background | `#F4F4F5` | `#000000` |
| `BW.surfaceAlt` | grey‑50: zebra rows, quiet boxes | `#FAFAFA` | `#27272A` |
| `BW.border` | `--clr-border` grey‑200 | `#E4E4E7` | `#3F3F46` |
| `BW.borderStrong` | grey‑300: control borders | `#D4D4D8` | `#52525B` |
| `BW.text` | grey‑900 | `#18181B` | `#F4F4F5` |
| `BW.textSecondary` | grey‑700: field labels | `#3F3F46` | `#D4D4D8` |
| `BW.textMuted` | `--clr-muted` grey‑500 | `#71717A` | `#A1A1AA` |
| `BW.onInk` | text on ink | `#FFFFFF` | `#000000` |
| `BW.inkOverlay(α)` | `rgba(255,255,255,α)` fills on black panels | white α | black α |

Status (the only colour), each with foreground, background, border and dot:

| Token | Foreground | Background | Border | Dot |
|---|---|---|---|---|
| `BW.success` | `#065F46` | `#ECFDF5` | `#A7F3D0` | `#10B981` |
| `BW.warning` | `#92400E` | `#FFFBEB` | `#FDE68A` | `#F59E0B` |
| `BW.danger` | `#991B1B` | `#FEF2F2` | `#FECACA` | `#EF4444` |
| `BW.neutral` | grey‑700 | grey‑100 | grey‑200 | grey‑500 |
| `BW.inkStatus` | on‑ink | ink | ink | on‑ink |

In dark mode the status foreground becomes the light border tint and the background becomes the dot colour at 15 % opacity.

Shooting domain mapping (keeps the G / Y / R meaning of the web app):

| Meaning | Token |
|---|---|
| Hit with the first shot (G) | `BW.hitFirst` = success |
| Hit with the second shot (Y) | `BW.hitSecond` = warning |
| Lost (R) | `BW.lost` = danger |
| Delete, NO TARGET | `BW.destructive` `#DC3545` (`#EF4444` dark) |
| Timer armed / listening | ink pill, success dot when audio is flowing |

## 4. Typography

| Reference | Token | Face |
|---|---|---|
| `.page-title` 22 px Bebas, tracking 1 | `.bwDisplay(.title2)` | SF Pro condensed bold, uppercase, tracking 1 |
| `.brand-header h2` 28 px, tracking 2.5 | `BWFont.display(.title)` + `BWTracking.brand` | same, tracking 2 |
| `.card-title` 17 px with 2 px rule | `BWCardTitle` | condensed title3 + rule |
| `.form-header h1` 28 px 700 tracking −0.5 | `BWFont.heading` | SF Pro title bold |
| modal `h2` 18 to 20 px 700 | `BWFont.subheading` | title3 bold |
| body 14 px Inter | `BWFont.body` | body |
| 13 px secondary | `BWFont.secondary` | subheadline |
| 11 px 600 uppercase labels | `.bwLabel()` | caption2 semibold, uppercase, tracking 0.6 |
| `.vm-section-label` 12 px 700 tracking 1 + 2 px rule | `BWSectionLabel` | footnote bold uppercase + rule |
| mono values 12 to 13 px | `BWFont.value(_:)` | SF Mono, tabular digits |
| `.vm-kpi-value` 24 px 700 mono | `BWFont.valueLarge` | SF Mono title bold |
| timer readout | `BWFont.readout(size: 64)` | SF Mono, fixed size |

## 5. Metrics

| Reference | Token |
|---|---|
| spacing 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 | `BWMetrics.s1 … s12` |
| `--radius-md` 8, `--radius-lg` 14, `--radius-xl` 24, pills 999 | `radiusMD`, `radiusLG`, `radiusXL`, `Capsule` |
| borders 1 and 1.5 px | `hairline`, `stroke` |
| 2 px rules, 3 px top accent, 4 px left accent | `rule`, `accentTop`, `accentLeft` |
| control height 48, action 40, icon 28 to 38 | `controlHeight` 48, `actionHeight` 44, `iconButton` 44 |
| shadows `0 1px 3px 4%`, `0 4px 12px 6%`, `0 20px 60px 15%` | `Shadow.card`, `.raised`, `.sheet` |
| `--t-fast` 0.15 s, 0.2 s, `--t-sidebar` 0.28 s cubic‑bezier(0.4,0,0.2,1), `vmBoxIn` 0.24 s overshoot | `BWMotion.fast`, `.standard`, `.layout`, `.appear` |

## 6. Components

| Reference class | SwiftUI |
|---|---|
| `.card`, `.vm-card` | `.bwCard()` |
| `.kpi-card`, `.vm-kpi-card` | `BWKPITile` (card + `.bwAccentTop()`) |
| `.vm-identity-banner` | `.bwCard().bwAccentLeading()` |
| `.card-title` | `BWCardTitle` |
| `.vm-section-label` | `BWSectionLabel` |
| `.form-label`, `.vm-field` | `.bwLabel()`, `BWField` |
| `.status-badge`, `.vm-badge-*`, `.hint-pill` | `BWPill(status:dot:uppercase:)` |
| `.status-dot` | `BWStatusDot` |
| `.btn-submit`, `.btn-vm-action.primary`, `.btn-dark` | `.buttonStyle(.bwPrimary)` |
| `.btn-vm-action`, `.btn-outline`, `.auth-btn-secondary` | `.buttonStyle(.bwSecondary)` |
| `.btn-danger-red` | `.buttonStyle(.bwDestructive)` |
| `.btn-icon`, `.vm-modal-close-btn` | `.buttonStyle(.bwIcon)` / `.bwIcon` with `onInk: true` |
| `.vm-table thead th`, `tbody tr` | `BWTableHeader`, `.bwTableRow(index:)` |
| `.showcase-panel`, `.vm-modal-header` | `BWInkPanel` |
| `.form-control` 48 px, 1.5 px border, focus ring black | `TextField` with `.textFieldStyle(.plain)` inside a 48 pt bordered box; focus swaps border to ink |

## 7. Where each screen uses it

- **Record**: range data and conditions as `BWCardTitle` cards; the 25‑target entry uses ink‑filled selected buttons and status pills for results; the scorecard is a `BWTableHeader` table with zebra rows.
- **Timer**: the readout in `BWFont.readout` inside a card; audio‑in line as a `BWPill` with a success dot when audio is flowing; settings as `BWField` rows.
- **Rounds**: list rows with a leading accent for the selected round; KPI tiles at the top (rounds, hit rate, average 1st shot).
- **Analysis**: `BWSectionLabel` per dimension, `BWTableHeader` tables, `BWKPITile` overview.
- **Schemes**: ink‑header table, 15 machines per scheme.
- **Settings**: grouped cards; destructive actions in `.bwDestructive`.
- **iPad**: `NavigationSplitView` with an ink sidebar (`BWInkPanel`, active item on `inkOverlay(0.12)`, pressed `inkOverlay(0.07)`), matching the reference sidebar.
