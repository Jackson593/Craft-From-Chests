# ============================================================================
# CraftFromChests - data generator
# ============================================================================
# Builds Scripts\recipes.lua and Scripts\keep.lua from YOUR OWN Icarus install's
# data.pak. No game data ships with this mod - this script reads the tables from
# the copy of the game you already own, so the mod stays current with every
# game update. Re-run after any Icarus patch.
#
# Usage:  right-click > Run with PowerShell     (auto-detects your Icarus install)
#         or:  .\generate-data.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Icarus"
#
# Your own edits belong in Scripts\keep_user.lua (never overwritten):
#   return { add = { "Some_Item" }, remove = { "Other_Item" } }
# ============================================================================
param(
    [string]$GamePath = ""
)

$ErrorActionPreference = "Stop"

function Find-IcarusInstall {
    $candidates = @()
    # Steam registry -> libraryfolders.vdf
    try {
        $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction Stop).SteamPath
        if ($steam) {
            $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
            if (Test-Path $vdf) {
                [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"') | ForEach-Object {
                    $candidates += ($_.Groups[1].Value -replace '\\\\', '\')
                }
            }
            $candidates += $steam
        }
    } catch {}
    # common fallbacks
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $candidates += "$($_.Name):\SteamLibrary"
        $candidates += "$($_.Name):\Program Files (x86)\Steam"
    }
    foreach ($c in $candidates) {
        $probe = Join-Path $c "steamapps\common\Icarus"
        if (Test-Path (Join-Path $probe "Icarus\Content\Data\data.pak")) { return $probe }
    }
    return $null
}

if (-not $GamePath) { $GamePath = Find-IcarusInstall }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath "Icarus\Content\Data\data.pak"))) {
    Write-Host "Could not find your Icarus install." -ForegroundColor Red
    Write-Host "Run again with:  .\generate-data.ps1 -GamePath `"<path to ...\steamapps\common\Icarus>`""
    exit 1
}
$pakPath = Join-Path $GamePath "Icarus\Content\Data\data.pak"
$scriptsDir = Join-Path $PSScriptRoot "Scripts"
if (-not (Test-Path $scriptsDir)) { New-Item -ItemType Directory -Force $scriptsDir | Out-Null }
Write-Host "data.pak : $pakPath"
Write-Host "output   : $scriptsDir"

# --- zlib sweep + table split (C# for speed) --------------------------------
if (-not ([System.Management.Automation.PSTypeName]'CfcPak').Type) {
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.IO.Compression;

public class CfcPak
{
    // Inflate every zlib stream (78 01/5E/9C/DA) whose output is mostly printable
    // text (rejects false positives found inside compressed data), in pak order.
    public static byte[] InflateAll(byte[] pak)
    {
        using (var outMs = new MemoryStream())
        {
            long i = 0;
            while (i < pak.Length - 2)
            {
                if (pak[i] == 0x78 && (pak[i+1] == 0x9C || pak[i+1] == 0xDA || pak[i+1] == 0x01 || pak[i+1] == 0x5E))
                {
                    byte[] b = TryInflate(pak, (int)i);
                    if (b != null && b.Length >= 64 && IsMostlyText(b))
                    {
                        outMs.Write(b, 0, b.Length);
                        i += 2;
                        continue;
                    }
                }
                i++;
            }
            return outMs.ToArray();
        }
    }

    static bool IsMostlyText(byte[] b)
    {
        int sample = Math.Min(b.Length, 4096);
        int printable = 0;
        for (int k = 0; k < sample; k++)
        {
            byte c = b[k];
            if ((c >= 0x20 && c < 0x7F) || c == 0x09 || c == 0x0A || c == 0x0D) printable++;
        }
        return printable >= sample * 97 / 100;
    }

    static byte[] TryInflate(byte[] pak, int offset)
    {
        try
        {
            using (var ms = new MemoryStream(pak, offset + 2, pak.Length - offset - 2))
            using (var ds = new DeflateStream(ms, CompressionMode.Decompress))
            using (var o = new MemoryStream())
            {
                byte[] buf = new byte[65536];
                int total = 0, n;
                while ((n = ds.Read(buf, 0, buf.Length)) > 0)
                {
                    o.Write(buf, 0, n);
                    total += n;
                    if (total > 70 * 1024 * 1024) return null;
                }
                return o.ToArray();
            }
        }
        catch { return null; }
    }

    // Balanced root-object substring starting at 'start' (tables may have trailing garbage)
    public static string BalancedJson(string text, int start)
    {
        int depth = 0; bool inStr = false, esc = false;
        for (int i = start; i < text.Length; i++)
        {
            char c = text[i];
            if (esc) { esc = false; continue; }
            if (inStr)
            {
                if (c == '\\') esc = true;
                else if (c == '"') inStr = false;
                continue;
            }
            if (c == '"') inStr = true;
            else if (c == '{') depth++;
            else if (c == '}') { depth--; if (depth == 0) return text.Substring(start, i - start + 1); }
        }
        return text.Substring(start);
    }
}
"@
}

Write-Host "scanning data.pak..."
$all = [CfcPak]::InflateAll([System.IO.File]::ReadAllBytes($pakPath))
$text = [System.Text.Encoding]::UTF8.GetString($all)
$all = $null
Write-Host ("recovered {0:n0} chars of table data" -f $text.Length)

# find the LARGEST table of each struct we need (pak can contain small stub tables)
function Get-LargestTable([string]$structName) {
    $best = $null
    foreach ($m in [regex]::Matches($text, '\{\s*"RowStruct":\s*"/Script/Icarus\.' + $structName + '"')) {
        $json = [CfcPak]::BalancedJson($text, $m.Index)
        if (-not $best -or $json.Length -gt $best.Length) { $best = $json }
    }
    return $best
}

$recJson = Get-LargestTable "ProcessorRecipe"
$itemJson = Get-LargestTable "ItemStaticData"
if (-not $recJson -or -not $itemJson) {
    Write-Host "Could not locate ProcessorRecipe / ItemStaticData tables in data.pak - game format may have changed. Please report this on the mod page." -ForegroundColor Red
    exit 1
}

Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = [int]::MaxValue
$ser.RecursionLimit = 200

# --- recipes.lua -------------------------------------------------------------
Write-Host "parsing recipes..."
$recRows = ($ser.DeserializeObject($recJson))["Rows"]
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- GENERATED from your game's D_ProcessorRecipe by generate-data.ps1 - do not edit.")
[void]$sb.AppendLine("-- Re-run generate-data.ps1 after every Icarus update.")
[void]$sb.AppendLine("local R = {}")
$nRec = 0
foreach ($row in $recRows) {
    $name = $row["Name"]
    if (-not $name) { continue }
    $ins = @()
    if ($row.ContainsKey("Inputs")) {
        foreach ($inp in $row["Inputs"]) {
            $el = $inp["Element"]
            if (-not $el) { continue }
            $rn = $el["RowName"]
            if (-not $rn -or $rn -eq "None") { continue }
            $cnt = 1
            if ($inp.ContainsKey("Count")) { $cnt = [int]$inp["Count"] }
            if ($cnt -lt 1) { continue }
            $ins += ('{{"{0}",{1}}}' -f $rn, $cnt)
        }
    }
    $out = $name
    if ($row.ContainsKey("Outputs")) {
        foreach ($o in $row["Outputs"]) {
            $el = $o["Element"]
            if ($el -and $el["RowName"] -and $el["RowName"] -ne "None") { $out = $el["RowName"]; break }
        }
    }
    [void]$sb.AppendLine(('R["{0}"]={{out="{1}",ins={{{2}}}}}' -f $name, $out, ($ins -join ",")))
    $nRec++
}
[void]$sb.AppendLine("return R")
[System.IO.File]::WriteAllText((Join-Path $scriptsDir "recipes.lua"), $sb.ToString())
Write-Host "recipes.lua : $nRec recipes"

# --- keep.lua ----------------------------------------------------------------
# Items send-back should never auto-store, derived from the game's own tags:
#   Item.Tool.* / Item.Weapon.* / Item.Ammo.* / Item.Medicine.* / Item.Equip.*
#   Item.Consumable.* (food, drink - you want these ON you, not in a cupboard)
#   Item.Meta.* (workshop packages, seeds, repair kits)
#   + Traits.Equippable (armor, carryable carcasses) + Armour trait rows
#   + anything named Mission_*/Faction_Mission_* (quest items carry no tags at all).
# Raw crafting resources ARE stored - that's the whole point of the O key.
Write-Host "parsing items..."
$itemRows = ($ser.DeserializeObject($itemJson))["Rows"]
$keepNames = New-Object System.Collections.Generic.List[string]
foreach ($row in $itemRows) {
    $name = $row["Name"]
    if (-not $name) { continue }
    # Mission/quest items carry NO gameplay tags at all, so they can only be caught by
    # name. Auto-storing one could break an active mission - always keep them.
    $isKeep = $row.ContainsKey("Armour") -or ($name -match '^(Mission_|Faction_Mission_)')
    if (-not $isKeep) {
        foreach ($tagBlock in @("Generated_Tags", "Manual_Tags")) {
            if ($isKeep) { break }
            $gt = $row[$tagBlock]
            if ($gt -and $gt["GameplayTags"]) {
                foreach ($t in $gt["GameplayTags"]) {
                    $tn = $t["TagName"]
                    if ($tn -and ($tn -match '^Item\.(Tool|Weapon|Ammo|Medicine|Equip|Consumable|Meta)\.' -or $tn -eq 'Traits.Equippable')) {
                        $isKeep = $true; break
                    }
                }
            }
        }
    }
    # Resource wins. Some crafting materials double as weapons - a Stick is
    # Item.Tool.Thrown, nails are Item.Ammo.Nail - and without this they'd be
    # protected from send-back and pile up in your pack forever.
    if ($isKeep -and -not $row.ContainsKey("Armour") -and ($name -notmatch '^(Mission_|Faction_Mission_)')) {
        foreach ($tagBlock in @("Generated_Tags", "Manual_Tags")) {
            $gt = $row[$tagBlock]
            if ($gt -and $gt["GameplayTags"]) {
                foreach ($t in $gt["GameplayTags"]) {
                    if ($t["TagName"] -match '^Item\.Resource(\.|$)') { $isKeep = $false; break }
                }
            }
            if (-not $isKeep) { break }
        }
    }

    if ($isKeep) { $keepNames.Add($name) }
}
$sb2 = New-Object System.Text.StringBuilder
[void]$sb2.AppendLine("-- GENERATED from your game's D_ItemsStatic by generate-data.ps1 - do not edit.")
[void]$sb2.AppendLine("-- Items send-back (O key) never auto-stores: tools, weapons, ammo, meds, armor, equipment.")
[void]$sb2.AppendLine("-- To customize, create Scripts\keep_user.lua:  return { add={`"X`"}, remove={`"Y`"} }")
[void]$sb2.AppendLine("return {")
foreach ($n in ($keepNames | Sort-Object)) { [void]$sb2.AppendLine(('  ["{0}"]=true,' -f $n)) }
[void]$sb2.AppendLine("}")
[System.IO.File]::WriteAllText((Join-Path $scriptsDir "keep.lua"), $sb2.ToString())
Write-Host "keep.lua    : $($keepNames.Count) protected items"
Write-Host ""
Write-Host "Done. Launch Icarus and craft from your chests." -ForegroundColor Green
