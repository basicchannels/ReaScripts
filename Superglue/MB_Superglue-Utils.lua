-- @description MB_Superglue-Utils: Codebase for MB_Superglue scripts' functionality
-- @author MonkeyBars
-- @version 1.53
-- @changelog Rename item breaks Glue-Reversible [9] (https://github.com/MonkeyBars3k/ReaScripts/issues/3); Add script: "Explode container items" [6] (https://github.com/MonkeyBars3k/ReaScripts/issues/7); Add scripts: "Smart Glue-Explode" with & without time selection [1] (https://github.com/MonkeyBars3k/ReaScripts/issues/50); Don't store original item state in item name (https://github.com/MonkeyBars3k/ReaScripts/issues/73); Open container item is poor UX (https://github.com/MonkeyBars3k/ReaScripts/issues/75); Update code for item state from faststrings to Reaper state chunks (https://github.com/MonkeyBars3k/ReaScripts/issues/89); Refactor nomenclature (https://github.com/MonkeyBars3k/ReaScripts/issues/115); Replace os.time() for id string with GenGUID() (https://github.com/MonkeyBars3k/ReaScripts/issues/109); Change SNM_GetSetObjectState to state chunk functions (https://github.com/MonkeyBars3k/ReaScripts/issues/120); Switch take data number to item data take GUID (https://github.com/MonkeyBars3k/ReaScripts/issues/121); Refactor: Bundle up related variables into tables (https://github.com/MonkeyBars3k/ReaScripts/issues/129); Change background image on restored items (https://github.com/MonkeyBars3k/ReaScripts/issues/130); Abstract out (de)serialization (https://github.com/MonkeyBars3k/ReaScripts/issues/132); Remove extra loop in adjustRestoredItems() (https://github.com/MonkeyBars3k/ReaScripts/issues/134); Use serialization lib for dependencies storage (https://github.com/MonkeyBars3k/ReaScripts/issues/135); Extrapolate deserialized data handling (https://github.com/MonkeyBars3k/ReaScripts/issues/137); Refactor nested pool update functions (https://github.com/MonkeyBars3k/ReaScripts/issues/139); Correct parent container pool update offset logic (https://github.com/MonkeyBars3k/ReaScripts/issues/142); Regluing container with previously removed item throws recursion msg (https://github.com/MonkeyBars3k/ReaScripts/issues/145); Rearchitect parent position propagation (https://github.com/MonkeyBars3k/ReaScripts/issues/146); Change action nomenclature (https://github.com/MonkeyBars3k/ReaScripts/issues/148); Check that parents exist before attempting restore+reglue (https://github.com/MonkeyBars3k/ReaScripts/issues/150); Empty spacing item breaks in item replace modes (https://github.com/MonkeyBars3k/ReaScripts/issues/151); Reglue after parent deletion throws error (still looks for it) (https://github.com/MonkeyBars3k/ReaScripts/issues/153); Doublecheck loops through all items & remove if alternate solution possible (https://github.com/MonkeyBars3k/ReaScripts/issues/158); Move dev functions to external file (https://github.com/MonkeyBars3k/ReaScripts/issues/160); Deleted ancestors prevent higher ancestors from updating (https://github.com/MonkeyBars3k/ReaScripts/issues/161); Utilize terms "ancestors" and "descendants" (https://github.com/MonkeyBars3k/ReaScripts/issues/164); Smart action logic is wrong (https://github.com/MonkeyBars3k/ReaScripts/issues/166)
-- @provides [nomain] .
--   serpent.lua
--   sg-bg-restored.png
--   sg-bg-superglued.png
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Superglue scripts



-- ==== SUPERGLUE UTILS SCRIPT NOTES ====
-- Superglue requires Reaper SWS plug-in extension. https://standingwaterstudios.com/
-- Superglue uses serpent, a serialization library for LUA, for table-string and string-table conversion. https://github.com/pkulchenko/serpent
-- Superglue uses Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Data is also stored in media items' P_EXT.
-- General utility functions at bottom

-- for dev only
-- package.path = package.path .. ";" .. string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "?.lua"
-- require("sg-dev-functions")
 

local serpent = require("serpent")


local _script_path, _superglued_item_bg_img_path, _restored_item_bg_img_path, _peak_data_filename_extension, _scroll_action_id, _save_time_selection_slot_5_action_id, _restore_time_selection_slot_5_action_id, _crop_selected_items_to_time_selection_action_id, _glue_undo_block_string, _unglue_undo_block_string, _explode_undo_block_string, _smart_action_undo_block_string, _sizing_region_label, _sizing_region_color, _api_current_project, _api_include_all_undo_states, _api_item_image_center_tile, _api_data_key, _api_project_region_guid_key_prefix, _api_item_mute_key, _api_item_position_key, _api_item_length_key, _api_item_notes_key, _api_take_src_offset_key, _api_take_name_key, _api_takenumber_key, _api_null_takes_val, _global_script_prefix, _global_script_item_name_prefix, _separator, _superglued_container_name_prefix, _pool_key_prefix, _sizing_region_guid_key_suffix, _pool_contained_item_states_key_suffix, _pool_parent_position_key_suffix, _pool_parent_length_key_suffix, _instance_pool_id_key_suffix, _parent_pool_id_key_suffix, _descendant_pool_ids_key_suffix, _last_pool_id_key_suffix, _preglue_active_take_guid_key_suffix, _glue_data_key_suffix, _edit_data_key_suffix, _superglued_container_params_suffix, _parent_pool_ids_data_key_suffix, _container_preglue_state_suffix, _item_offset_to_container_position_key_suffix, _postglue_action_step, _preedit_action_step, _container_name_default_prefix, _nested_item_default_name, _double_quotation_mark, _msg_type_ok, _msg_type_ok_cancel, _msg_type_yes_no, _msg_response_ok, _msg_response_yes, _msg_change_selected_items, _data_storage_track, _active_glue_pool_id, _sizing_region_1st_display_num, _superglued_instance_offset_delta_since_last_glue, _restored_items_project_start_position_delta, _ancestor_pools_params, _position_changed_since_last_glue, _position_change_response

_script_path = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$")
_superglued_item_bg_img_path = _script_path .. "sg-bg-superglued.png"
_restored_item_bg_img_path = _script_path .. "sg-bg-restored.png"
_peak_data_filename_extension = ".reapeaks"
_scroll_action_id = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")
_save_time_selection_slot_5_action_id = reaper.NamedCommandLookup("_SWS_SAVETIME5")
_restore_time_selection_slot_5_action_id = reaper.NamedCommandLookup("_SWS_RESTTIME5")
_crop_selected_items_to_time_selection_action_id = reaper.NamedCommandLookup("_SWS_AWTRIMCROP")
_glue_undo_block_string = "MB_Superglue"
_unglue_undo_block_string = "MB_Superglue-Unglue"
_explode_undo_block_string = "MB_Superglue-Explode"
_smart_action_undo_block_string = "MB_Superglue-Smart-Action"
_sizing_region_label = "SG: DO NOT DELETE – Use to increase size – Pool #"
_sizing_region_color = reaper.ColorToNative(255, 255, 255)|0x1000000
_api_current_project = 0
_api_include_all_undo_states = -1
_api_item_image_center_tile = 1
_api_data_key = "P_EXT:"
_api_project_region_guid_key_prefix = "MARKER_GUID:"
_api_item_mute_key = "B_MUTE"
_api_item_position_key = "D_POSITION"
_api_item_length_key = "D_LENGTH"
_api_item_notes_key = "P_NOTES"
_api_take_src_offset_key = "D_STARTOFFS"
_api_take_name_key = "P_NAME"
_api_takenumber_key = "IP_TAKENUMBER"
_api_null_takes_val = "TAKE NULL"
_global_script_prefix = "SG_"
_global_script_item_name_prefix = "sg"
_separator = ":"
_superglued_container_name_prefix = _global_script_item_name_prefix .. _separator
_pool_key_prefix = "pool-"
_sizing_region_guid_key_suffix = ":sizing-region-guid"
_pool_contained_item_states_key_suffix = ":contained-item-states"
_pool_parent_position_key_suffix = ":first-parent-instance-position"
_pool_parent_length_key_suffix = ":first-parent-instance-length"
_instance_pool_id_key_suffix = "instance-pool-id"
_parent_pool_id_key_suffix = "parent-pool-id"
_last_pool_id_key_suffix = "last-pool-id"
_preglue_active_take_guid_key_suffix = "preglue-active-take-guid"
_glue_data_key_suffix = ":glue"
_edit_data_key_suffix = ":pre-edit"
_superglued_container_params_suffix = "_superglued-container-params"
_parent_pool_ids_data_key_suffix = ":parent-pool-ids"
_descendant_pool_ids_key_suffix = ":descendant_pool_ids"
_container_preglue_state_suffix = ":preglue-state-chunk"
_item_offset_to_container_position_key_suffix = "_superglued-container-offset"
_postglue_action_step = "postglue"
_preedit_action_step = "preedit"
_container_name_default_prefix = "^" .. _global_script_item_name_prefix .. "%:%d+"
_nested_item_default_name = '%[".+%]'
_double_quotation_mark = "\u{0022}"
_msg_type_ok = 0
_msg_type_ok_cancel = 1
_msg_type_yes_no = 4
_msg_response_ok = 2
_msg_response_yes = 6
_msg_change_selected_items = "Change the items selected and try again."
_data_storage_track = reaper.GetMasterTrack(_api_current_project)
_active_glue_pool_id = nil
_sizing_region_1st_display_num = 0
_superglued_instance_offset_delta_since_last_glue = 0
_restored_items_project_start_position_delta = 0
_ancestor_pools_params = {}
_position_changed_since_last_glue = false
_position_change_response = nil



function initSuperglue(obey_time_selection)
  local selected_item_count, restored_items_pool_id, selected_items, first_selected_item, first_selected_item_track, superglued_container

  selected_item_count = initAction("glue")

  if selected_item_count == false then return end

  restored_items_pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)
  _active_glue_pool_id = restored_items_pool_id
  selected_items, first_selected_item = getSelectedItems(selected_item_count)
  first_selected_item_track = reaper.GetMediaItemTrack(first_selected_item)

  if restored_items_pool_id then
    handleRemovedItems(restored_items_pool_id, selected_items)
  end

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or 
    containerSelectionIsInvalid(selected_item_count, "Glue") == true or 
    pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track) == true then
      return
  end

  superglued_container = triggerSuperglue(selected_items, restored_items_pool_id, first_selected_item_track, obey_time_selection, selected_items)
  
  exclusiveSelectItem(superglued_container)
  cleanUpAction(_glue_undo_block_string)
end


function initAction(action)
  local selected_item_count

  selected_item_count = doPreGlueChecks()

  if selected_item_count == false then return false end

  prepareAction(action)
  
  selected_item_count = getSelectedItemsCount()

  if itemsAreSelected(selected_item_count) == false then return false end

  return selected_item_count
end


function doPreGlueChecks()
  local selected_item_count

  if renderPathIsValid() == false then return false end

  selected_item_count = getSelectedItemsCount()
  
  if itemsAreSelected(selected_item_count) == false then return false end

  if requiredLibsAreInstalled() == false then return false end

  return selected_item_count
end


function renderPathIsValid()
  local platform, proj_renderpath, win_platform_regex, is_win, win_absolute_path_regex, is_win_absolute_path, is_win_local_path, nix_absolute_path_regex, is_nix_absolute_path, is_other_local_path

  platform = reaper.GetOS()
  proj_renderpath = reaper.GetProjectPath(_api_current_project)
  win_platform_regex = "^Win"
  is_win = string.match(platform, win_platform_regex)
  win_absolute_path_regex = "^%u%:\\"
  is_win_absolute_path = string.match(proj_renderpath, win_absolute_path_regex)
  is_win_local_path = is_win and not is_win_absolute_path
  nix_absolute_path_regex = "^/"
  is_nix_absolute_path = string.match(proj_renderpath, nix_absolute_path_regex)
  is_other_local_path = not is_win and not is_nix_absolute_path
  
  if is_win_local_path or is_other_local_path then
    reaper.ShowMessageBox("Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "Superglue needs a valid file render path.", _msg_type_ok)
    
    return false

  else
    return true
  end
end


function getSelectedItemsCount()
  return reaper.CountSelectedMediaItems(_api_current_project)
end


function itemsAreSelected(selected_item_count)
  local no_items_are_selected = selected_item_count < 1

  if not selected_item_count or no_items_are_selected then 
    return false

  else
    return true
  end
end


function requiredLibsAreInstalled()
  local can_get_sws_version, sws_version

  can_get_sws_version = reaper.CF_GetSWSVersion ~= nil

  if can_get_sws_version then
    sws_version = reaper.CF_GetSWSVersion()
  end

  if not can_get_sws_version or not sws_version then
    reaper.ShowMessageBox("Please install SWS at https://standingwaterstudios.com/ and try again.", "Superglue requires the SWS plugin extension to work.", _msg_type_ok)
    
    return false
  end
end


function prepareAction(action)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  if action == "glue" then
    setResetItemSelectionSet(true)
  end
end


function setResetItemSelectionSet(set_reset)
  local set, reset

  set = set_reset
  reset = not set_reset

  if set then
    -- save selected item selection set to slot 10
    reaper.Main_OnCommand(41238, 0)

  elseif reset then
    -- reset item selection from selection set slot 10
    reaper.Main_OnCommand(41248, 0)
  end
end


function getFirstPoolIdFromSelectedItems(selected_item_count)
  local i, this_item, this_item_pool_id, this_item_has_stored_pool_id

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)
    this_item_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)
    this_item_has_stored_pool_id = this_item_pool_id and this_item_pool_id ~= ""

    if this_item_has_stored_pool_id then
      return this_item_pool_id
    end
  end

  return false
end


function storeRetrieveItemData(item, key_suffix, val)
  local retrieve, store, data_param_key, retval

  retrieve = not val
  store = val
  data_param_key = _api_data_key .. _global_script_prefix .. key_suffix

  if retrieve then
    retval, val = reaper.GetSetMediaItemInfo_String(item, data_param_key, "", false)

    return val

  elseif store then
    reaper.GetSetMediaItemInfo_String(item, data_param_key, val, true)
  end
end


function getSelectedItems(selected_item_count)
  local selected_items, i, this_item, first_selected_item

  selected_items = {}
  
  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)

    table.insert(selected_items, this_item)

    if not first_selected_item then
      first_selected_item = this_item
    end
  end

  return selected_items, first_selected_item
end


function handleRemovedItems(restored_items_pool_id, selected_items)
  local retval, last_glue_stored_item_states_string, last_glue_stored_item_states_table, this_stored_item_guid, this_item_last_glue_state, this_stored_item_is_unmatched, i, this_selected_item, this_selected_item_guid, this_unmatched_item

  retval, last_glue_stored_item_states_string = storeRetrieveProjectData(_pool_key_prefix .. restored_items_pool_id .. _pool_contained_item_states_key_suffix)
    
  if retval then
    retval, last_glue_stored_item_states_table = serpent.load(last_glue_stored_item_states_string)

    for this_stored_item_guid, this_item_last_glue_state in pairs(last_glue_stored_item_states_table) do
      this_stored_item_is_unmatched = true

      for i = 1, #selected_items do
        this_selected_item = selected_items[i]
        this_selected_item_guid = reaper.BR_GetMediaItemGUID(this_selected_item)

        if this_selected_item_guid == this_stored_item_guid then
          this_stored_item_is_unmatched = false

          break
        end
      end

      if this_stored_item_is_unmatched then
        this_unmatched_item = reaper.BR_GetMediaItemByGUID(_api_current_project, this_stored_item_guid)

        if this_unmatched_item then
          addRemoveItemImage(this_unmatched_item, false)
          storeRetrieveItemData(this_unmatched_item, _parent_pool_id_key_suffix, "")
        end
      end
    end
  end
end


function getFirstSelectedItem()
  return reaper.GetSelectedMediaItem(_api_current_project, 0)
end


function itemsOnMultipleTracksAreSelected(selected_item_count)
  local items_on_multiple_tracks_are_selected = detectSelectedItemsOnMultipleTracks(selected_item_count)

  if items_on_multiple_tracks_are_selected == true then 
      reaper.ShowMessageBox(_msg_change_selected_items, "Superglue only works on items on a single track.", _msg_type_ok)
      return true
  end
end


function detectSelectedItemsOnMultipleTracks(selected_item_count)
  local item_is_on_different_track_than_previous, i, this_item, this_item_track, prev_item_track

  item_is_on_different_track_than_previous = false

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)
    this_item_track = reaper.GetMediaItemTrack(this_item)
    item_is_on_different_track_than_previous = this_item_track and prev_item_track and this_item_track ~= prev_item_track
  
    if item_is_on_different_track_than_previous == true then
      return item_is_on_different_track_than_previous
    end
    
    prev_item_track = this_item_track
  end
end


function containerSelectionIsInvalid(selected_item_count, action)
  local superglued_containers, restored_items, multiple_instances_from_same_pool_are_selected, i, this_restored_item, this_restored_item_parent_pool_id, this_is_2nd_or_later_restored_item_with_pool_id, this_item_belongs_to_different_pool_than_active_edit, last_restored_item_parent_pool_id, recursive_container_is_being_glued

  superglued_containers, restored_items = getSelectedSuperglueItemTypes(selected_item_count)
  multiple_instances_from_same_pool_are_selected = false

  for i = 1, #restored_items do
    this_restored_item = restored_items[i]
    this_restored_item_parent_pool_id = storeRetrieveItemData(this_restored_item, _parent_pool_id_key_suffix)
    this_is_2nd_or_later_restored_item_with_pool_id = last_restored_item_parent_pool_id and last_restored_item_parent_pool_id ~= ""
    this_item_belongs_to_different_pool_than_active_edit = this_restored_item_parent_pool_id ~= last_restored_item_parent_pool_id

    if this_is_2nd_or_later_restored_item_with_pool_id then

      if this_item_belongs_to_different_pool_than_active_edit then
        multiple_instances_from_same_pool_are_selected = true

        break
      end

    else
      last_restored_item_parent_pool_id = this_restored_item_parent_pool_id
    end
  end
  
  recursive_container_is_being_glued = recursiveContainerIsBeingGlued(superglued_containers, restored_items) == true

  if recursive_container_is_being_glued then return true end

  if multiple_instances_from_same_pool_are_selected then
    reaper.ShowMessageBox(_msg_change_selected_items, "Superglue can only " .. action .. " one pool instance at a time.", _msg_type_ok)
    setResetItemSelectionSet(false)

    return true
  end
end


function getSelectedSuperglueItemTypes(selected_item_count)
  local item_types, item_types_data, i, this_item_type, this_item, superglued_container_pool_id, restored_item_pool_id, j

  item_types = {"superglued", "restored", "noncontainer", "child_instance", "parent_instance"}
  item_types_data = {}

  for i = 1, #item_types do
    this_item_type = item_types[i]
    item_types_data[this_item_type] = {
      ["selected_items"] = {}
    }
  end

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)
    superglued_container_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    restored_item_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)
    item_types_data["superglued"]["is"] = superglued_container_pool_id and superglued_container_pool_id ~= ""
    item_types_data["restored"]["is"] = restored_item_pool_id and restored_item_pool_id ~= ""
    item_types_data["noncontainer"]["is"] = not item_types_data["superglued"]["is"]
    item_types_data["child_instance"]["is"] = item_types_data["superglued"]["is"] and item_types_data["restored"]["is"]
    item_types_data["parent_instance"]["is"] = item_types_data["superglued"]["is"] and not item_types_data["restored"]["is"]

    for j = 1, #item_types do
      this_item_type = item_types[j]
      
      if item_types_data[this_item_type]["is"] then
        table.insert(item_types_data[this_item_type]["selected_items"], this_item)
      end
    end
  end

  return item_types_data["superglued"]["selected_items"], item_types_data["restored"]["selected_items"], item_types_data["noncontainer"]["selected_items"], item_types_data["child_instance"]["selected_items"], item_types_data["parent_instance"]["selected_items"]
end


function recursiveContainerIsBeingGlued(superglued_containers, restored_items)
  local i, this_superglued_container, this_superglued_container_instance_pool_id, j, this_restored_item, this_restored_item_parent_pool_id, this_restored_item_is_from_same_pool_as_selected_superglued_container

  for i = 1, #superglued_containers do
    this_superglued_container = superglued_containers[i]
    this_superglued_container_instance_pool_id = storeRetrieveItemData(this_superglued_container, _instance_pool_id_key_suffix)

    for j = 1, #restored_items do
      this_restored_item = restored_items[j]
      this_restored_item_parent_pool_id = storeRetrieveItemData(this_restored_item, _parent_pool_id_key_suffix)
      this_restored_item_is_from_same_pool_as_selected_superglued_container = this_superglued_container_instance_pool_id == this_restored_item_parent_pool_id
      
      if this_restored_item_is_from_same_pool_as_selected_superglued_container then
        reaper.ShowMessageBox(_msg_change_selected_items, "Superglue can't glue a superglued container item to an instance from the same pool being Unglued – that could destroy the universe!", _msg_type_ok)
        setResetItemSelectionSet(false)

        return true
      end
    end
  end
end


function pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track)
  local track_has_no_virtual_instrument, i, this_item, midi_item_is_selected

  track_has_no_virtual_instrument = reaper.TrackFX_GetInstrument(first_selected_item_track) == -1

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)
    midi_item_is_selected = midiItemIsSelected(this_item)

    if midi_item_is_selected then
      break
    end
  end

  if midi_item_is_selected and track_has_no_virtual_instrument then
    reaper.ShowMessageBox("Add a virtual instrument to render audio into the superglued container or try a different item selection.", "Superglue can't glue pure MIDI without a virtual instrument.", _msg_type_ok)
    return true
  end
end


function midiItemIsSelected(item)
  local active_take, active_take_is_midi

  active_take = reaper.GetActiveTake(item)
  active_take_is_midi = reaper.TakeIsMIDI(active_take)

  if active_take and active_take_is_midi then
    return true
  else
    return false
  end
end


function triggerSuperglue(selected_items, restored_items_pool_id, first_selected_item_track, obey_time_selection)
  local superglued_container

  if restored_items_pool_id then
    superglued_container = handleReglue(selected_items, first_selected_item_track, restored_items_pool_id, obey_time_selection)
  else
    superglued_container = handleGlue(selected_items, first_selected_item_track, nil, nil, nil, obey_time_selection)
  end

  return superglued_container
end


function exclusiveSelectItem(item)
  if item then
    deselectAllItems()
    reaper.SetMediaItemSelected(item, true)
  end
end


function deselectAllItems()
  reaper.Main_OnCommand(40289, 0)
end


function cleanUpAction(undo_block_string)
  refreshUI()
  reaper.Undo_EndBlock(undo_block_string, _api_include_all_undo_states)
end


function refreshUI()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(true)
end


function handleGlue(selected_items, first_selected_item_track, pool_id, sizing_region_guid, restored_items_position_adjustment, obey_time_selection, parent_is_being_updated)
  local this_is_new_glue, this_is_reglue, first_selected_item, first_selected_item_name, sizing_params, time_selection_was_set_by_code, selected_item_states, selected_instances_pool_ids, earliest_item_delta_to_superglued_container_position, superglued_container

  this_is_new_glue = not pool_id
  this_is_reglue = pool_id
  first_selected_item = getFirstSelectedItem()
  first_selected_item_name = getSetItemName(first_selected_item)

  deselectAllItems()

  if this_is_new_glue then
    pool_id = handlePoolId()

  elseif this_is_reglue then
    sizing_params, obey_time_selection, time_selection_was_set_by_code = setUpReglue(parent_is_being_updated, first_selected_item_track, pool_id, restored_items_position_adjustment, sizing_region_guid, selected_items, obey_time_selection)
  end

  selected_item_states, selected_instances_pool_ids, earliest_item_delta_to_superglued_container_position = handlePreglueItems(selected_items, pool_id, sizing_params, first_selected_item_track, parent_is_being_updated)
  superglued_container = glueSelectedItemsIntoContainer(obey_time_selection)

  handlePostGlue(selected_items, pool_id, first_selected_item_name, superglued_container, earliest_item_delta_to_superglued_container_position, selected_instances_pool_ids, sizing_params, parent_is_being_updated, time_selection_was_set_by_code)

  return superglued_container
end


function getSetItemName(item, new_name, add_or_remove)
  local set, get, add, remove, item_has_no_takes, take, current_name

  set = new_name
  get = not new_name
  add = add_or_remove == true
  remove = add_or_remove == false

  item_has_no_takes = reaper.GetMediaItemNumTakes(item) < 1

  if item_has_no_takes then return end

  take = reaper.GetActiveTake(item)

  if take then
    current_name = reaper.GetTakeName(take)

    if set then
      if add then
        new_name = current_name .. " " .. new_name

      elseif remove then
        new_name = string.gsub(current_name, new_name, "")
      end

      reaper.GetSetMediaItemTakeInfo_String(take, _api_take_name_key, new_name, true)

      return new_name, take

    elseif get then
      return current_name, take
    end
  end
end


function handlePoolId()
  local retval, last_pool_id, new_pool_id
  
  retval, last_pool_id = storeRetrieveProjectData(_last_pool_id_key_suffix)
  new_pool_id = incrementPoolId(last_pool_id)

  storeRetrieveProjectData(_last_pool_id_key_suffix, new_pool_id)

  return new_pool_id
end


function storeRetrieveProjectData(key, val)
  local retrieve, store, store_or_retrieve_state_data, data_param_key, retval, state_data_val

  retrieve = not val
  store = val

  if retrieve then
    val = ""
    store_or_retrieve_state_data = false

  elseif store then
    store_or_retrieve_state_data = true
  end

  data_param_key = _api_data_key .. _global_script_prefix .. key
  retval, state_data_val = reaper.GetSetMediaTrackInfo_String(_data_storage_track, data_param_key, val, store_or_retrieve_state_data)

  return retval, state_data_val
end


function incrementPoolId(last_pool_id)
  local this_is_first_glue_in_project, new_pool_id

  this_is_first_glue_in_project = not last_pool_id or last_pool_id == ""

  if this_is_first_glue_in_project then
    new_pool_id = 1

  else
    last_pool_id = tonumber(last_pool_id)
    new_pool_id = math.floor(last_pool_id + 1)
  end

  return new_pool_id
end


function setUpReglue(parent_is_being_updated, first_selected_item_track, pool_id, restored_items_position_adjustment, sizing_region_guid, selected_items, obey_time_selection)
  local user_selected_instance_is_being_reglued

  user_selected_instance_is_being_reglued = not parent_is_being_updated

  if parent_is_being_updated then
    return setUpParentUpdate(first_selected_item_track, pool_id, restored_items_position_adjustment, obey_time_selection)

  elseif user_selected_instance_is_being_reglued then
    return setUpUserSelectedInstanceReglue(sizing_region_guid, first_selected_item_track, selected_items, obey_time_selection)
  end
end


function setUpParentUpdate(first_selected_item_track, pool_id, restored_items_position_adjustment, obey_time_selection)
  local pool_parent_position_key_label, pool_parent_length_key_label, retval, pool_parent_last_glue_position, pool_parent_last_glue_length, pool_parent_last_glue_end_point, sizing_params, time_selection_was_set_by_code

  pool_parent_position_key_label = _pool_key_prefix .. pool_id .. _pool_parent_position_key_suffix
  pool_parent_length_key_label = _pool_key_prefix .. pool_id .. _pool_parent_length_key_suffix
  retval, pool_parent_last_glue_position = storeRetrieveProjectData(pool_parent_position_key_label)
  retval, pool_parent_last_glue_length = storeRetrieveProjectData(pool_parent_length_key_label)
  pool_parent_last_glue_position = tonumber(pool_parent_last_glue_position)
  pool_parent_last_glue_length = tonumber(pool_parent_last_glue_length)
  pool_parent_last_glue_end_point = pool_parent_last_glue_position + pool_parent_last_glue_length
  sizing_params = {
    ["position"] = pool_parent_last_glue_position - restored_items_position_adjustment,
    ["length"] = pool_parent_last_glue_length - restored_items_position_adjustment,
    ["end_point"] = pool_parent_last_glue_end_point - restored_items_position_adjustment
  }

  if not obey_time_selection then
    setResetGlueTimeSelection(sizing_params, "set")

    obey_time_selection = true
    time_selection_was_set_by_code = true
  end

  return sizing_params, obey_time_selection, time_selection_was_set_by_code
end


function setResetGlueTimeSelection(sizing_params, set_or_reset)
  local set, reset

  set = set_or_reset == "set"
  reset = set_or_reset == "reset"

  if set then
    reaper.Main_OnCommand(_save_time_selection_slot_5_action_id, 0)
    reaper.GetSet_LoopTimeRange(true, false, sizing_params.position, sizing_params.end_point, false)

  elseif reset then
    reaper.Main_OnCommand(_restore_time_selection_slot_5_action_id, 0)
  end
end


function convertMidiItemToAudio(item)
  local item_takes_count, active_take, this_take_is_midi, retval, active_take_guid

  item_takes_count = reaper.GetMediaItemNumTakes(item)

  if item_takes_count > 0 then
    active_take = reaper.GetActiveTake(item)
    this_take_is_midi = active_take and reaper.TakeIsMIDI(active_take)

    if this_take_is_midi then
      reaper.SetMediaItemSelected(item, true)
      renderFxToItem()
      
      active_take = reaper.GetActiveTake(item)
      retval, active_take_guid = reaper.GetSetMediaItemTakeInfo_String(active_take, "GUID", "", false)

      storeRetrieveItemData(item, _preglue_active_take_guid_key_suffix, active_take_guid)
      reaper.SetMediaItemSelected(item, false)
      cleanNullTakes(item)
    end
  end
end


function renderFxToItem()
  reaper.Main_OnCommand(40209, 0)
end


function setLastTakeActive(item, item_takes_count)
  local last_take = reaper.GetTake(item, item_takes_count)

  reaper.SetActiveTake(last_take)

  return last_take
end


function cleanNullTakes(item, force)
  local item_state = getSetItemStateChunk(item)

  if string.find(item_state, _api_null_takes_val) or force then
    item_state = string.gsub(item_state, _api_null_takes_val, "")

    getSetItemStateChunk(item, item_state)
  end
end


function getSetItemStateChunk(item, state)
  local get, set, retval

  get = not state
  set = state

  if get then
    retval, state = reaper.GetItemStateChunk(item, "", true)

    return state

  elseif set then
    reaper.SetItemStateChunk(item, state, true)
  end
end


function setGluedContainerName(item, item_name_ending)
  local take, new_item_name

  take = reaper.GetActiveTake(item)
  new_item_name = _superglued_container_name_prefix .. item_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, _api_take_name_key, new_item_name, true)
end


function selectDeselectItems(items, select_deselect)
  local i, this_item

  for i = 1, #items do
    this_item = items[i]

    if this_item then 
      reaper.SetMediaItemSelected(this_item, select_deselect)
    end
  end
end


function setUpUserSelectedInstanceReglue(sizing_region_guid, active_track, selected_items, obey_time_selection)
  local sizing_params, is_active_container_reglue, time_selection_was_set_by_code

  sizing_params = getSetSizingRegion(sizing_region_guid)
  is_active_container_reglue = sizing_params
  time_selection_was_set_by_code = false

  if is_active_container_reglue then

    if not obey_time_selection then
      sizing_params = calculateSizingTimeSelection(selected_items, sizing_params)

      setResetGlueTimeSelection(sizing_params, "set")

      obey_time_selection = true
      time_selection_was_set_by_code = true
    end

    getSetSizingRegion(sizing_region_guid, "delete")
  end

  return sizing_params, obey_time_selection, time_selection_was_set_by_code
end


function getSetSizingRegion(sizing_region_guid_or_pool_id, params_or_delete)
  local get_or_delete, set, region_idx, retval, sizing_region_params, sizing_region_guid
 
  get_or_delete = not params_or_delete or params_or_delete == "delete"
  set = params_or_delete and params_or_delete ~= "delete"
  region_idx = 0

  repeat

    if get_or_delete then
      retval, sizing_region_params = getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)

      if sizing_region_params then
        return sizing_region_params
      end

    elseif set then
      retval, sizing_region_guid = addSizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)

      if sizing_region_guid then
        return sizing_region_guid
      end
    end

    region_idx = region_idx + 1

  until retval == 0
end


function calculateSizingTimeSelection(selected_items, sizing_params)
  local i, this_selected_item, this_selected_item_position, this_selected_item_length, this_selected_item_end_point, earliest_selected_item_position, latest_selected_item_end_point

  for i = 1, #selected_items do
    this_selected_item = selected_items[i]
    this_selected_item_position = reaper.GetMediaItemInfo_Value(this_selected_item, _api_item_position_key)
    this_selected_item_length = reaper.GetMediaItemInfo_Value(this_selected_item, _api_item_length_key)
    this_selected_item_end_point = this_selected_item_position + this_selected_item_length

    if earliest_selected_item_position then
      earliest_selected_item_position = math.min(earliest_selected_item_position, this_selected_item_position)
    else
      earliest_selected_item_position = this_selected_item_position
    end

    if latest_selected_item_end_point then
      latest_selected_item_end_point = math.max(latest_selected_item_end_point, this_selected_item_end_point)
    else
      latest_selected_item_end_point = this_selected_item_end_point
    end
  end

  sizing_params.position = math.min(sizing_params.position, earliest_selected_item_position)
  sizing_params.end_point = math.max(sizing_params.end_point, latest_selected_item_end_point)

  return sizing_params
end


function handlePreglueItems(selected_items, pool_id, sizing_params, first_selected_item_track, parent_is_being_updated)
  local earliest_item_delta_to_superglued_container_position, selected_item_states, selected_instances_pool_ids, i

  earliest_item_delta_to_superglued_container_position = setPreglueItemsData(selected_items, pool_id, sizing_params)
  selected_item_states, selected_instances_pool_ids = createSelectedItemStates(selected_items, pool_id)

  storeSelectedItemStates(pool_id, selected_item_states)
  selectDeselectItems(selected_items, true)

  if parent_is_being_updated then

    for i = 1, #selected_items do
      cropItemToParent(selected_items[i], sizing_params)
    end
  end

  return selected_item_states, selected_instances_pool_ids, earliest_item_delta_to_superglued_container_position
end


function setPreglueItemsData(preglue_items, pool_id, sizing_params)
  local this_is_new_glue, this_is_reglue, earliest_item_delta_to_superglued_container_position, i, this_item, this_is_1st_item, this_item_position, first_item_position, offset_position, this_item_delta_to_superglued_container_position

  this_is_new_glue = not sizing_params
  this_is_reglue = sizing_params
  earliest_item_delta_to_superglued_container_position = 0

  for i = 1, #preglue_items do
    this_item = preglue_items[i]
    this_is_1st_item = i == 1
    this_item_position = reaper.GetMediaItemInfo_Value(this_item, _api_item_position_key)

    storeRetrieveItemData(this_item, _parent_pool_id_key_suffix, pool_id)

    if this_is_1st_item then
      first_item_position = this_item_position
    end

    if this_is_new_glue then
      offset_position = this_item_position

    elseif this_is_reglue then
      offset_position = math.min(first_item_position, sizing_params.position)
    end
    
    this_item_delta_to_superglued_container_position = this_item_position - offset_position
    earliest_item_delta_to_superglued_container_position = math.min(earliest_item_delta_to_superglued_container_position, this_item_delta_to_superglued_container_position)

    storeRetrieveItemData(this_item, _item_offset_to_container_position_key_suffix, this_item_delta_to_superglued_container_position)
  end

  return earliest_item_delta_to_superglued_container_position
end


function createSelectedItemStates(selected_items, active_pool_id)
  local selected_item_states, selected_instances_pool_ids, i, item, this_item, this_superglued_container_pool_id, this_is_superglued_container, this_item_guid, this_item_state

  selected_item_states = {}
  selected_instances_pool_ids = {}

  for i, item in ipairs(selected_items) do
    this_item = selected_items[i]
    this_superglued_container_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    this_is_superglued_container = this_superglued_container_pool_id and this_superglued_container_pool_id ~= ""

    convertMidiItemToAudio(this_item)

    this_item_guid = reaper.BR_GetMediaItemGUID(item)
    this_item_state = getSetItemStateChunk(this_item)

    selected_item_states[this_item_guid] = this_item_state

    if this_is_superglued_container then
      table.insert(selected_instances_pool_ids, this_superglued_container_pool_id)
    end
  end

  return selected_item_states, selected_instances_pool_ids, this_superglued_container_pool_id
end


function storeSelectedItemStates(pool_id, selected_item_states)
  local pool_item_states_key_label

  pool_item_states_key_label = _pool_key_prefix .. pool_id .. _pool_contained_item_states_key_suffix
  selected_item_states = serpent.dump(selected_item_states)
  
  storeRetrieveProjectData(pool_item_states_key_label, selected_item_states)
end


function cropItemToParent(restored_item, this_parent_instance_params)
  local restored_item_params, restored_item_starts_before_parent, restored_item_ends_later_than_parent, restored_item_parent_pool_id, restored_item_cropped_position_delta, restored_item_active_take, end_point_delta, restored_item_new_length

  restored_item_params = getSetItemParams(restored_item)
  restored_item_starts_before_parent = restored_item_params.position < this_parent_instance_params.position
  restored_item_ends_later_than_parent = restored_item_params.end_point > this_parent_instance_params.end_point
  restored_item_parent_pool_id = storeRetrieveItemData(restored_item, _parent_pool_id_key_suffix)

  if restored_item_starts_before_parent then
    restored_item_cropped_position_delta = this_parent_instance_params.position - restored_item_params.position 
    restored_item_active_take = reaper.GetTake(restored_item, restored_item_params.active_take_num)

    reaper.SetMediaItemPosition(restored_item, this_parent_instance_params.position, true)
    reaper.SetMediaItemTakeInfo_Value(restored_item_active_take, _api_take_src_offset_key, restored_item_cropped_position_delta)
  end

  if restored_item_ends_later_than_parent then
    end_point_delta = restored_item_params.end_point - this_parent_instance_params.end_point
    restored_item_new_length = restored_item_params.length - end_point_delta
    
    reaper.SetMediaItemLength(restored_item, restored_item_new_length, false)
  end
end


function getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local get, delete, sizing_region_guid, sizing_region_api_key, stored_guid_retval, this_region_guid, this_region_belongs_to_active_pool, sizing_region_params, retval, is_region

  get = not params_or_delete
  delete = params_or_delete == "delete"
  sizing_region_guid = sizing_region_guid_or_pool_id
  sizing_region_api_key = _api_project_region_guid_key_prefix .. region_idx
  stored_guid_retval, this_region_guid = reaper.GetSetProjectInfo_String(_api_current_project, sizing_region_api_key, "", false)
  this_region_belongs_to_active_pool = this_region_guid == sizing_region_guid

  if this_region_belongs_to_active_pool then
    if get then
      sizing_region_params = {
        ["idx"] = region_idx
      }

      retval, is_region, sizing_region_params.position, sizing_region_params.end_point = reaper.EnumProjectMarkers3(_api_current_project, region_idx)
      sizing_region_params.length = sizing_region_params.end_point - sizing_region_params.position

      return retval, sizing_region_params

    elseif delete then
      reaper.DeleteProjectMarkerByIndex(_api_current_project, region_idx, true)

      retval = 0

      return retval
    end

  else
    return retval
  end
end


function addSizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local params, pool_id, sizing_region_name, sizing_region_label_num, sizing_region_guid_key_label, retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num, this_region_is_active, sizing_region_api_key, stored_guid_retval, sizing_region_guid

  params = params_or_delete
  params.end_point = params.position + params.length
  pool_id = sizing_region_guid_or_pool_id
  sizing_region_name = _sizing_region_label .. pool_id
  sizing_region_label_num = reaper.AddProjectMarker2(_api_current_project, true, params.position, params.end_point, sizing_region_name, _sizing_region_1st_display_num, _sizing_region_color)
  sizing_region_guid_key_label = _pool_key_prefix .. pool_id .. _sizing_region_guid_key_suffix

  retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num = reaper.EnumProjectMarkers3(_api_current_project, region_idx)
      
  if is_region then
    this_region_is_active = this_region_label_num == sizing_region_label_num

    if this_region_is_active then
      sizing_region_api_key = _api_project_region_guid_key_prefix .. region_idx
      stored_guid_retval, sizing_region_guid = reaper.GetSetProjectInfo_String(_api_current_project, sizing_region_api_key, "", false)
      storeRetrieveProjectData(sizing_region_guid_key_label, sizing_region_guid)

      return retval, sizing_region_guid

    else
      return retval
    end
  end
end


function handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)
  local selected_item_count, multiple_user_items_are_selected, other_selected_items_count, is_nested_container_name, has_nested_item_name, item_name_addl_count_str, superglued_container_init_name

  selected_item_count = getTableSize(selected_items)
  multiple_user_items_are_selected = selected_item_count > 1
  other_selected_items_count = selected_item_count - 1
  is_nested_container_name = string.find(first_selected_item_name, _container_name_default_prefix)
  has_nested_item_name = string.find(first_selected_item_name, _nested_item_default_name)
  
  if multiple_user_items_are_selected then
    item_name_addl_count_str = " +" .. other_selected_items_count ..  " more"

  else
    item_name_addl_count_str = ""
  end

  if is_nested_container_name and has_nested_item_name then
    first_selected_item_name = string.match(first_selected_item_name, _container_name_default_prefix)
  end

  superglued_container_init_name = pool_id .. " [" .. _double_quotation_mark .. first_selected_item_name .. _double_quotation_mark .. item_name_addl_count_str .. "]"

  return superglued_container_init_name
end


function handleSupergluedContainerPostGlue(superglued_container, superglued_container_init_name, pool_id, earliest_item_delta_to_superglued_container_position, this_is_reglue, parent_is_being_updated)
  local superglued_container_preglue_state_key_suffix, superglued_container_state, pool_parent_position_key_label, pool_parent_length_key_label, pool_parent_params

  superglued_container_preglue_state_key_suffix = _pool_key_prefix .. pool_id .. _container_preglue_state_suffix
  superglued_container_state = getSetItemStateChunk(superglued_container)
  pool_parent_position_key_label = _pool_key_prefix .. pool_id .. _pool_parent_position_key_suffix
  pool_parent_length_key_label = _pool_key_prefix .. pool_id .. _pool_parent_length_key_suffix
  pool_parent_params = getSetItemParams(superglued_container)

  setGluedContainerName(superglued_container, superglued_container_init_name, true)
  addRemoveItemImage(superglued_container, "superglued")
  storeRetrieveSupergluedContainerParams(pool_id, _postglue_action_step, superglued_container)
  storeRetrieveItemData(superglued_container, _instance_pool_id_key_suffix, pool_id)
  storeRetrieveItemData(superglued_container, superglued_container_preglue_state_key_suffix, superglued_container_state)
  storeRetrieveProjectData(pool_parent_position_key_label, pool_parent_params.position)
  storeRetrieveProjectData(pool_parent_length_key_label, pool_parent_params.length)
end


function storeRetrieveSupergluedContainerParams(pool_id, action_step, superglued_container)
  local retrieve, store, superglued_container_params_key_label, retval, superglued_container_params

  retrieve = not superglued_container
  store = superglued_container
  superglued_container_params_key_label = _pool_key_prefix .. pool_id .. _separator .. action_step .. _superglued_container_params_suffix

  if retrieve then
    retval, superglued_container_params = storeRetrieveProjectData(superglued_container_params_key_label)
    retval, superglued_container_params = serpent.load(superglued_container_params)

    if superglued_container_params then
      superglued_container_params.track = reaper.BR_GetMediaTrackByGUID(_api_current_project, superglued_container_params.track_guid)
    end

    return superglued_container_params

  elseif store then
    superglued_container_params = getSetItemParams(superglued_container)
    superglued_container_params = serpent.dump(superglued_container_params)

    storeRetrieveProjectData(superglued_container_params_key_label, superglued_container_params)
  end
end


function getSetItemParams(item, params)
  local get, set, track, retval, track_guid, active_take, active_take_num, item_params

  get = not params
  set = params

  if get then
    track = reaper.GetMediaItemTrack(item)
    retval, track_guid = reaper.GetSetMediaTrackInfo_String(track, "GUID", "", false)
    active_take = reaper.GetActiveTake(item)

    if active_take then
      active_take_num = reaper.GetMediaItemTakeInfo_Value(active_take, _api_takenumber_key)
    end

    item_params = {
      ["item_guid"] = reaper.BR_GetMediaItemGUID(item),
      ["state"] = getSetItemStateChunk(item),
      ["track_guid"] = track_guid,
      ["active_take_num"] = active_take_num,
      ["position"] = reaper.GetMediaItemInfo_Value(item, _api_item_position_key),
      ["length"] = reaper.GetMediaItemInfo_Value(item, _api_item_length_key),
      ["instance_pool_id"] = storeRetrieveItemData(item, _instance_pool_id_key_suffix),
      ["parent_pool_id"] = storeRetrieveItemData(item, _parent_pool_id_key_suffix)
    }
    item_params.end_point = item_params.position + item_params.length

    if active_take then
      item_params.source_offset = reaper.GetMediaItemTakeInfo_Value(active_take, _api_take_src_offset_key)
    end

    return item_params

  elseif set then
    reaper.SetMediaItemInfo_Value(item, _api_item_position_key, params.position)
    reaper.SetMediaItemInfo_Value(item, _api_item_length_key, params.length)
  end
end


function addRemoveItemImage(item, type_or_remove)
  local add, type, remove, img_path

  add = type_or_remove
  type = type_or_remove
  remove = type_or_remove == false

  if add then

    if type == "superglued" then
      img_path = _superglued_item_bg_img_path

    elseif type == "restored" then
      img_path = _restored_item_bg_img_path
    end

  elseif remove then
    img_path = ""
  end

  reaper.BR_SetMediaItemImageResource(item, img_path, _api_item_image_center_tile)
end


function glueSelectedItemsIntoContainer(obey_time_selection)
  local superglued_container

  glueSelectedItems(obey_time_selection)

  superglued_container = getFirstSelectedItem()

  return superglued_container
end


function glueSelectedItems(obey_time_selection)

  if obey_time_selection == true then
    reaper.Main_OnCommand(41588, 0)
  else
    reaper.Main_OnCommand(40362, 0)
  end
end


function handlePostGlue(selected_items, pool_id, first_selected_item_name, superglued_container, earliest_item_delta_to_superglued_container_position, child_instances_pool_ids, sizing_params, parent_is_being_updated, time_selection_was_set_by_code)
  local this_is_reglue, user_selected_instance_is_being_reglued, superglued_container_init_name

  this_is_reglue = pool_id
  user_selected_instance_is_being_reglued = not parent_is_being_updated
  superglued_container_init_name = handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)

  handleSupergluedContainerPostGlue(superglued_container, superglued_container_init_name, pool_id, earliest_item_delta_to_superglued_container_position, this_is_reglue, parent_is_being_updated)
  handleDescendantPoolReferences(pool_id, child_instances_pool_ids)

  if user_selected_instance_is_being_reglued then
    handleParentPoolReferencesInChildPools(pool_id, child_instances_pool_ids)
  end

  if this_is_reglue and time_selection_was_set_by_code then
    setResetGlueTimeSelection(sizing_params, "reset")
  end
end


function handleDescendantPoolReferences(pool_id, child_instances_pool_ids)
  local this_pool_descendants, i, this_child_pool_id, this_child_pool_descendant_pool_ids_key, retval, this_child_pool_descendant_pool_ids, j, descendant_pool_ids_key, this_pool_descendants_string

  this_pool_descendants = {}

  for i = 1, #child_instances_pool_ids do
    this_child_pool_id = child_instances_pool_ids[i]
    this_child_pool_descendant_pool_ids_key = _pool_key_prefix .. this_child_pool_id .. _descendant_pool_ids_key_suffix
    retval, this_child_pool_descendant_pool_ids = storeRetrieveProjectData(this_child_pool_descendant_pool_ids_key)

    table.insert(this_pool_descendants, this_child_pool_id)

    for j = 1, #this_child_pool_descendant_pool_ids do
      table.insert(this_pool_descendants, this_child_pool_descendant_pool_ids[j])
    end
  end

  this_pool_descendants = deduplicateTable(this_pool_descendants)

  descendant_pool_ids_key = _pool_key_prefix .. pool_id .. _descendant_pool_ids_key_suffix
  this_pool_descendants_string = serpent.dump(this_pool_descendants)

  storeRetrieveProjectData(descendant_pool_ids_key, this_pool_descendants_string)
end


function handleParentPoolReferencesInChildPools(active_pool_id, child_instances_pool_ids)
  local i, this_preglue_child_instance_pool_id

  for i = 1, #child_instances_pool_ids do
    this_preglue_child_instance_pool_id = child_instances_pool_ids[i]

    storeParentPoolReferencesInChildPool(this_preglue_child_instance_pool_id, active_pool_id)
  end
end


function storeParentPoolReferencesInChildPool(preglue_child_instance_pool_id, active_pool_id)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids_referenced_in_child_pool, i, this_parent_pool_id, this_parent_pool_id_is_referenced_in_child_pool

  parent_pool_ids_data_key_label = _pool_key_prefix .. preglue_child_instance_pool_id .. _parent_pool_ids_data_key_suffix
  retval, parent_pool_ids_referenced_in_child_pool = storeRetrieveProjectData(parent_pool_ids_data_key_label)

  if retval == false then
    parent_pool_ids_referenced_in_child_pool = {}

  else
    retval, parent_pool_ids_referenced_in_child_pool = serpent.load(parent_pool_ids_referenced_in_child_pool)
  end

  for i = 1, #parent_pool_ids_referenced_in_child_pool do
    this_parent_pool_id = parent_pool_ids_referenced_in_child_pool[i]
    
    if this_parent_pool_id == active_pool_id then
      this_parent_pool_id_is_referenced_in_child_pool = true
    end
  end

  if not this_parent_pool_id_is_referenced_in_child_pool then
    table.insert(parent_pool_ids_referenced_in_child_pool, active_pool_id)

    parent_pool_ids_referenced_in_child_pool = serpent.dump(parent_pool_ids_referenced_in_child_pool)

    storeRetrieveProjectData(parent_pool_ids_data_key_label, parent_pool_ids_referenced_in_child_pool)
  end
end


function handleReglue(selected_items, first_selected_item_track, restored_items_pool_id, obey_time_selection)
  local superglued_container_last_glue_params, sizing_region_guid_key_label, retval, sizing_region_guid, superglued_container, superglued_container_params

  superglued_container_last_glue_params = storeRetrieveSupergluedContainerParams(restored_items_pool_id, _postglue_action_step)
  sizing_region_guid_key_label = _pool_key_prefix .. restored_items_pool_id .. _sizing_region_guid_key_suffix
  retval, sizing_region_guid = storeRetrieveProjectData(sizing_region_guid_key_label)
  superglued_container = handleGlue(selected_items, first_selected_item_track, restored_items_pool_id, sizing_region_guid, nil, obey_time_selection)
  superglued_container_params = getSetItemParams(superglued_container)
  superglued_container_params.updated_src = getSetItemAudioSrc(superglued_container)
  superglued_container_params.pool_id = restored_items_pool_id
  superglued_container = restoreContainerState(superglued_container, superglued_container_params)

  setRegluePositionDeltas(superglued_container_params, superglued_container_last_glue_params)
  unglueAncestors(superglued_container_params.pool_id, superglued_container)
  deselectAllItems()
  propagatePoolChanges(superglued_container_params, sizing_region_guid, obey_time_selection)

  return superglued_container
end


function getSetItemAudioSrc(item, src)
  local get, set, wipe, take, source, filename, filename_is_valid

  get = not src
  set = src and src ~= "wipe"
  wipe = src == "wipe"

  if get then
    take = reaper.GetActiveTake(item)
    source = reaper.GetMediaItemTake_Source(take)
    filename = reaper.GetMediaSourceFileName(source)
    filename_is_valid = string.len(filename) > 0

    if filename_is_valid then
      return filename
    end

  elseif set then
    take = reaper.GetActiveTake(item)

    reaper.BR_SetTakeSourceFromFile2(take, src, false, true)

  elseif wipe then
    src = getSetItemAudioSrc(item)

    os.remove(src)
    os.remove(src .. _peak_data_filename_extension)
  end
end


function restoreContainerState(superglued_container, superglued_container_params)
  local superglued_container_preglue_state_key_label, retval, original_state

  superglued_container_preglue_state_key_label = _pool_key_prefix .. superglued_container_params.pool_id .. _container_preglue_state_suffix
  retval, original_state = storeRetrieveProjectData(superglued_container_preglue_state_key_label)

  if retval == true and original_state then
    getSetItemStateChunk(superglued_container, original_state)
    getSetItemAudioSrc(superglued_container, superglued_container_params.updated_src)
    getSetItemParams(superglued_container, superglued_container_params)
  end

  return superglued_container
end


function setRegluePositionDeltas(freshly_superglued_container_params, superglued_container_last_glue_params)
  local superglued_container_preedit_params, superglued_container_offset_changed_before_edit, superglued_container_offset_during_edit, superglued_container_offset

  superglued_container_preedit_params = storeRetrieveSupergluedContainerParams(freshly_superglued_container_params.pool_id, _preedit_action_step)
  freshly_superglued_container_params, superglued_container_preedit_params, superglued_container_last_glue_params = numberizeElements(
    {freshly_superglued_container_params, superglued_container_preedit_params, superglued_container_last_glue_params}, 
    {"position", "source_offset"}
  )
  superglued_container_offset_changed_before_edit = superglued_container_preedit_params.source_offset ~= 0
  superglued_container_offset_during_edit = freshly_superglued_container_params.position - superglued_container_preedit_params.position
  superglued_container_offset = freshly_superglued_container_params.position - superglued_container_preedit_params.position

  if superglued_container_offset_changed_before_edit or superglued_container_offset_during_edit then
    _superglued_instance_offset_delta_since_last_glue = round(superglued_container_preedit_params.source_offset + superglued_container_offset, 13)
  end

  if _superglued_instance_offset_delta_since_last_glue ~= 0 then
    _position_changed_since_last_glue = true
  end
end


function unglueAncestors(pool_id, superglued_container, descendant_nesting_depth_of_active_parent)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, parent_pool_ids_data_found_for_active_pool, i, this_parent_pool_id, parent_unglue_temp_track, restored_items, this_parent_instance_params, no_parent_instances_were_found

  parent_pool_ids_data_key_label = _pool_key_prefix .. pool_id .. _parent_pool_ids_data_key_suffix
  retval, parent_pool_ids = storeRetrieveProjectData(parent_pool_ids_data_key_label)
  parent_pool_ids_data_found_for_active_pool = retval == true

  if not descendant_nesting_depth_of_active_parent then
    descendant_nesting_depth_of_active_parent = 1
  end

  if parent_pool_ids_data_found_for_active_pool then
    retval, parent_pool_ids = serpent.load(parent_pool_ids)

    if #parent_pool_ids > 0 then
      reaper.Main_OnCommand(_save_time_selection_slot_5_action_id, 0)

      for i = 1, #parent_pool_ids do
        this_parent_pool_id = parent_pool_ids[i]

        if _ancestor_pools_params[this_parent_pool_id] then
          assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)

        else
          traverseAncestorsOnTempTracks(this_parent_pool_id, superglued_container, descendant_nesting_depth_of_active_parent)
        end
      end

      reaper.Main_OnCommand(_restore_time_selection_slot_5_action_id, 0)
    end
  end
end


function assignParentNestingDepth(this_parent_pool_id, descendant_nesting_depth_of_active_parent)
  _ancestor_pools_params[this_parent_pool_id].children_nesting_depth = math.max(descendant_nesting_depth_of_active_parent, _ancestor_pools_params[this_parent_pool_id].children_nesting_depth)
end


function traverseAncestorsOnTempTracks(this_parent_pool_id, superglued_container, descendant_nesting_depth_of_active_parent)
  local this_parent_is_ancestor_in_project, this_parent_instance_params, this_parent_instance_is_item_in_project, this_parent_is_ancestor_not_item_in_project, parent_unglue_temp_track, restored_items, next_nesting_depth

  this_parent_instance_params = getFirstPoolInstanceParams(this_parent_pool_id)
  this_parent_instance_is_item_in_project = this_parent_instance_params

  if not this_parent_instance_is_item_in_project then
    this_parent_is_ancestor_in_project = parentPoolIsAncestorInProject(this_parent_pool_id)

    if this_parent_is_ancestor_in_project then
      this_parent_instance_params = {}
    end
  end

  if this_parent_instance_is_item_in_project or this_parent_is_ancestor_in_project then
    this_parent_instance_params.pool_id = this_parent_pool_id
    this_parent_instance_params.children_nesting_depth = descendant_nesting_depth_of_active_parent

    reaper.InsertTrackAtIndex(0, false)

    parent_unglue_temp_track = reaper.GetTrack(_api_current_project, 0)

    deselectAllItems()

    restored_items = restoreSupergluedItems(this_parent_pool_id, parent_unglue_temp_track, superglued_container, nil, true)
    this_parent_instance_params.track = parent_unglue_temp_track
    this_parent_instance_params.restored_items = restored_items
    _ancestor_pools_params[this_parent_pool_id] = this_parent_instance_params
    next_nesting_depth = descendant_nesting_depth_of_active_parent + 1

    unglueAncestors(this_parent_pool_id, superglued_container, next_nesting_depth)
  end
end


function getFirstPoolInstanceParams(pool_id)
  local all_items_count, i, this_item, this_item_instance_pool_id, parent_instance_params

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    this_item_instance_pool_id = tonumber(this_item_instance_pool_id)

    if this_item_instance_pool_id == pool_id then
      parent_instance_params = getSetItemParams(this_item)

      return parent_instance_params
    end
  end

  return false
end


function parentPoolIsAncestorInProject(this_parent_pool_id)
  local all_items_count, all_pool_ids_in_project, i, this_item, this_item_instance_pool_id, this_pool, this_pool_descendant_pool_ids_key, retval, this_pool_descendant_pool_ids, j

  all_items_count = reaper.CountMediaItems(_api_current_project)
  all_pool_ids_in_project = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)

    if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
      table.insert(all_pool_ids_in_project, this_item_instance_pool_id)
    end
  end

  all_pool_ids_in_project = deduplicateTable(all_pool_ids_in_project)

  for i = 1, #all_pool_ids_in_project do
    this_pool = all_pool_ids_in_project[i]

    if this_pool == this_parent_pool_id then
      return true
    end

    this_pool_descendant_pool_ids_key = _pool_key_prefix .. this_pool .. _descendant_pool_ids_key_suffix
    retval, this_pool_descendant_pool_ids = storeRetrieveProjectData(this_pool_descendant_pool_ids_key)
    retval, this_pool_descendant_pool_ids = serpent.load(this_pool_descendant_pool_ids)

    for j = 1, #this_pool_descendant_pool_ids do
      this_pool_descendant_pool_id = tonumber(this_pool_descendant_pool_ids[j])

      if this_pool_descendant_pool_id == this_parent_pool_id then
        return true
      end
    end
  end

  deletePoolDescendantsData(this_parent_pool_id)
   
  return false
end


function deletePoolDescendantsData(pool_id)
  local this_parent_pool_descendant_pool_ids_key = _pool_key_prefix .. pool_id .. _descendant_pool_ids_key_suffix

  storeRetrieveProjectData(this_parent_pool_descendant_pool_ids_key, "")
end


function restoreSupergluedItems(pool_id, active_track, superglued_container, superglued_container_preedit_params, parent_is_being_updated, this_is_explode)
  local pool_item_states_key_label, retval, stored_item_states, stored_item_states_table, restored_items, superglued_container_postglue_params, item_guid, stored_item_state, restored_instances_near_project_start, restored_item, restored_instance_pool_id, this_instance_params

  pool_item_states_key_label = _pool_key_prefix .. pool_id .. _pool_contained_item_states_key_suffix
  retval, stored_item_states = storeRetrieveProjectData(pool_item_states_key_label)
  stored_item_states_table = retrieveStoredItemStates(stored_item_states)
  restored_items = {}
  superglued_container_postglue_params = storeRetrieveSupergluedContainerParams(pool_id, _postglue_action_step)

  for item_guid, stored_item_state in pairs(stored_item_states_table) do

    if stored_item_state then
      restored_instances_near_project_start, restored_item = handleRestoredItem(active_track, stored_item_state, superglued_container_preedit_params, superglued_container_postglue_params, parent_is_being_updated, this_is_explode)

      table.insert(restored_items, restored_item)
    end
  end

  for restored_instance_pool_id, this_instance_params in pairs(restored_instances_near_project_start) do
    handleInstancesNearProjectStart(superglued_container, this_instance_params)
  end

  return restored_items
end


function retrieveStoredItemStates(item_state_chunks_string)
  local retval, item_state_chunks_table

  retval, item_state_chunks_table = serpent.load(item_state_chunks_string)
  item_state_chunks_table.track = reaper.BR_GetMediaTrackByGUID(_api_current_project, item_state_chunks_table.track_guid)

  return item_state_chunks_table
end


function handleRestoredItem(active_track, stored_item_state, superglued_container_preedit_params, superglued_container_postglue_params, parent_is_being_updated, this_is_explode)
  local restored_item, restored_item_negative_position_delta, restored_instances_near_project_start, restored_instance_pool_id

  restored_item = restoreItem(active_track, stored_item_state, parent_is_being_updated, this_is_explode)
  restored_item, restored_item_negative_position_delta = adjustRestoredItem(restored_item, superglued_container_preedit_params, superglued_container_postglue_params, parent_is_being_updated)
  restored_instances_near_project_start = {}

  reaper.SetMediaItemSelected(restored_item, true)

  restored_instance_pool_id = storeRetrieveItemData(restored_item, _instance_pool_id_key_suffix)

  handleRestoredItemImage(restored_item, restored_instance_pool_id, this_is_explode)

  if restored_item_negative_position_delta then

    if not restored_instances_near_project_start[restored_instance_pool_id] then
      restored_instances_near_project_start[restored_instance_pool_id] = {
        ["item"] = restored_item,
        ["negative_position_delta"] = restored_item_negative_position_delta
      }

    elseif restored_instances_near_project_start[restored_instance_pool_id] then
      this_restored_instance_position_is_earlier_than_prev_sibling = restored_item_negative_position_delta < restored_instances_near_project_start[restored_instance_pool_id]

      if this_restored_instance_position_is_earlier_than_prev_sibling then
        restored_instances_near_project_start[restored_instance_pool_id] = {
          ["item"] = restored_item,
          ["negative_position_delta"] = restored_item_negative_position_delta
        }
      end
    end
  end

  return restored_instances_near_project_start, restored_item
end


function handleInstancesNearProjectStart(superglued_container, this_instance_params)
  local superglued_container_params, restored_instance_last_glue_delta_to_parent, this_instance_adjusted_position, this_instance_adjustment_delta, this_instance_active_take, this_instance_current_src_offset, this_instance_adjusted_src_offset

  superglued_container_params = getSetItemParams(superglued_container)
  restored_instance_last_glue_delta_to_parent = storeRetrieveItemData(this_instance_params.item, _item_offset_to_container_position_key_suffix)
  restored_instance_last_glue_delta_to_parent = tonumber(restored_instance_last_glue_delta_to_parent)
  this_instance_adjusted_position = superglued_container_params.position + restored_instance_last_glue_delta_to_parent + this_instance_params.negative_position_delta

  if this_instance_adjusted_position < -this_instance_params.negative_position_delta then
    this_instance_adjustment_delta = this_instance_adjusted_position
    this_instance_adjusted_position = 0

  else
    this_instance_adjustment_delta = this_instance_params.negative_position_delta
  end

  this_instance_active_take = reaper.GetActiveTake(this_instance_params.item)
  this_instance_current_src_offset = reaper.GetMediaItemTakeInfo_Value(this_instance_active_take, _api_take_src_offset_key)
  this_instance_adjusted_src_offset = this_instance_current_src_offset - this_instance_params.negative_position_delta

  reaper.SetMediaItemInfo_Value(this_instance_params.item, _api_item_position_key, this_instance_adjusted_position)
  reaper.SetMediaItemTakeInfo_Value(this_instance_active_take, _api_take_src_offset_key, this_instance_adjusted_src_offset)
end


function restoreItem(track, state, this_is_parent_update, this_is_explode)
  local restored_item

  restored_item = reaper.AddMediaItemToTrack(track)

  getSetItemStateChunk(restored_item, state)

  if not this_is_parent_update then
    restoreOriginalTake(restored_item)
  end

  return restored_item
end


function restoreOriginalTake(item)
  local item_takes_count, preglue_active_take_guid, preglue_active_take, preglue_active_take_num

  item_takes_count = reaper.GetMediaItemNumTakes(item)
  
  if item_takes_count > 0 then
    preglue_active_take_guid = storeRetrieveItemData(item, _preglue_active_take_guid_key_suffix)
    preglue_active_take = reaper.SNM_GetMediaItemTakeByGUID(_api_current_project, preglue_active_take_guid)

    if preglue_active_take then
      preglue_active_take_num = reaper.GetMediaItemTakeInfo_Value(preglue_active_take, _api_takenumber_key)

      if preglue_active_take_num then
        getSetItemAudioSrc(item, "wipe")
        reaper.SetMediaItemSelected(item, true)
        deleteActiveTakeFromItems()

        preglue_active_take_num = tonumber(preglue_active_take_num)
        preglue_active_take = reaper.GetTake(item, preglue_active_take_num)

        if preglue_active_take then
          reaper.SetActiveTake(preglue_active_take)
        end

        reaper.SetMediaItemSelected(item, false)
        cleanNullTakes(item)
      end
    end
  end
end


function deleteActiveTakeFromItems()
  reaper.Main_OnCommand(40129, 0)
end


function adjustRestoredItem(restored_item, superglued_container_preedit_params, superglued_container_last_glue_params, parent_is_being_updated)
  local siblings_are_being_updated, restored_item_params, adjusted_restored_item_position_is_before_project_start, restored_item_negative_position

  siblings_are_being_updated = not parent_is_being_updated
  restored_item_params = getSetItemParams(restored_item)

  if siblings_are_being_updated then
    restored_item_params.position = shiftRestoredItemPositionSinceLastGlue(restored_item_params.position, superglued_container_preedit_params, superglued_container_last_glue_params)
    adjusted_restored_item_position_is_before_project_start = restored_item_params.position < 0

    if adjusted_restored_item_position_is_before_project_start then
      restored_item_negative_position = restored_item_params.position

      return restored_item, restored_item_negative_position
    end

    reaper.SetMediaItemPosition(restored_item, restored_item_params.position, false)
  end

  return restored_item
end


function shiftRestoredItemPositionSinceLastGlue(restored_item_params_position, superglued_container_preedit_params, superglued_container_last_glue_params)
  local this_instance_delta_to_last_superglued_instance

  if not superglued_container_preedit_params or not superglued_container_preedit_params.position then
    this_instance_delta_to_last_superglued_instance = 0
  
  elseif not superglued_container_last_glue_params or not superglued_container_last_glue_params.position then
    this_instance_delta_to_last_superglued_instance = superglued_container_preedit_params.position - superglued_container_preedit_params.source_offset

  else
    this_instance_delta_to_last_superglued_instance = superglued_container_preedit_params.position - superglued_container_preedit_params.source_offset - superglued_container_last_glue_params.position
  end
  
  restored_item_params_position = restored_item_params_position + this_instance_delta_to_last_superglued_instance 

  return restored_item_params_position
end


function handleRestoredItemImage(restored_item, restored_instance_pool_id, this_is_explode)
  local this_restored_item_is_not_instance = not restored_instance_pool_id or restored_instance_pool_id == ""

  if this_is_explode then
    storeRetrieveItemData(restored_item, _parent_pool_id_key_suffix, "")

    if this_restored_item_is_not_instance then
      addRemoveItemImage(restored_item, false)
    end

  elseif this_restored_item_is_not_instance then
    addRemoveItemImage(restored_item, "restored")
  end
end


function propagatePoolChanges(active_superglued_instance_params, sizing_region_guid, obey_time_selection)
  local parent_pools_near_project_start, ancestor_pools_params_by_children_nesting_depth, i, this_parent_pool_params, this_parent_pool_id--[[, this_parent_instance_params--]], restored_items_position_adjustment

  parent_pools_near_project_start = updateActivePoolSiblings(active_superglued_instance_params)
  ancestor_pools_params_by_children_nesting_depth = sortParentUpdatesByNestingDepth()

  for i = 1, #ancestor_pools_params_by_children_nesting_depth do
    this_parent_pool_params = ancestor_pools_params_by_children_nesting_depth[i]
    this_parent_pool_id = tostring(this_parent_pool_params.pool_id)
    restored_items_position_adjustment = parent_pools_near_project_start[this_parent_pool_id]

    if restored_items_position_adjustment then
      adjustParentPoolChildren(this_parent_pool_id, active_superglued_instance_params.pool_id, restored_items_position_adjustment)

    else
      restored_items_position_adjustment = 0
    end

    reglueParentInstance(this_parent_pool_params, obey_time_selection, sizing_region_guid, restored_items_position_adjustment)
  end

  reaper.ClearPeakCache()
end


function updateActivePoolSiblings(active_superglued_instance_params, parent_is_being_updated)
  local all_items_count, siblings_are_being_updated, parent_pools_near_project_start, i, this_item, this_active_pool_sibling, attempted_negative_instance_position, this_sibling_parent_pool_id, this_sibling_position_is_earlier_than_prev_sibling

  all_items_count = reaper.CountMediaItems(_api_current_project)
  siblings_are_being_updated = not parent_is_being_updated
  parent_pools_near_project_start = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_active_pool_sibling = getActivePoolSibling(this_item, active_superglued_instance_params)

    if this_active_pool_sibling then
      getSetItemAudioSrc(this_active_pool_sibling, active_superglued_instance_params.updated_src)

      if siblings_are_being_updated then
        attempted_negative_instance_position = adjustActivePoolSibling(this_active_pool_sibling, active_superglued_instance_params)

        if attempted_negative_instance_position then
          this_sibling_parent_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)

          if not parent_pools_near_project_start[this_sibling_parent_pool_id] then
            parent_pools_near_project_start[this_sibling_parent_pool_id] = attempted_negative_instance_position

          elseif parent_pools_near_project_start[this_sibling_parent_pool_id] then
            this_sibling_position_is_earlier_than_prev_sibling = attempted_negative_instance_position < parent_pools_near_project_start[this_sibling_parent_pool_id]

            if this_sibling_position_is_earlier_than_prev_sibling then
              parent_pools_near_project_start[this_sibling_parent_pool_id] = attempted_negative_instance_position
            end
          end
        end
      end
    end
  end

  return parent_pools_near_project_start
end


function getActivePoolSibling(item, active_superglued_instance_params)
  local item_instance_pool_id, item_is_instance, item_is_active_superglued_pool_instance, instance_current_src, this_instance_needs_update

  item_instance_pool_id = storeRetrieveItemData(item, _instance_pool_id_key_suffix)
  item_is_instance = item_instance_pool_id and item_instance_pool_id ~= ""

  if item_is_instance then
    if not active_superglued_instance_params.instance_pool_id or active_superglued_instance_params.instance_pool_id == "" then
      active_superglued_instance_params.instance_pool_id = active_superglued_instance_params.pool_id
      active_superglued_instance_params.instance_pool_id = tostring(active_superglued_instance_params.instance_pool_id)
    end

    item_is_active_superglued_pool_instance = item_instance_pool_id == active_superglued_instance_params.instance_pool_id
    
    if item_is_active_superglued_pool_instance then
      instance_current_src = getSetItemAudioSrc(item)
      this_instance_needs_update = instance_current_src ~= active_superglued_instance_params.updated_src

      if this_instance_needs_update then
        return item
      end
    end
  end
end


function adjustActivePoolSibling(instance, active_superglued_instance_params)
  local instance_adjusted_length, active_instance_position_has_changed, user_wants_position_change, instance_current_position, instance_adjusted_position

  instance_adjusted_length = active_superglued_instance_params.length

  reaper.SetMediaItemLength(instance, instance_adjusted_length, false)

  active_instance_position_has_changed = not _position_change_response and _position_changed_since_last_glue == true

  if active_instance_position_has_changed then
    _position_change_response = launchPropagatePositionDialog()
  end

  user_wants_position_change = _position_change_response == _msg_response_yes

  if user_wants_position_change then
    instance_current_position = reaper.GetMediaItemInfo_Value(instance, _api_item_position_key)
    instance_adjusted_position = instance_current_position + _superglued_instance_offset_delta_since_last_glue
    
    if instance_adjusted_position >= 0 then
      reaper.SetMediaItemPosition(instance, instance_adjusted_position, false)

    else
      return instance_adjusted_position
    end
  end
end


function launchPropagatePositionDialog()
  return reaper.ShowMessageBox("Do you want to adjust other pool instances' position to match so their audio position remains the same?", "The left edge location of the superglued container item you're regluing has changed!", _msg_type_yes_no)
end


function sortParentUpdatesByNestingDepth()
  local pool_id, this_parent_instance_params, ancestor_pools_params_by_children_nesting_depth

  ancestor_pools_params_by_children_nesting_depth = {}

  for pool_id, this_parent_instance_params in pairs(_ancestor_pools_params) do
    table.insert(ancestor_pools_params_by_children_nesting_depth, this_parent_instance_params)
  end

  table.sort(ancestor_pools_params_by_children_nesting_depth, function(a, b)
    return a.children_nesting_depth < b.children_nesting_depth end
  )

  return ancestor_pools_params_by_children_nesting_depth
end


function adjustParentPoolChildren(parent_pool_id, active_pool_id, instance_position)
  local all_items_count, i, this_item, this_item_parent_pool_id, this_item_is_pool_child, this_child_instance_pool_id, this_child_is_active_sibling, this_child_current_position, this_child_adjusted_position

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_parent_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)
    this_item_is_pool_child = this_item_parent_pool_id == parent_pool_id

    if this_item_is_pool_child then
      this_child_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
      this_child_is_active_sibling = this_child_instance_pool_id == active_pool_id
      this_child_current_position = reaper.GetMediaItemInfo_Value(this_item, _api_item_position_key)

      if this_child_is_active_sibling then
        this_child_adjusted_position = this_child_current_position + _superglued_instance_offset_delta_since_last_glue - instance_position

      else
        this_child_adjusted_position = this_child_current_position - instance_position
      end

      reaper.SetMediaItemPosition(this_item, this_child_adjusted_position, false)
    end
  end
end


function reglueParentInstance(parent_instance_params, obey_time_selection, sizing_region_guid, restored_items_position_adjustment)
  local selected_items, parent_instance

  deselectAllItems()
  selectDeselectItems(parent_instance_params.restored_items, true)

  selected_items = getSelectedItems(#parent_instance_params.restored_items)
  parent_instance = handleGlue(selected_items, parent_instance_params.track, parent_instance_params.pool_id, sizing_region_guid, restored_items_position_adjustment, obey_time_selection, true)
  parent_instance_params.updated_src = getSetItemAudioSrc(parent_instance)

  deselectAllItems()
  updateActivePoolSiblings(parent_instance_params, true)
  reaper.DeleteTrack(parent_instance_params.track)
end
  

function initUnglueExplode(action)
  local selected_item_count, superglued_containers, this_pool_id, other_open_instance

  selected_item_count = initAction(action)
  superglued_containers = getSelectedSuperglueItemTypes(selected_item_count)

  if isNotSingleSupergluedContainer(#superglued_containers, action) == true then return end

  this_pool_id = storeRetrieveItemData(superglued_containers[1], _instance_pool_id_key_suffix)

  if otherInstanceIsOpen(this_pool_id) then
    other_open_instance = superglued_containers[1]

    handleOtherOpenInstance(other_open_instance, this_pool_id, action)

    return
  end
  
  handleUnglueExplode(this_pool_id, action)
end


function isNotSingleSupergluedContainer(superglued_containers_count, action)
  local multiitem_result, user_wants_to_edit_1st_container

  if superglued_containers_count == 0 then
    reaper.ShowMessageBox(_msg_change_selected_items, "Superglue can only " .. action .. " previously superglued container items." , _msg_type_ok)

    return true
  
  elseif superglued_containers_count > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to " .. action .. " the first selected superglued container item from the top track only?", "Superglue can only " .. action .. " one superglued container item per action call.", _msg_type_ok_cancel)
    user_wants_to_edit_1st_container = multiitem_result == _msg_response_ok

    if user_wants_to_edit_1st_container then
      return true
    end
  
  else
    return false
  end
end


function otherInstanceIsOpen(edit_pool_id)
  local all_items_count, i, this_item, restored_item_pool_id

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    restored_item_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)

    if restored_item_pool_id == edit_pool_id then
      return true
    end
  end
end


function handleOtherOpenInstance(instance, open_instance_pool_id, action)
  deselectAllItems()
  reaper.SetMediaItemSelected(instance, true)
  scrollToSelectedItem()

  open_instance_pool_id = tostring(open_instance_pool_id)

  reaper.ShowMessageBox("Reglue the other open instance from pool " .. open_instance_pool_id .. " before trying to " .. action .. " this superglued container item. It will be selected and scrolled to now.", "Superglue can only " .. action .. " one superglued pool instance at a time.", _msg_type_ok)
end


function scrollToSelectedItem()
  reaper.Main_OnCommand(_scroll_action_id, 0)
end


function handleUnglueExplode(pool_id, action)
  local superglued_container, undo_block_string

  superglued_container = getFirstSelectedItem()

  if action == "Unglue" then
    undo_block_string = _unglue_undo_block_string

  elseif action == "Explode" then
    undo_block_string = _explode_undo_block_string
  end

  storeRetrieveSupergluedContainerParams(pool_id, _preedit_action_step, superglued_container)
  processUnglueExplode(superglued_container, pool_id, action)
  cleanUpAction(undo_block_string)
end


function processUnglueExplode(superglued_container, pool_id, action)
  local superglued_container_preedit_params, active_track, this_is_explode, superglued_container_postglue_params

  superglued_container_preedit_params = getSetItemParams(superglued_container)

  deselectAllItems()

  active_track = reaper.BR_GetMediaTrackByGUID(_api_current_project, superglued_container_preedit_params.track_guid)

  if action == "Explode" then
    this_is_explode = true
  end

  restoreSupergluedItems(pool_id, active_track, superglued_container, superglued_container_preedit_params, nil, this_is_explode)

  if action == "Unglue" then
    createSizingRegionFromSupergluedContainer(superglued_container, pool_id)

    superglued_container_postglue_params = storeRetrieveSupergluedContainerParams(pool_id, _postglue_action_step)
  end

  reaper.DeleteTrackMediaItem(active_track, superglued_container)
end


function createSizingRegionFromSupergluedContainer(superglued_container, pool_id)
  local superglued_container_params = getSetItemParams(superglued_container)

  getSetSizingRegion(pool_id, superglued_container_params)
end


function initSmartAction(unglue_or_explode, obey_time_selection)
  local selected_item_count, pool_id
  
  selected_item_count = doPreGlueChecks()
  
  if selected_item_count == false then return end

  prepareAction("glue")
  
  if itemsAreSelected(selected_item_count) == false then return end

  pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)

  if containerSelectionIsInvalid(selected_item_count, unglue_or_explode) == true then return end

  if triggerAction(selected_item_count, unglue_or_explode, obey_time_selection) == false then 
    reaper.ShowMessageBox(_msg_change_selected_items, "Superglue Smart Action can't determine which script to run.", _msg_type_ok)
    setResetItemSelectionSet(false)

    return
  end

  reaper.Undo_EndBlock(_smart_action_undo_block_string, _api_include_all_undo_states)
end


function getSmartAction(selected_item_count)
  local superglued_containers, restored_items, noncontainers, child_instances, parent_instances, parent_instances_count, no_parent_instances_are_selected, single_parent_instance_is_selected, parent_instances_are_selected, multiple_parent_instances_are_selected, noncontainers_count, no_noncontainers_are_selected, noncontainers_are_selected, child_instances_count, no_child_instances_are_selected

  superglued_containers, restored_items, noncontainers, child_instances, parent_instances = getSelectedSuperglueItemTypes(selected_item_count)
  parent_instances_count = #parent_instances
  no_parent_instances_are_selected = parent_instances_count == 0
  single_parent_instance_is_selected = parent_instances_count == 1
  parent_instances_are_selected = parent_instances_count > 0
  multiple_parent_instances_are_selected = parent_instances_count > 1
  noncontainers_count = #noncontainers
  no_noncontainers_are_selected = noncontainers_count == 0
  noncontainers_are_selected = noncontainers_count > 0
  child_instances_count = #child_instances
  no_child_instances_are_selected = #child_instances == 0
  single_child_instance_is_selected = #child_instances == 1

  if single_parent_instance_is_selected and no_noncontainers_are_selected and no_child_instances_are_selected then
    return "unglue_or_explode"
  
  elseif parent_instances_are_selected and single_child_instance_is_selected then
    return "glue/abort"
  
  elseif (multiple_parent_instances_are_selected and no_noncontainers_are_selected and no_child_instances_are_selected) or (noncontainers_are_selected and no_child_instances_are_selected) or (no_parent_instances_are_selected and single_child_instance_is_selected) then
    return "glue"
  end
end


function triggerAction(selected_item_count, unglue_or_explode, obey_time_selection)
  local superglue_action, glue_abort_dialog

  superglue_action = getSmartAction(selected_item_count)

  if superglue_action == "unglue_or_explode" then
    initUnglueExplode(unglue_or_explode)

  elseif superglue_action == "glue" then
    initSuperglue(obey_time_selection)

  elseif superglue_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("Are you sure you want to superglue them?", "You have selected both superglued container(s) and restored item(s) from an unglued container.", _msg_type_ok_cancel)

    if glue_abort_dialog == 2 then
      setResetItemSelectionSet(false)

      return
    
    else
      initSuperglue(obey_time_selection)
    end

  else
    return false
  end
end



--- UTILITY FUNCTIONS ---

function deduplicateTable(t)
  local hash = {}
  local res = {}
  for _, v in ipairs(t) do
    if (not hash[v]) then
      res[#res+1] = v
      hash[v] = true
    end
  end
  return res
end

function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end


function numberizeElements(tables, elems)
  local i, this_table, j

  for i = 1, #tables do
    this_table = tables[i]

    for j = 1, #elems do
      this_table[elems[j]] = tonumber(this_table[elems[j]])
    end
  end

  return table.unpack(tables)
end


function round(num, precision)
   return math.floor(num*(10^precision)+0.5) / 10^precision
end