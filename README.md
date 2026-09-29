# Tech assessment place

A two-player Roblox collection prototype built on my existing roblox studio template

Per the task, the player gotta collect the 16 collectibles in Zone 1 together to open Zone 2, which contains another 4 collectibles

I'll start calling "collectibles" items from now on for clarity<br> ANyway

Items belong to the server session; when a player collects one item, it's unavailable to everyone else until a new server starts

## Playing

- Walk near an item to collect it automatically
- A new player has a lv 1 bag w/ capacity 5
- Walk on teh pad to empty the bag (each item pays 5 coins)
- Use 'Upgrade bag - 25' to buy an upgrade to level 2 and capacity 10
- Coins and bag level persist across rejoins (bag contents dont persist)
- If ur on a pc, hold Shift to sprint
- - On phones, use the joystick and the CAS RUN button on the right side
- The template's Shop, Settings, movement, death/respawn and dev tools remain available

The shared zone counter advances when items are collected, regardless of which player collects or deposits them <br>Bag contents survive a character respawn within the same session <br> Collected items never respawn during that session, including when the player leaves

## Running the project

Open the folder w/ the .rbxl file in explorer, drag it into any active Roblox Studio window and ur done

The place contains a map, UI, pickup models and sounds; this repository contains their scripts

Source folders mirror Roblox services btw

`StarterPlayerScripts` and `StarterCharacterScripts` go under `StarterPlayer`

I used Studio's Script Sync and Git (again, rojo wasnt used)

## Project structure

| Location | Responsibility |
| --- | --- |
| `ServerScriptService` | Server startup |
| `ServerStorage/Modules` | Services, player admission, persistence and authoritative gameplay |
| `ReplicatedStorage/Modules/Configs` | Gameplay, economy, UI and template tuning |
| `ReplicatedStorage/Modules/Gameplay` | Framework, shared types, rules and helpers |
| `ReplicatedStorage/Modules/Packets` | ByteNetMax network defs |
| `ReplicatedStorage/Modules/Imported` | Bundled libs and deps |
| `StarterPlayerScripts/ClientModules` | Input, interface and visual controllers |
| `ReplicatedFirst` | Loading screen |
| `StarterCharacterScripts` | Character presentation |

### Main assessment modules

- **PickupService** owns 20 collectible slots, claims and shared zone progress, opening the gate when the Zone 1 count reaches 16
- **BagService** owns each player's temporary bag count, detects entry into Deposit and handles upgrade requests
- **DataManager** owns access to the existing DataService/ProfileStore layer; deposits credit cash, while upgrades update cash and bag level tg
- **AssessmentConfig**, AssessmentTypes, BagRules and DataTemplate define tuning, shared contracts and persistent defaults
- **PickupController** sends proximity requests and preserves my template's coin flight path, sound and collection feedback
- **BagController** shows bag capacity, upgrade feedback and shared progress while CoinHudController displays saved coins and deposit gains
- **WorldGuiController** clones authored BillboardGui/SurfaceGui templates from `ReplicatedStorage.Assets.WorldGuiTemplates` into `PlayerGui.WorldGuis.Active`<br>
  Each template's `Adornee` links it to an instance<br>
  `WorldGuis` is a ScreenGui w/ `ResetOnSpawn = false`, inside playergui so it survives respawn<br>
  BagController updates the gate sign from shared zone state

## Player data

This place uses the existing profile store, `PlayerData_v1`

| Field | Default | Meaning |
| --- | --- | --- |
| `cash` | `0` | Saved coins |
| `bagLevel` | `1` | Saved upgrade level, capacity is derived as 5 or 10 |

## Networking and validation

ByteNetMax creates a query named `Pickup.Collect` that carries only a collectible ID, a `Bag.Upgrade` query with no client-supplied price or level, and a server-to-client collection event for fx

The server checks player admission, whether an item exists, prior claims, zone access, if hes alive, distance, line of sight and available bag space<br>
Requests are rate limited

Deposit value comes from the server's bag count and position check<br>
Upgrade price and resulting capacity come from server configuration<br>
The current level and balance are checked before both saved fields are changed

To demonstrate an invalid client request, run this in the **client** Command Bar while standing at spawn (assuming you've never played before):

```lua
local query = require(game.ReplicatedStorage.Modules.Packets.PickupPackets).queries.Collect
print(query.invoke(16))
```

The result is `range`, w/ no change to the bag or shared progress<br>
Other rejection results include `claimed`, `locked`, `full`, `missing` and `busy`

## Deps and template reuse

This place reuses my template's service/controller Framework, DataService w/ ProfileStore, ByteNetMax, Promise, Signal, Timer, Sift and Scythe

DataManager manages profile; Scythe manages cleanup

Existing UI helpers and other bundled packages support retained template features, and no second profile owner or replacement network framework was introduced

## Tools and time

Studio Script Sync, Git, Roblox Studio and Claude code were used

Claude assisted with strict typing and test automation<br>

Approximate assessment time so far: 5-6 hours, including prep, implementation, video recording, README.md, validation and polish

### P.S.

Roblox's bundled PlayerModule camera/control scripts still use deprecated raycast APIs

I'm leaving that Roblox code as-is to avoid introducing unnecessary bugs into camera and movement behavior just to clear those warnings
