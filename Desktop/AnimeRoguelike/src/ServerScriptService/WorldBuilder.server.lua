-- WorldBuilder.server.lua
-- Thin wrapper: delegates to WorldBuilderModule so the same code runs
-- both at Play time (here) and in edit mode (via the Studio plugin).
require(script.Parent.WorldBuilderModule).Build()
