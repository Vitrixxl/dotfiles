#!/usr/bin/env lua
-- Génère hyprland.conf à partir de hyprland.lua.
-- Usage : lua ~/.config/hypr/build.lua  (puis hyprctl reload)

local here = arg[0]:match("^(.*)/[^/]*$") or "."
local out, depth = {}, 0
local WIDTH = 79

local function fmt(v)
    if type(v) == "boolean" then return tostring(v) end
    if type(v) == "number" and v % 1 == 0 then return string.format("%d", v) end
    return tostring(v)
end

local function push(line)
    out[#out + 1] = (line == "") and "" or (string.rep("    ", depth) .. line)
end

-- Colle les arguments non-nil en « a, b, c ».
local function join(...)
    local parts, n = {}, select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        if v ~= nil then parts[#parts + 1] = fmt(v) end
    end
    return table.concat(parts, ", ")
end

local dsl = {}

function dsl.blank() push("") end
function dsl.raw(line) push(line) end
function dsl.comment(text) push("# " .. text) end

-- « # ── Titre ─────────… » aligné sur WIDTH colonnes.
function dsl.header(title)
    local prefix = "# ── " .. title .. " "
    local pad = WIDTH - depth * 4 - utf8.len(prefix)
    push(prefix .. string.rep("─", math.max(pad, 0)))
end

function dsl.var(name, value) push("$" .. name .. " = " .. fmt(value)) end
function dsl.set(key, value) push(key .. " = " .. fmt(value)) end

-- Mot-clé répétable : monitor, windowrule, animation, bezier, gesture…
function dsl.kw(key, ...) push(key .. " = " .. join(...)) end

function dsl.env(name, value) push("env = " .. name .. "," .. fmt(value)) end

function dsl.section(name, body)
    push(name .. " {")
    depth = depth + 1
    body()
    depth = depth - 1
    push("}")
end

-- bind / bindl / bindel / bindm / bindr…
for _, flavour in ipairs({ "bind", "bindl", "bindel", "bindm", "bindr", "binde" }) do
    dsl[flavour] = function(mods, key, dispatcher, args)
        push(flavour .. " = " .. join(mods, key, dispatcher, args))
    end
end

function dsl.submap(name, body)
    push("submap = " .. name)
    if body then body() end
    push("submap = reset")
end

local env = setmetatable(dsl, { __index = _G })
local chunk = assert(loadfile(here .. "/hyprland.lua", "t", env))
chunk()

local target = here .. "/hyprland.conf"
local f = assert(io.open(target, "w"))
f:write("# GÉNÉRÉ PAR build.lua — NE PAS ÉDITER À LA MAIN.\n")
f:write("# Source : hyprland.lua · régénérer avec `lua ~/.config/hypr/build.lua`\n\n")
f:write(table.concat(out, "\n"))
f:write("\n")
f:close()
print("écrit " .. target .. " (" .. #out .. " lignes)")
