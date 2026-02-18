# Master Plan Amendment — Vendor App Color System

## Summary
The master plan now includes a locked, implementation-ready color specification for the vendor app UI.

## Final Color Tokens

### Core (Light Default)
1. `primaryAction`: `#FE6132`
2. `primaryActionPressed`: `#E6572D`
3. `primaryActionSoft`: `#FFF1EC`
4. `background`: `#F7F8FA`
5. `surface`: `#FFFFFF`
6. `border`: `#E4E7EC`
7. `textPrimary`: `#101828`
8. `textSecondary`: `#475467`

### Service Accents
1. `foodAccent`: `#FE6132`
2. `groceryAccent`: `#4CAF50`
3. `pharmacyAccent`: `#009688`
4. `grabmartAccent`: `#2563EB`

### Semantic
1. `success`: `#16A34A`
2. `warning`: `#F59E0B`
3. `error`: `#DC2626`
4. `info`: `#0284C7`

### Dark Theme (Available, Not Default)
1. `darkBackground`: `#0F1216`
2. `darkSurface`: `#161B22`
3. `darkBorder`: `#2A3441`
4. `darkTextPrimary`: `#F3F4F6`
5. `darkTextSecondary`: `#9CA3AF`
6. Keep `primaryAction` as `#FE6132`

## Usage Rules
1. Use neutral backgrounds/surfaces for most screens.
2. Use orange only for primary actions and key confirmations.
3. Use service accents for badges, chips, tabs, and contextual highlights only.
4. Do not use full-screen saturated service-color backgrounds.
5. Keep all status communication color + icon + text label (not color alone).

## Component Mapping
1. Primary CTA buttons use `primaryAction`.
2. Secondary/ghost buttons use neutral border/text.
3. Service chips use service accent + soft neutral background.
4. Order urgency badges use semantic tokens:
   - At risk: `warning`
   - Failed/cancelled: `error`
   - Completed: `success`
   - Informational updates: `info`
5. Divider, card, and table-like rows use neutral borders for high readability.

## Accessibility Guardrails
1. Maintain WCAG-friendly contrast on text and badges.
2. Minimum readable contrast for small text against surface backgrounds.
3. Never rely on color alone for critical actions or statuses.

## Assumption
This color system is now the official vendor app design baseline and should be reflected in shared theme extensions/tokens before screen implementation begins.
