## 2025-05-15 - Balancing Editorial Aesthetics with Accessibility
**Learning:** In "editorial" design systems that prioritize typography and clean layouts (like FoodLogger), icon-only buttons are often used to maintain a minimalist look, but they frequently lack accessibility labels. This creates a barrier for screen reader users despite the high visual polish.
**Action:** When working with editorial-style UIs, always audit "floating" or "minimalist" icons for `accessibilityLabel` support, as they are the most likely candidates for accessibility gaps in this design style.
