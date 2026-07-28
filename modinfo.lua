name = "Loyal Critters"
description = "Modernized loyal critter support for Don't Starve Together.\n\n"..
"Pet support affects the OWNER ONLY. Puppy, Kitten, Perdling, Glomling, and Friendly Peeper support stays active while that pet is fed; distance no longer matters. Lamb storage and themed light pets remain available independently of hunger.\n\n"..
"Changes:\n"..
"- Added Mothling and Friendly Peeper support.\n"..
"- Puppy: 1.2x damage buff to the owner while the puppy is fed.\n"..
"- Kitten: 1.2x speed buff to the owner while the kitten is fed.\n"..
"- Lamb: 2x2 mini chest storage; only the owner can open it, and items inside spoil 1.5x faster.\n"..
"- Perdling: owner's hunger drains 20% slower while it is fed (replaces the old redpouch drop).\n"..
"- Glomling: sanity aura to the owner while fed, at full strength regardless of distance.\n"..
"- Friendly Peeper: Horizon Expandinator-style vision support. Increases the owner's maximum zoom-out while the Peeper is fed. Fixed the jarring camera-angle jump.\n"..
"- Dragonling and Mothling give ONLY their themed light (no temperature effects). Light pets follow closer so their light is useful.\n"..
"- Optional Walter support lets him adopt one critter alongside Woby. Disabled by default.\n"..
"- Pets no longer affect other players in any way. Teammate/fed-team support has been removed.\n"..
"- Optional Debug Mode helps test owner support and Peeper vision state."
author = "k0za1ak"
version = "1.7.4"
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
        hover = "Testing helper for Loyal Critters. Shows owner support and Peeper vision state changes.",
        options =
        {
            { description = "Off", data = "off", hover = "No debug output." },
            { description = "Log only", data = "log", hover = "Print Loyal Critters debug messages to the server log." },
            { description = "Chat + log", data = "announce", hover = "Print to log and show short in-game test messages." },
        },
        default = "off",
    },
}
