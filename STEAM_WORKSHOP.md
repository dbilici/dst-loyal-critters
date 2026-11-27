# Steam Workshop Page

## Title

Loyal Critters

## Description

[h1]Loyal Critters[/h1]

Modernized critter benefits that belong only to each pet's owner. Fed-gated
player stat support depends on satiation; Bulbin's support is owner-specific.

[h2]Critter benefits[/h2]

[list]
[*][b]Puppy:[/b] 1.2x damage for its owner while fed.
[*][b]Kitten:[/b] 1.2x movement speed for its owner while fed.
[*][b]Perdling:[/b] 20% slower hunger drain for its owner while fed.
[*][b]Glomling:[/b] owner-only sanity aura at full strength while fed, regardless of distance.
[*][b]Friendly Peeper:[/b] +12 maximum camera zoom-out for its owner while fed, with smooth camera transitions.
[*][b]Lamb:[/b] owner-only 2 x 2 mini chest. Stored food spoils 1.5x faster. Storage is not hunger-gated.
[*][b]Dragonling and Mothling:[/b] themed light only, with closer following so the light stays useful. Light is not hunger-gated.
[*][b]Eets:[/b] 20% more positive food sanity for its owner while fed.
[*][b]Bulbin:[/b] Repulsive Presence: 20% shorter detection distance for its owner while fed (supported hounds, spiders, bees, frogs and mosquitoes). Odor Masking also prevents meat-triggered Bunnyman targeting; other hostility and retaliation remain unchanged.
[/list]

Player stat benefits are owner-only. Light can help nearby players indirectly.

[h2]Configuration and diagnostics[/h2]

Walter normally cannot adopt critters because Woby is his exclusive companion.
[b]Walter Can Adopt Critters[/b] defaults to [b]Disabled[/b]. Enable it to let
Walter adopt one regular critter alongside Woby. Disabling the option prevents
new adoptions but does not remove a critter Walter already owns.

Debug Mode defaults to [b]Off[/b] and can use [b]Log only[/b] or
[b]Chat + log[/b]. Run [code]c_loyalcritters_status()[/code] in the console to
report owned pets, fullness and benefit status. Use [code]c_lc_help()[/code] for additional diagnostics.

The server and every joining player must install and enable the same version.

[h2]Credits[/h2]

Based on [url=https://steamcommunity.com/sharedfiles/filedetails/?id=849986686]Better pet[/url] by [b]宵征[/b]. This project originated from that work; the current architecture extends vanilla critters.

The original item was last updated in 2017 and is no longer compatible with the current DST critter roster. This modernization is maintained by [b]k0za1ak[/b] under [url=https://support.klei.com/hc/en-us/articles/360029557172-I-am-Interested-in-Modding-Don-t-Starve]Klei's abandoned-mod guidance[/url], with owner-only benefit rules, current critter support, revised balance, and diagnostics. If the original author requests removal or different attribution, this item will be updated or removed.

Version: 1.8.0-rc.1 (draft, not published)

Source code and bug reports:
https://github.com/dbilici/dst-loyal-critters

## Change notes

[h1]1.8.0-rc.1 (draft)[/h1]

[list]
[*]Vanilla prefab compatibility, Bulbin and Eets support.
[*]Pearl adoption and owner-only benefits.
[*]Bulbin: Repulsive Presence and Odor Masking.
[*]Eets: positive food sanity bonus.
[*]Concise in-game diagnostics and camera, light and inventory maintenance.
[/list]

