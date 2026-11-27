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
- Published Workshop version: `1.8.0` (confirmed by maintainer)
- GitHub release: `v1.8.0` tag and release pending
- Manual validation: Bulbin, Eets, Lamb, debug commands and Pearl adoption/save-load reported successful; final two-player isolation and reconnect tests pending.

## Features

- Owner-only player stat benefits; nearby players can benefit indirectly from light.
- Eets: +20% positive food sanity while fed.
- Bulbin: Repulsive Presence: 20% shorter detection distance for its owner while fed (supported hounds, spiders, bees, frogs and mosquitoes).
- Bulbin: Odor Masking prevents meat-triggered Bunnyman targeting while fed; other hostility and retaliation remain unchanged.
- Vanilla prefab/skin handling and Pearl adoption compatibility.
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
- Optional Walter support lets him adopt one critter alongside Woby.
- Debug Mode helps test owner support and Peeper vision state.

## Configuration

| Option | Values | Default |
| --- | --- | --- |
| Walter Can Adopt Critters | Disabled, Enabled | Disabled |
| Debug Mode | Off, Log only, Chat + log | Off |

Enabling Walter support raises his regular critter capacity from zero to one.
Woby is managed separately and remains available. If another mod already grants
Walter a larger pet capacity, Loyal Critters does not reduce it. Disabling the
option prevents new adoptions but does not remove a critter Walter already owns.

## Diagnostics

Use Remote console commands. Log only writes diagnostics to the server log; Chat + log also shows concise in-game messages. Explicit commands print even when automatic debug is off.

| Command | Purpose |
| --- | --- |
| `c_lc()` | Owned pets, fullness and benefit status |
| `c_lc_watch()` | Start/reset real target-search sampling |
| `c_lc_aggro()` | Current Bulbin state and last eligible search |
| `c_lc_odor()` | Current masking state and last Bunnyman search |
| `c_lc_watch(false)` | Stop sampling |
| `c_lc_help()` | Command help |

Old status and aggro command aliases remain available. Samples are historical; reset the watch between test cases.

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

