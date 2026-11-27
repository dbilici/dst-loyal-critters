name = "Loyal Critters"
description = "Modernized loyal critter support for Don't Starve Together.\n\n"..
"Player stat support affects the OWNER ONLY while the relevant pet is fed. Bulbin reduces supported enemy detection distance for its owner. Lamb storage and themed light pets remain available independently of hunger.\n\n"..
"Changes:\n"..
"- Eets: 20% more positive sanity from food while fed.\n"..
"- Bulbin: Odor Masking prevents meat-triggered Bunnyman targeting while fed.\n"..
"- Bulbin: Repulsive Presence: 20% shorter detection distance for its owner while fed (supported hounds, spiders, bees, frogs and mosquitoes).\n"..
"- Supports vanilla critters and Pearl adoption.\n"..
"- Puppy: 1.2x damage buff to the owner while the puppy is fed.\n"..
"- Kitten: 1.2x speed buff to the owner while the kitten is fed.\n"..
"- Lamb: 2x2 mini chest storage; only the owner can open it, and items inside spoil 1.5x faster.\n"..
"- Perdling: owner's hunger drains 20% slower while it is fed (replaces the old redpouch drop).\n"..
"- Glomling: sanity aura to the owner while fed, at full strength regardless of distance.\n"..
"- Friendly Peeper: Horizon Expandinator-style vision support. Increases the owner's maximum zoom-out while the Peeper is fed. Fixed the jarring camera-angle jump.\n"..
"- Dragonling and Mothling give ONLY their themed light (no temperature effects). Light pets have shorter sleep distances.\n"..
"- Optional Walter support lets him adopt one critter alongside Woby. Disabled by default.\n"..
"- Player stat buffs are owner-only; nearby players may benefit indirectly from light.\n"..
"- Optional Debug Mode helps test owner support and Peeper vision state."
author = "k0za1ak"
version = "1.8.0-beta.2"
forumthread = ""
api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
all_clients_require_mod = true
icon_atlas = "modicon.xml"
icon = "modicon.tex"
server_filter_tags = {"pet", "critter", "support", "camera"}

configuration_options =
{
    {
        name = "allow_walter_critter",
        label = "Walter Can Adopt Critters",
        hover = "Allow Walter to adopt one critter while keeping Woby. Disabling blocks new adoptions but does not remove an existing critter.",
        options =
        {
            { description = "Disabled", data = false, hover = "Walter cannot adopt a new critter. An existing critter is not removed." },
            { description = "Enabled", data = true, hover = "Walter may adopt one critter alongside Woby." },
        },
        default = false,
    },
    {
        name = "betterpet_debug",
        label = "Debug Mode",
        hover = "Debug commands: c_lc(), c_lc_aggro(), c_lc_odor(), c_lc_watch(), c_lc_help().",
        options =
        {
            { description = "Off", data = "off", hover = "No automatic debug output; explicit commands still print to server log." },
            { description = "Log only", data = "log", hover = "Print Loyal Critters debug messages to the server log." },
            { description = "Chat + log", data = "announce", hover = "Print to log and show short in-game test messages." },
        },
        default = "off",
    },
}
