# Public release checklist

- [x] Review the modernization against Klei's abandoned-mod guidance.
- [x] Credit the original "Better pet" Workshop item in the public description.
- [x] Add scoped licensing and third-party notices for the maintained fork.
- [x] Use the mod in a regular multiplayer server with friends without observed
  Lua errors (reported 2026-07-26).
- [x] Upload and verify the clean 1.7.2 Workshop package.
- [x] Verify the Workshop description, exact benefit values, title image, change
  notes, version tag, author, and source credit.
- [x] Keep Debug Mode disabled by default and document
  `c_loyalcritters_status()`.
- [x] Change Steam Workshop visibility to Public (2026-07-26).

## Recommended follow-up regression coverage

- [ ] Run a focused two-player pass for puppy, kitten, perdling, glomling, and
  peeper owner-only support.
- [ ] Recheck Lamb storage ownership and contents across save/load and reconnect.
- [ ] Recheck Dragonling and Mothling follow distance and light behavior at
  night.
- [ ] Recheck that fed-gated benefits clear when a pet becomes hungry, is
  dismissed, or changes owner.
- [ ] With Walter support disabled, confirm Walter still cannot adopt a critter.
- [ ] With Walter support enabled, confirm Walter can adopt exactly one critter
  alongside both small and big Woby.
- [x] Keep the GitHub repository public so the Workshop source and bug-report
  link is accessible.
