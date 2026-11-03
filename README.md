# Vessel (working title)

A 3D management game: you are the mind of an interstellar probe that crosses to a star, lands, builds industry with a robot workforce, builds a copy of itself and launches it.

- What the game is: `docs/DESIGN.md`
- What to build, in order: `docs/PLAN.md`
- Current state: `docs/STATUS.md`
- Lore (owned by Steve): `docs/LORE.md`

```
npm install
npm run dev        # local dev server
npm test           # sim tests
npm run build      # type check + production build
npm run lint
npm run screenshot # optional, needs Playwright: writes shots/latest.png
```

Deployed to GitHub Pages from `main` by `.github/workflows/pages.yml`.
