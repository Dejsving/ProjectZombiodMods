AutoReloadXP — automatic leveling of the reloading skill.

Press F9 to enable or disable the mod. It selects a functional firearm with
maximum capacity from your inventory, including nested containers. For weapons
with removable magazines, a compatible magazine is required; for any weapon,
at least one separate appropriate ammunition is needed. Broken and jammed weapons
are not used.

The character repeatedly unloads and loads the selected magazine or weapon with
a built-in magazine. For a built-in magazine, the weapon is held in the main hand.
When extracting an installed magazine, the standard game action also requires
holding the weapon in hand. The extracted magazine remains in inventory. Ammunition
and items from nested containers may be moved to the main inventory.

For diagnostics, run AutoReloadDebug() in the game's Lua console. The selection
result and reasons for item exclusion are printed to the game log.

If suitable items are not found, the action is interrupted, or the item becomes
unavailable, the mod disables itself and reports the reason. When disabled by F9,
an already running game action is not cancelled.

To cancel the game action, press "Space" — this will cause an immediate reaction
from your character.

The common directory is required for the Project Zomboid Build 42 mod structure.
