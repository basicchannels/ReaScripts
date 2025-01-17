-- @description MB_Superglue Smart Action - Reversibly Glue or Unglue selected item(s) by context, ignoring time selection
-- @author MonkeyBars
-- @version 1.54
-- @changelog Change script name
-- @provides [main] .
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Fork of matthewjumpsoffbuildings's Glue Groups scripts


package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
require("MB_Superglue-Utils")

initSmartAction("Unglue", false)