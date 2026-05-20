# Example — Inventory (item_container)

Largest module. Exposes 10 sub-services under `SaiServer`:

| Accessor | Class | Purpose |
|----------|-------|---------|
| `SaiServer.inventory` | `PlayerContainer` | Containers + their items, gacha pack open. |
| `SaiServer.player_item` (alias `item`) | `PlayerItem` | List items, update properties, move/swap. |
| `SaiServer.item_add_deduct` | `ItemAddDeduct` | Grant or remove item stacks. |
| `SaiServer.gacha` | `GachaPack` | Open gacha packs by definition id or code. |
| `SaiServer.equipment_slot` | `EquipmentSlot` | Equip / unequip items, list slots. |
| `SaiServer.item_crafting` | `ItemCrafting` | Craft via recipes, list history. |
| `SaiServer.item_preset` | `ItemPreset` | Loadout presets. |
| `SaiServer.item_tag` | `ItemTag` | Tag lookup, items-by-tag. |
| `SaiServer.item_generator` | `ItemGenerator` | Yield generators (drip-feed items). |

> `SaiServer.inventory` is an alias of `SaiServer.player_container`. They are the same node.

## Containers + items

```gdscript
# List the player's containers.
var c_result := await SaiServer.inventory.get_containers(50, 0)
if c_result.success:
    for container in c_result.data.containers:
        print("%s (%s)" % [container.id, container.container_type])

# Fetch items inside one container.
var i_result := await SaiServer.inventory.get_items(container_id, 50, 0)
if i_result.success:
    for item in i_result.data.items:
        print("%s x%d" % [item.id, item.quantity])
```

## Whole-inventory listing (cross-container)

```gdscript
var result := await SaiServer.player_item.get_items(50, 0, "")  # limit, offset, category
if result.success:
    for item in result.data.items:
        print(item.id, item.quantity)
```

## Add / deduct items

```gdscript
# Grant 5 of an item definition (defaults to player's main container).
await SaiServer.item_add_deduct.add("def_potion_hp", 5)

# Deduct 1.
await SaiServer.item_add_deduct.deduct("def_potion_hp", 1)

SaiServer.item_add_deduct.add_deduct_success.connect(func(data): print("Delta: ", data))
```

## Move / swap

```gdscript
# Move 3 of `item_id` into `target_container_id`, placed at grid (x, y).
await SaiServer.player_item.move_item(item_id, target_container_id, 3, 0, 0)

# Swap two inventory items by id.
await SaiServer.player_item.swap_items(item_a_id, item_b_id)
```

## Equip / unequip

```gdscript
# Equip `item_id` into the named slot (e.g. `"weapon"`).
await SaiServer.equipment_slot.equip_item(item_id, "weapon")

# Unequip the item by inventory id.
await SaiServer.equipment_slot.unequip_item(item_id)

# List equipped items.
var eq := await SaiServer.equipment_slot.get_equipped()
```

## Craft

```gdscript
SaiServer.item_crafting.craft_success.connect(func(response):
    for out in response.outputs:
        print("Crafted: %s x%d" % [out.item_def_id, out.quantity])
)
await SaiServer.item_crafting.craft(recipe_id)
# OR: await SaiServer.item_crafting.craft_by_key("recipe_iron_sword")
```

## Gacha

```gdscript
# Open a gacha pack by definition id, depositing rewards into `container_id`.
var result := await SaiServer.gacha.open_by_id(gacha_pack_def_id, container_id)
if result.success:
    for granted in result.data.granted_items:
        print("Got: %s x%d" % [granted.item_def_id, granted.quantity])

# Alternative entry point if you only have a redemption code.
await SaiServer.gacha.open_by_code("CODE-1234", container_id)
```

## Tags

```gdscript
var tagged := await SaiServer.item_tag.get_items_by_tag("equipment")
if tagged.success:
    for item in tagged.data.items:
        print(item.id)
```

## Presets

```gdscript
# Create a loadout preset from a definition id.
await SaiServer.item_preset.create_by_definition_id("preset_def_loadout", "Main Loadout")

# Add an inventory item into slot 0 of a preset.
await SaiServer.item_preset.add_item_to_preset(preset_id, 0, inventory_item_id)

# Local lookup.
var preset := SaiServer.item_preset.get_preset_by_id(preset_id)
```

## Generators

```gdscript
# Inspect what a yield generator owes the player.
var status := await SaiServer.item_generator.check_generator(inventory_item_id)

# Collect pending yield.
var grant := await SaiServer.item_generator.collect_generator(inventory_item_id)
if grant.success:
    print("Yield: ", grant.data)
```
