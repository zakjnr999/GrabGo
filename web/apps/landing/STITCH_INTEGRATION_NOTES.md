# Stitch UI Integration Notes

## Route Mapping

- `/` -> `public/stitch_pages/home.html`
- `/about` -> `public/stitch_pages/about.html`
- `/services` -> `public/stitch_pages/services.html`
- `/pricing` -> `public/stitch_pages/pricing.html`
- `/faq` and `/support` -> `public/stitch_pages/faq.html`
- `/contact` -> `public/stitch_pages/contact.html`
- `/vendor` -> `public/stitch_pages/vendor.html`
- `/customer` -> `public/stitch_pages/customer.html`
- `/rider` -> `public/stitch_pages/rider.html`
- `/legal/privacy` -> `public/stitch_pages/privacy.html`
- `/legal/terms` -> `public/stitch_pages/terms.html`
- `/legal/cookies` -> `public/stitch_pages/cookies.html`

## Notes

- Routes are now implemented as App Router pages using `app/_lib/stitch-page.tsx`.
- Next.js rewrites are no longer used for stitched pages.
- Material Symbols markup is converted at render-time to local SVG icons via `iconoir-react` and `lucide-react`.
- Theme tokens are normalized to mobile app accent palette (`accentOrange`: `#FE6132`).
- Source exports live in `web/stitch_grabgo/`.
- Integrated copies live in `web/apps/landing/public/stitch_pages/`.
- Primary nav/legal links were patched from `#` to real routes where available.
