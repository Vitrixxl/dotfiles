local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
    s("cmmb", {
        t({ "/**", " * " }),
        i(1, "comment"),
        t({ "", " */" }),
    }),
}
