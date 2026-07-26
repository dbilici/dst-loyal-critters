# Changelog

## 1.7.2 - Description and diagnostics

- Corrected the public description: fed-gated owner buffs depend on satiation,
  while Lamb storage and Dragonling/Mothling light do not.
- Expanded `c_loyalcritters_status()` with version, debug mode, and player
  identity.
- Expanded the Workshop copy with exact benefit values and troubleshooting.
- Published the verified 1.7.2 package on Steam Workshop.

## 1.7.1 - Publish metadata refresh

- Reworded fed-state text for Steam-facing metadata and debug output.
- Added Steam Workshop ID and URL.
- Updated the preview image for the `Loyal Critters` title.

## 1.7.0 - Repository standardization

- Renamed the Steam-visible mod title to `Loyal Critters`.
- Updated Steam-visible author metadata to `k0za1ak`.
- Cleaned local duplicate files from the repository package.
- Added repository documentation and Workshop page copy.
- Renamed the repository package to `dst-loyal-critters`.

## 1.6.2 - Legacy maintenance update

## Changed
- Perdling reworked. It no longer drops a random redpouch when fed. Instead, while the Perdling is fed, the owner's hunger drains 20% slower. Owner-only, cleared automatically when the pet gets too hungry or is abandoned — same pattern as the puppy/kitten buffs.
- Lamb storage is now **owner-only**: only the player who owns the Lamb can open its container. Ownership is matched by userid so it keeps working across reconnects. (If a Lamb somehow has no owner it stays openable rather than locking forever.)
- Items stored inside the Lamb now spoil **1.5x faster** (via a preserver component on the container).
- Peeper vision bonus is now a fixed standard value (+12 max zoom-out). The `Peeper Vision Bonus` mod-config option was removed; the config screen now only shows Debug Mode.

## Notes
- Debug Mode (`c_betterpet_status`) reports the Perdling's satiation and its "-hunger drain" state alongside the other pets.

---

## 1.6.0 - Legacy maintenance update

## Changed
- Reworked how every pet benefit is granted. All benefits now go to the pet's **owner only** and are active **only while the pet is fed**. Feed a pet to keep its benefit going. Proximity/radius no longer matters — if the pet is fed, the owner gets the benefit.
- Puppy: the 1.2x damage buff is no longer a fixed 1-day timer. It now applies to the owner while the puppy is satiated, and is removed automatically when the puppy gets too hungry.
- Kitten: the 1.2x speed buff works the same way — active on the owner while the kitten is satiated.
- Glomling: sanity aura is now owner-only and full strength regardless of distance (the distance falloff was removed). It is active while the Glomling is satiated.
- Friendly Peeper: vision (extra camera zoom-out) is now owner-only and active while the Peeper is satiated. When it activates, the camera automatically zooms out toward the new range.

## Fixed
- Friendly Peeper camera "jump": fixed the jarring camera-angle/height snap that happened when Peeper vision turned on or off. The mod no longer forces the camera distance directly; it only adjusts the maximum zoom-out limit and lets the game ease the camera smoothly. The support check was also moved to a stable satiation trigger instead of a fast proximity toggle, which removes the flip-flopping near the range edge.
- Stale buffs after abandoning a puppy/kitten are cleaned up immediately (the buff lives on the player, so an onremove handler now clears it when the pet is removed).

## Removed
- Pets no longer affect other players in any way. All "fed team support" / teammate-sharing has been removed (Glomling and Peeper no longer share their effect with nearby teammates).
- Removed the now-unused radius/duration config values and the associated fed-team bookkeeping (save/load persistence, feed hooks, timers).

## Light pets
- Dragonling and Mothling give **only** their themed light. This build has no temperature/warmth/cooling system, so there is nothing to disable — light pets are light-only by design. Themed lights and closer follow behavior are unchanged.

## Notes
- When Peeper vision turns on, the camera now automatically zooms out toward the newly unlocked range (about 70% of it, mirroring the Horizon Expandinator's behavior). This happens smoothly and only pushes the view outward — if you had already zoomed out further yourself, it leaves your view alone. When the Peeper gets too hungry, the extra range is removed and the camera smoothly eases back in.
- The camera effect still tries not to fight larger dedicated camera/zoom mods.
- Debug Mode (`c_betterpet_status`) now reports Peeper vision state, camera max distance, and each owned pet's hunger percent and fed state.

---

## 1.4.0 - Legacy maintenance update

## Added
- Added `Peeper Vision Bonus` mod configuration:
  - `Subtle` (+8 max camera distance)
  - `Default` (+12 max camera distance)
  - `Strong` (+16 max camera distance)
- Added client-side Friendly Peeper vision support.
- Added networked Peeper vision state so the server decides who is supported, while each client applies the camera effect locally.

## Changed
- Friendly Peeper has been reworked from sanity-aura protection into Horizon Expandinator-style vision utility.
- Friendly Peeper owner now receives increased maximum zoom-out whenever the pet is nearby.
- When Friendly Peeper is fed, nearby teammates also receive the same zoom-out support for 1 full day.
- Friendly Peeper no longer touches sanity, enlightenment, negative sanity auras, item dapperness, darkness, wetness, ghost drain, or external sanity modifiers.
- Debug Mode now reports Peeper vision state instead of Peeper sanity protection state.

## Kept
- Glomling still provides sanity aura to its owner while nearby.
- When Glomling is fed, nearby teammates still receive its sanity aura for 1 full day.
- Puppy, Kitten, Lamb, Dragonling, Mothling, lights, closer follow behavior, and debug helpers remain from previous maintenance updates.

## Notes
- The Peeper camera effect increases maximum zoom-out; the player may still need to scroll the camera outward to use the extra range.
- The camera effect tries not to fight larger dedicated camera/zoom mods. If another mod already gives a larger max zoom-out, Loyal Critters will avoid lowering it when Peeper support ends.
