# Patch: Project RV Interior — fix exit action doing nothing (MP)

Workshop ID: `3543229299`  
File patched (in Docker volume, not git-tracked):  
`/project-zomboid/steamapps/workshop/content/108600/3543229299/mods/modprojectrvinterior/42/media/lua/server/rvservermp_v3.lua`

## Root causes fixed in `RVServer.GetOutFromRV`

1. **String/number key mismatch after ModData deserialisation** — PZ's Java layer can
   convert string keys that look like numbers (e.g. `"12345678"`) to integer keys when
   writing/reading from SQLite. The original code did a plain `modData.Players[playerId]`
   lookup with no fallback, so after a server restart the key was never found and the
   function silently returned early.  
   Fix: lookup with both `[tostring(id)]` and `[tonumber(id)]`.

2. **No fallback when ModData is empty** — if either `modData.Players[playerId]` or
   `modData.Vehicles[vehicleId]` was nil, the function returned without teleporting the
   player back. The player was permanently stuck inside the interior.  
   Fix: added `doFallbackExit()` that uses `pmd.beforeEnter` (position stored at entry
   time, always on the player object) to teleport back in all failure paths.

3. **Vehicle not found in stored data but loaded in world** — even if `modData.Vehicles`
   doesn't have the entry, the vehicle might still be in the loaded cell. A scan over
   `cell:getVehicles()` matching `projectRV_uniqueId` is now tried before giving up.

4. **Player state not cleared on exit** — `pmd.projectRV_playerId` and `pmd.beforeEnter`
   were never cleared, which could cause stale state on re-entry. Both are now nilled
   after a successful teleport.

## Re-applying after mod update

If the workshop mod auto-updates and overwrites the file, re-apply this patch by:
1. Starting from the current `rvservermp_v3.lua` in the volume
2. Replacing the `function RVServer.GetOutFromRV(player) ... end` block
   with the version described in this file (or re-running the Claude session that
   created this patch — see git log for reference).
