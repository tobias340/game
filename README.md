# Steal a Robot

A Roblox "Steal a ___" game. Buy robots from the conveyor, let them earn cash in your base, and steal
better ones from other players' bases before they bonk you with a wrench.

## How to play

- **Buy:** robots ride the conveyor down the middle of the map. Hold **E** on one to buy it, and it goes
  straight onto a free pedestal in your base.
- **Earn:** every robot earns cash per second. The cash piles up on the green pad in front of its
  pedestal, so step on the pad to collect it.
- **Steal:** walk into another base and hold **E** on a robot. You carry it over your head (slower than
  normal), and it's yours once you're back inside your own base.
- **Defend:** you spawn with a **Wrench**. Bonk a thief and they drop your robot, which goes straight
  back onto its pedestal. Step on the red **Lock** button and your base is sealed for 60 seconds: other
  players get pushed out, and a thief still inside drops what they're carrying.
- **Sell:** hold **E** on one of your own robots to sell it for half its price and make room.

Rarer robots (Common, Uncommon, Rare, Epic, Legendary, Mythic) are bigger, glow more and earn a lot
more. The server announces Legendary and Mythic robots when they spawn on the conveyor.

## Setup (Rojo)

The game code lives in this repo and syncs into Roblox Studio with [Rojo](https://rojo.space).

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run:
   ```sh
   rokit install            # installs rojo, selene and stylua at the pinned versions
   rojo plugin install      # installs the matching Rojo plugin into Studio
   ```
2. Build a place file and open it in Studio:
   ```sh
   rojo build default.project.json -o StealARobot.rbxl
   ```
3. Start the live sync and click **Connect** in the Rojo plugin inside Studio:
   ```sh
   rojo serve
   ```
4. Press **Play**. The map is built by code when the server starts, so it only shows up in play mode.

To test stealing you need two players. In Studio, use **Test → Clients and Servers → 2 Players → Start**.

### Saving in Studio

Progress saves with DataStores. To test saving in Studio, publish the place, then turn on **Game
Settings → Security → Enable Studio Access to API Services**. Without that, the game still runs but
shows "Saving is off" and starts everyone fresh.

### Before publishing

Set the server's max players to **8** (one per base). Any extra players won't get a base.

## Project layout

```
src/
  shared/              ReplicatedStorage.Shared (used by server and client)
    Config.luau        all the tunable numbers: prices, speeds, timers
    Robots.luau        the robot catalog and rarity weights
    Format.luau        "$1.5K"-style number formatting
  server/              ServerScriptService.Server
    init.server.luau   entry point: starts services, handles join/leave in order
    Map.luau           builds the ground, the conveyor lane and the 8 bases
    PlotService.luau   base ownership, pedestals, income, collecting, selling, locking
    ConveyorService.luau  spawns robots on the conveyor and handles buying
    StealService.luau  grabbing, carrying, delivering and dropping robots
    Combat.luau        the wrench and its knockback
    DataService.luau   loading/saving cash and robots, the Cash leaderstat
    RobotModel.luau    builds robot models out of parts
  client/              StarterPlayerScripts.Client
    Hud.luau           cash counter and toast messages
    PromptFilter.luau  shows Steal prompts to thieves and Sell prompts to owners
    Knockback.luau     applies wrench knockback to your own character
```

## Changing the game

- **Balance:** edit `src/shared/Config.luau` (spawn rate, lock time, carry speed, starting cash).
- **New robots:** add a line to `Robots.List` in `src/shared/Robots.luau`. Never rename an `Id` that
  has already shipped, because that id is what's stored in player saves.

## Code checks

```sh
stylua src               # format
selene src               # lint
```
