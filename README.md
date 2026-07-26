# Loyal Critters

Public Don't Starve Together mod that modernizes critter benefits so they apply only to each pet's owner while the pet is fed.

## Status

- Steam Workshop visibility: Public
- Workshop ID: `3747661184`
- Workshop URL: https://steamcommunity.com/sharedfiles/filedetails/?id=3747661184
- Steam title: `Loyal Critters`
- Local source package: `Better_Pet`
- Mod name: `Loyal Critters`
- Author: `k0za1ak`
- Original author credit: `宵征`
- Original Workshop item: https://steamcommunity.com/sharedfiles/filedetails/?id=849986686
- Source repository: https://github.com/dbilici/dst-loyal-critters
- Repository folder: `dst-loyal-critters`
- Version: `1.7.2`

## Features

- Owner-only pet benefits; pets no longer buff nearby teammates.
- Puppy, Kitten, Perdling, Glomling, and Friendly Peeper support stays active
  only while the corresponding pet is fed.
- Puppy gives owner damage support.
- Kitten gives owner speed support.
- Lamb provides owner-only 2x2 storage with faster spoilage.
- Perdling slows the owner's hunger drain while fed.
- Glomling provides owner-only sanity aura.
- Friendly Peeper increases the owner's max camera zoom-out while fed.
- Dragonling and Mothling provide themed light only; light is not hunger-gated.
- Lamb storage remains available independently of hunger.
- Debug Mode helps test owner support and Peeper vision state.

## Configuration

| Option | Values | Default |
| --- | --- | --- |
| Debug Mode | Off, Log only, Chat + log | Off |

## Diagnostics

Use `Log only` during normal troubleshooting and `Chat + log` for a short live
test. The following console command prints the selected player's Peeper state,
camera limit, owned pets, hunger percentages, fed state, and active benefits:

```text
c_loyalcritters_status()
```

## Install Locally

Copy this folder into the Don't Starve Together mods folder, then enable it from the in-game mod screen.

Common macOS location:

```text
~/Library/Application Support/Steam/steamapps/common/Don't Starve Together/dontstarve_steam.app/Contents/mods/
```

## Repository Notes

- Keep generated or OS-local files out of Git (`.DS_Store`, logs, temporary zips).
- Keep Workshop metadata in this README.
- Keep the Steam Workshop page text in `STEAM_WORKSHOP.md`.
- Tag GitHub releases when publishing Workshop updates.
