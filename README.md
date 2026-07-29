# CraftFromChests

**Craft from your storage room. Stop playing inventory Tetris.**

Stand at a bench, pick a recipe, press **P** — every missing ingredient is pulled
out of the cupboards and crates around you automatically. Press **O** and
everything you're hauling goes back to the chest it came from.

And while a recipe is open, the ingredient counts tell you something the game
never has: **a yellow number means "you don't have it, but it's in a chest right
here."**

ICARUS has no built-in craft-from-storage. This mod adds it.

---

## Features

**P — Pull ingredients.** Reads the recipe you have selected (including the
craft quantity), works out exactly what you're short, and pulls precisely that
much from containers within range. Not whole stacks — the exact count.

**O — Send back.** Empties your pack into your storage, routing each item to a
chest that already holds that type. Tools, weapons, ammo, medicine, and armor
stay on you (fully configurable — see below).

**Live ingredient highlighting.** The bench's REQUIRED ELEMENTS tiles turn
**yellow** when you don't have an ingredient but a nearby chest does — one press
of **P** away. Tiles the game reddens are genuinely missing; nothing nearby has
them. It updates on its own, no keypress needed.

The ingredient numbers themselves are never recolored — the game draws those on
colored backgrounds and tinting them makes them unreadable. Highlighting appears
on the bench's own tiles; the larger hover tooltip is not currently highlighted.

**F7** — diagnostics (containers found, bench detected, recipe read).
**F8** — dry run: logs exactly what **P** would move, moves nothing.
**F10** — toggle the live color loop off/on.

Every action reports on screen — nothing fails silently.

---

## Install

1. **Install UE4SS** ([RE-UE4SS releases](https://github.com/UE4SS-RE/RE-UE4SS/releases))
   into `...\steamapps\common\Icarus\Icarus\Binaries\Win64\`.
   You should end up with `dwmapi.dll` and `UE4SS.dll` sitting next to
   `Icarus-Win64-Shipping.exe`.
2. **Copy the `CraftFromChests` folder** into
   `...\Icarus\Icarus\Binaries\Win64\Mods\`.
3. **Double-click `RUN ME FIRST.bat`.**
   It finds your Icarus install automatically and builds the recipe and
   item-protection data from your own game files. Takes a few seconds, and you
   only do it once (plus after each game update).
4. Launch the game. The highlight turns itself on — no keypress needed.

> **Re-run `RUN ME FIRST.bat` after every ICARUS update.** That's how the mod
> stays correct when RocketWerkz changes recipes — it reads *your* game's data
> rather than shipping a copy that goes stale.

**If Windows blocks the script** ("running scripts is disabled on this system"),
the .bat already works around it. If you'd rather run the .ps1 directly, either
right-click it → Properties → tick **Unblock**, or run from a PowerShell window:

```
powershell -ExecutionPolicy Bypass -File "generate-data.ps1"
```

**If the mod doesn't load** (no `[CraftFromChests] stub loaded` line in
`Binaries\Win64\UE4SS.log`), open `Binaries\Win64\Mods\mods.txt` and add this
line above the `; Built-in keybinds` comment:

```
CraftFromChests : 1
```

Newer UE4SS builds load any mod folder containing `enabled.txt` (included), but
some versions only read `mods.txt`.

### Uninstall

Delete the `CraftFromChests` folder. Nothing else is touched — this mod does not
modify game files or your saves.

---

## Configuration

Open `Scripts/cfc_logic.lua`:

| Setting | Default | Meaning |
|---|---|---|
| `RANGE` | `5000` | How far to search for containers (5000 ≈ 50m) |
| `BENCH_RANGE` | `700` | How close you must be to a bench (700 ≈ 7m) |

**Protecting extra items from send-back:** create `Scripts/keep_user.lua` —
it survives regenerating the data files.

```lua
return {
  add    = { "Refined_Metal", "Epoxy" },  -- never auto-store these
  remove = { "Stone_Arrow" },             -- do auto-store these
}
```

**Rebinding keys:** edit `Scripts/main.lua` (requires a game restart; every
other file hot-reloads on the next keypress).

---

## FAQ

**Is this safe for my save?**
It only moves items between containers you already own, using the game's own
transfer functions — the same ones a shift-click uses. It never writes to save
files. Single-player and hosted co-op only.

**Multiplayer?**
Works when you're the host. Not tested as a client on a dedicated server.

**Why a script instead of shipped data files?**
`generate-data.ps1` reads the recipe tables out of your own installed copy of
the game. That keeps game data out of this download, and means the mod survives
game patches instead of breaking on them.

**Nothing happens when I press P.**
Check the on-screen message. "No bench within 7m" means step closer; "no recipe
selected" means click a recipe first. For details, see
`Icarus\Icarus\Binaries\Win64\UE4SS.log`.

---

## Support

Free, and staying that way. If it saved you an hour of running between
cupboards, you're welcome to buy me a coffee — but the mod is the same either
way.

☕ **[ko-fi.com/icarusmodsbyj](https://ko-fi.com/icarusmodsbyj)**

Bug reports and log excerpts welcome on the mod page.

---

## License

MIT — see [LICENSE](LICENSE). Do what you like with the code.

Not affiliated with RocketWerkz. ICARUS is their game; this mod just reads it.
