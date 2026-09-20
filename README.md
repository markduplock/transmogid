# Transmog ID

Transmog ID adds a small wardrobe icon to the default target frame when a
targeted player has a transmogrified appearance or weapon illusion.

It is made for WoW Forever beta and uses the game's inspection data. The icon
disappears when you target another unit, an NPC, or a player whose appearance
cannot be inspected.

## Installation

1. Download or copy this project folder.
2. Rename the folder to `TransmogID` if it is not already named that.
3. Place it in your WoW Forever AddOns directory:

   `World of Warcraft/_classic_beta_/Interface/AddOns/TransmogID`

4. Start the game and enable **Transmog ID** in the AddOns list on the
   character-selection screen.

## How to use it

Target a nearby player. If their displayed equipment includes a transmogged
appearance or weapon illusion, the wardrobe icon appears in the upper-right
area of the standard target frame.

For testing, the icon always appears when you target yourself.

Use `/tmid` to open the position menu. The horizontal slider controls the
icon's X position from `-200` to `0`; select **Save position** to store the
current value and close the menu.
Note that this setting is not currently working due to the client not reading the SavedVariables: https://us.forums.blizzard.com/en/wow/t/uiaddon-settings-wiped-on-client-restart/2353992

## What the icon means

The icon means the inspected appearance does not match at least one item the
player has equipped, or that a weapon illusion is present.

It does **not** reveal the state of WoW Forever's personal “show transmogs”
toggle. That setting is not exposed to addons. A player with the toggle enabled
but no altered appearances will not show the icon.

## Troubleshooting

- **No icon for a player:** move closer and target them again. The game only
  supplies inspection data for eligible players in range.
- **Addon is marked out of date:** enable **Load out of date AddOns**. This is
  expected while WoW Forever is in beta.
- **No addon in the list:** check that `TransmogID.toc` is directly inside the
  `TransmogID` folder, alongside `transmogid.lua` and the `media` folder.
