-- @description MB_Glue-Reversible Utils: Codebase for MB_Glue-Reversible scripts' functionality
-- @author MonkeyBars
-- @version 1.53
-- @changelog Rename item breaks Glue-Reversible [9] (https://github.com/MonkeyBars3k/ReaScripts/issues/3); Don't store original item state in item name (https://github.com/MonkeyBars3k/ReaScripts/issues/73); Open container item is poor UX (https://github.com/MonkeyBars3k/ReaScripts/issues/75); Update code for item state from faststrings to Reaper state chunks (https://github.com/MonkeyBars3k/ReaScripts/issues/89); Refactor nomenclature (https://github.com/MonkeyBars3k/ReaScripts/issues/115); Replace os.time() for id string with GenGUID() (https://github.com/MonkeyBars3k/ReaScripts/issues/109); Change SNM_GetSetObjectState to state chunk functions (https://github.com/MonkeyBars3k/ReaScripts/issues/120); Switch take data number to item data take GUID (https://github.com/MonkeyBars3k/ReaScripts/issues/121); Refactor: Bundle up related variables into tables (https://github.com/MonkeyBars3k/ReaScripts/issues/129); Abstract out (de)serialization (https://github.com/MonkeyBars3k/ReaScripts/issues/132); Remove extra loop in adjustRestoredItems() (https://github.com/MonkeyBars3k/ReaScripts/issues/134); Use serialization lib for dependencies storage (https://github.com/MonkeyBars3k/ReaScripts/issues/135); Extrapolate deserialized data handling (https://github.com/MonkeyBars3k/ReaScripts/issues/137); Refactor nested pool update functions (https://github.com/MonkeyBars3k/ReaScripts/issues/139); Correct parent container pool update offset logic (https://github.com/MonkeyBars3k/ReaScripts/issues/142); Check that parents exist before attempting restore+reglue (https://github.com/MonkeyBars3k/ReaScripts/issues/150); Empty spacing item breaks in item replace modes (https://github.com/MonkeyBars3k/ReaScripts/issues/151)
-- @provides [nomain] .
--   serpent.lua
--   gr-bg.png
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Glue-Reversible scripts



-- ==== GR UTILS SCRIPT NOTES ====
-- GR requires Reaper SWS plug-in extension. https://standingwaterstudios.com/
-- GR uses serpent, a serialization library for LUA, for table-string and string-table conversion. https://github.com/pkulchenko/serpent
-- GR uses Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Data is also stored in media items' P_EXT.
-- General utility functions at bottom
 

local serpent = require("serpent")


local _script_path, _item_bg_img_path, _peak_data_filename_extension, _scroll_action_id, _save_time_selection_slot_5_action_id, _restore_time_selection_slot_5_action_id, _crop_selected_items_to_time_selection_action_id, _glue_undo_block_string, _edit_undo_block_string, _smart_glue_edit_undo_block_string, _sizing_region_label, _sizing_region_color, _api_current_project, _api_data_key, _api_project_region_guid_key_prefix, _api_item_mute_key, _api_item_position_key, _api_item_length_key, _api_item_notes_key, _api_take_src_offset_key, _api_take_name_key, _api_takenumber_key, _api_null_takes_val, _global_script_prefix, _global_script_item_name_prefix, _glued_container_name_prefix, _sizing_region_guid_key_suffix, _pool_key_prefix, _pool_item_states_key_suffix, _instance_pool_id_key_suffix, _restored_item_pool_id_key_suffix, _last_pool_id_key_suffix, _preglue_active_take_guid_key_suffix, _glue_data_key_suffix, _edit_data_key_suffix, _glued_container_params_suffix, _parent_pool_ids_data_key_suffix, _child_pool_ids_data_key_suffix, _container_preglue_state_suffix, _item_offset_to_container_position_key_suffix, _postglue_action_step, _preedit_action_step, _container_name_default_prefix, _nested_item_default_name, _double_quotation_mark, _msg_type_ok, _msg_type_ok_cancel, _msg_type_yes_no, _msg_response_yes, _msg_change_selected_items, _data_storage_track, _active_glue_pool_id, _active_instance_params, _glued_instance_offset_delta_since_last_glue, _keyed_parent_instances, _numeric_parent_instances, _position_changed_since_last_glue, _position_change_response

_script_path = string.match(({reaper.get_action_context()})[2], "(.-)([^\\/]-%.?([^%.\\/]*))$")
_item_bg_img_path = _script_path .. "gr-bg.png"
_peak_data_filename_extension = ".reapeaks"
_scroll_action_id = reaper.NamedCommandLookup("_S&M_SCROLL_ITEM")
_save_time_selection_slot_5_action_id = reaper.NamedCommandLookup("_SWS_SAVETIME5")
_restore_time_selection_slot_5_action_id = reaper.NamedCommandLookup("_SWS_RESTTIME5")
_crop_selected_items_to_time_selection_action_id = reaper.NamedCommandLookup("_SWS_AWTRIMCROP")
_glue_undo_block_string = "MB_Glue-Reversible"
_edit_undo_block_string = "MB_Glue-Reversible-Edit"
_smart_glue_edit_undo_block_string = "MB_Glue-Reversible-Smart-Glue-Edit"
_sizing_region_label = "GR: DO NOT DELETE – Use to increase size – Pool #"
_sizing_region_color = reaper.ColorToNative(255, 255, 255)|0x1000000
_api_current_project = 0
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
_global_script_prefix = "GR_"
_global_script_item_name_prefix = "gr"
_glued_container_name_prefix = _global_script_item_name_prefix .. ":"
_pool_key_prefix = "pool-"
_sizing_region_guid_key_suffix = ":sizing-region-guid"
_pool_item_states_key_suffix = ":contained-item-states"
_instance_pool_id_key_suffix = "instance-pool-id"
_restored_item_pool_id_key_suffix = "parent-pool-id"
_last_pool_id_key_suffix = "last-pool-id"
_preglue_active_take_guid_key_suffix = "preglue-active-take-guid"
_glue_data_key_suffix = ":glue"
_edit_data_key_suffix = ":pre-edit"
_glued_container_params_suffix = "_glued-container-params"
_parent_pool_ids_data_key_suffix = ":parent-pool-ids"
_child_pool_ids_data_key_suffix = ":child-pool-ids"
_container_preglue_state_suffix = ":preglue-state-chunk"
_item_offset_to_container_position_key_suffix = "_glued-container-offset"
_postglue_action_step = "postglue"
_preedit_action_step = "preedit"
_container_name_default_prefix = "^" .. _global_script_item_name_prefix .. "%:%d+"
_nested_item_default_name = '%[".+%]'
_double_quotation_mark = "\u{0022}"
_msg_type_ok = 0
_msg_type_ok_cancel = 1
_msg_type_yes_no = 4
_msg_response_yes = 6
_msg_change_selected_items = "Change the items selected and try again."
_data_storage_track = reaper.GetMasterTrack(_api_current_project)
_active_glue_pool_id = nil
_active_instance_params = nil
_sizing_region_1st_display_num = 0
_glued_instance_offset_delta_since_last_glue = 0
_keyed_parent_instances = {}
_numeric_parent_instances = {}
_position_changed_since_last_glue = false
_position_change_response = nil



function initGlue(obey_time_selection)
  local selected_item_count, restored_items_pool_id, first_selected_item, first_selected_item_track, glued_container

  selected_item_count = initAction("glue")

  if selected_item_count == false then return end

  restored_items_pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)
  _active_glue_pool_id = restored_items_pool_id
  first_selected_item = getFirstSelectedItem()
  first_selected_item_track = reaper.GetMediaItemTrack(first_selected_item)

  if itemsOnMultipleTracksAreSelected(selected_item_count) == true or 
    containerSelectionIsInvalid(selected_item_count) == true or 
    pureMIDIItemsAreSelected(selected_item_count, first_selected_item_track) == true then
      return
  end

  glued_container = triggerGlue(restored_items_pool_id, first_selected_item_track, obey_time_selection)
  
  exclusiveSelectItem(glued_container)
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
    reaper.ShowMessageBox("Set an absolute path in Project Settings > Media > Path or save your new project and try again.", "Glue-Reversible needs a valid file render path.", _msg_type_ok)
    
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
    reaper.ShowMessageBox("Please install SWS at https://standingwaterstudios.com/ and try again.", "Glue-Reversible requires the SWS plugin extension to work.", _msg_type_ok)
    
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
    this_item_pool_id = storeRetrieveItemData(this_item, _restored_item_pool_id_key_suffix)
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


function getFirstSelectedItem()
  return reaper.GetSelectedMediaItem(_api_current_project, 0)
end


function itemsOnMultipleTracksAreSelected(selected_item_count)
  local items_on_multiple_tracks_are_selected = detectSelectedItemsOnMultipleTracks(selected_item_count)

  if items_on_multiple_tracks_are_selected == true then 
      reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible and Edit container item only work on items on a single track.", _msg_type_ok)
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


function containerSelectionIsInvalid(selected_item_count)
  local glued_containers, restored_items, multiple_instances_from_same_pool_are_selected, i, this_restored_item, this_restored_item_parent_pool_id, this_is_2nd_or_later_restored_item_with_pool_id, this_item_belongs_to_different_pool_than_active_edit, last_restored_item_parent_pool_id, recursive_container_is_being_glued

  glued_containers, restored_items = getSelectedGlueReversibleItems(selected_item_count)
  multiple_instances_from_same_pool_are_selected = false

  for i = 1, #restored_items do
    this_restored_item = restored_items[i]
    this_restored_item_parent_pool_id = storeRetrieveItemData(this_restored_item, _restored_item_pool_id_key_suffix)
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
  
  recursive_container_is_being_glued = recursiveContainerIsBeingGlued(glued_containers, restored_items) == true

  if recursive_container_is_being_glued then return true end

  if multiple_instances_from_same_pool_are_selected then
    reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible can only Reglue or Edit one pool instance at a time.", _msg_type_ok)
    setResetItemSelectionSet(false)

    return true
  end
end


function getSelectedGlueReversibleItems(selected_item_count)
  local glued_containers, restored_items, i, this_item

  glued_containers = {}
  restored_items = {}

  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)

    if getItemType(this_item) == "glued" then
      table.insert(glued_containers, this_item)
    elseif getItemType(this_item) == "restored" then
      table.insert(restored_items, this_item)
    end
  end

  return glued_containers, restored_items
end


function getItemType(item)
  local glued_container_pool_id, is_glued_container, restored_item_pool_id, is_restored_item
  
  glued_container_pool_id = storeRetrieveItemData(item, _instance_pool_id_key_suffix)
  is_glued_container = glued_container_pool_id and glued_container_pool_id ~= ""
  restored_item_pool_id = storeRetrieveItemData(item, _restored_item_pool_id_key_suffix)
  is_restored_item = restored_item_pool_id and restored_item_pool_id ~= ""

  if is_glued_container then
    return "glued"
  elseif is_restored_item then
    return "restored"
  else
    return "noncontained"
  end
end


function recursiveContainerIsBeingGlued(glued_containers, restored_items)
  local i, this_glued_container, this_glued_container_instance_pool_id, j, this_restored_item, this_restored_item_parent_pool_id, this_restored_item_is_from_same_pool_as_selected_glued_container

  for i = 1, #glued_containers do
    this_glued_container = glued_containers[i]
    this_glued_container_instance_pool_id = storeRetrieveItemData(this_glued_container, _instance_pool_id_key_suffix)

    for j = 1, #restored_items do
      this_restored_item = restored_items[j]
      this_restored_item_parent_pool_id = storeRetrieveItemData(this_restored_item, _restored_item_pool_id_key_suffix)
      this_restored_item_is_from_same_pool_as_selected_glued_container = this_glued_container_instance_pool_id == this_restored_item_parent_pool_id
      
      if this_restored_item_is_from_same_pool_as_selected_glued_container then
        reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible can't glue a glued container item to an instance from the same pool being Edited – or you could destroy the universe!", _msg_type_ok)
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
    reaper.ShowMessageBox("Add a virtual instrument to render audio into the glued container or try a different item selection.", "Glue-Reversible can't glue pure MIDI without a virtual instrument.", _msg_type_ok)
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


function triggerGlue(restored_items_pool_id, first_selected_item_track, obey_time_selection)
  local glued_container

  if restored_items_pool_id then
    glued_container = handleReglue(first_selected_item_track, restored_items_pool_id, obey_time_selection)
  else
    glued_container = handleGlue(first_selected_item_track, nil, nil, obey_time_selection)
  end

  return glued_container
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
  reaper.Undo_EndBlock(undo_block_string, -1)
end


function refreshUI()
  reaper.PreventUIRefresh(-1)
  reaper.UpdateTimeline()
  reaper.UpdateArrange()
  reaper.TrackList_AdjustWindows(true)
end


function handleGlue(first_selected_item_track, pool_id, sizing_region_guid, obey_time_selection, this_is_parent_glue)
  local this_is_new_glue, selected_item_count, selected_items, first_selected_item_name, parent_dummy_track, sizing_params, selected_item_states, selected_container_items, glued_container, glued_container_init_name

  this_is_new_glue = not pool_id
  selected_item_count = getSelectedItemsCount()
  selected_items, first_selected_item_name = getSelectedItems(selected_item_count)

  deselectAllItems()

  if this_is_new_glue then
    pool_id = handlePoolId()

  elseif this_is_parent_glue then
    parent_dummy_track = first_selected_item_track
    sizing_params = _active_instance_params

    for i = 1, #selected_items do
      cropItemToParent(selected_items[i], sizing_params)
    end

    createEmptySpacingItem(parent_dummy_track, sizing_params)

  elseif not this_is_parent_glue then
    sizing_params = setUpReglue(sizing_region_guid, first_selected_item_track)
  end

  selected_item_states, selected_container_items = handleSelectedItems(selected_items, pool_id, sizing_params, first_selected_item_track, this_is_parent_glue)
  glued_container = glueSelectedItemsIntoContainer(obey_time_selection)
  glued_container_init_name = handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)

  handleContainerPostGlue(glued_container, glued_container_init_name, pool_id, this_is_reglue, this_is_parent_glue)

  if not this_is_parent_glue then
    handlePoolInheritanceData(pool_id, selected_container_items)
  end

  return glued_container
end


function getSelectedItems(selected_item_count)
  local selected_items, i, this_item, first_selected_item_name

  selected_items = {}
  
  for i = 0, selected_item_count-1 do
    this_item = reaper.GetSelectedMediaItem(_api_current_project, i)

    table.insert(selected_items, this_item)

    if not first_selected_item_name then
      first_selected_item_name = getSetItemName(this_item)
    end
  end

  return selected_items, first_selected_item_name
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
  local store, retrieve, store_or_retrieve_state_data, data_param_key, retval, state_data_val

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


function setSelectedItemsData(items, pool_id, sizing_params)
  local is_new_glue, is_reglue, i, this_item, this_is_1st_item, this_item_position, first_item_position, offset_position, this_item_offset_to_glued_container_position

  is_new_glue = not sizing_params
  is_reglue = sizing_params

  for i = 1, #items do
    this_item = items[i]
    this_is_1st_item = i == 1
    this_item_position = reaper.GetMediaItemInfo_Value(this_item, _api_item_position_key)

    storeRetrieveItemData(this_item, _restored_item_pool_id_key_suffix, pool_id)

    if this_is_1st_item then
      first_item_position = this_item_position
    end

    if is_new_glue then
      offset_position = first_item_position

    elseif is_reglue then
      offset_position = math.min(first_item_position, sizing_params.position)
    end
    
    this_item_offset_to_glued_container_position = this_item_position - offset_position

    storeRetrieveItemData(this_item, _item_offset_to_container_position_key_suffix, this_item_offset_to_glued_container_position)
  end
end


function setGluedContainerName(item, item_name_ending)
  local take, new_item_name

  take = reaper.GetActiveTake(item)
  new_item_name = _glued_container_name_prefix .. item_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, _api_take_name_key, new_item_name, true)
end


function selectDeselectItems(items, select_deselect)
  local i, item

  for i = 1, #items do
    item = items[i]

    if item then 
      reaper.SetMediaItemSelected(item, select_deselect)
    end
  end
end


function setUpReglue(sizing_region_guid, active_track)
  local sizing_region_params, is_active_container_reglue

  sizing_region_params = getSetSizingRegion(sizing_region_guid)
  is_active_container_reglue = sizing_region_params

  if is_active_container_reglue then
    createEmptySpacingItem(active_track, sizing_region_params)
    getSetSizingRegion(sizing_region_guid, "delete")
  end

  return sizing_region_params
end


function createEmptySpacingItem(destination_track, sizing_params)
  local empty_spacing_item = reaper.AddMediaItemToTrack(destination_track)

  getSetItemParams(empty_spacing_item, sizing_params)
  reaper.SetMediaItemSelected(empty_spacing_item, true)
end


function handleSelectedItems(selected_items, pool_id, sizing_params, first_selected_item_track, this_is_parent_glue)
  local selected_item_states, selected_container_items, parent_instance_track, i

  setSelectedItemsData(selected_items, pool_id, sizing_params)
  
  selected_item_states, selected_container_items = createSelectedItemStates(selected_items, pool_id)

  storeSelectedItemStates(pool_id, selected_item_states)
  selectDeselectItems(selected_items, true)

  return selected_item_states, selected_container_items
end


function cropItemToParent(restored_item, this_parent_instance_params)
  local restored_item_params, restored_item_starts_before_parent, restored_item_parent_pool_id, right_hand_split_item, restored_item_ends_later_than_parent

  restored_item_params = getSetItemParams(restored_item)
  restored_item_starts_before_parent = restored_item_params.position < this_parent_instance_params.position
  restored_item_ends_later_than_parent = restored_item_params.end_point > this_parent_instance_params.end_point
  restored_item_parent_pool_id = storeRetrieveItemData(restored_item, _restored_item_pool_id_key_suffix)

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


function getSetSizingRegion(sizing_region_guid_or_pool_id, params_or_delete)
  local get_or_delete, set, retval, sizing_region_params, sizing_region_guid, region_idx, sizing_region_params
 
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


function getParamsFrom_OrDelete_SizingRegion(sizing_region_guid_or_pool_id, params_or_delete, region_idx)
  local get, delete, sizing_region_api_key, stored_guid_retval, this_region_guid, this_region_belongs_to_active_pool, sizing_region_params, retval, is_region

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
  local params, pool_id, sizing_region_name, sizing_region_label_num, retval, is_region, this_region_position, this_region_end_point, this_region_name, this_region_label_num, this_region_is_active, sizing_region_api_key, stored_guid_retval, sizing_region_guid

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


function createSelectedItemStates(selected_items, active_pool_id)
  local selected_item_states, selected_container_items, i, item, this_item, this_item_state, this_glued_container_pool_id, this_is_glued_container

  selected_item_states = {}
  selected_container_items = {}

  for i, item in ipairs(selected_items) do
    this_item = selected_items[i]
    this_glued_container_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    this_is_glued_container = this_glued_container_pool_id and this_glued_container_pool_id ~= ""

    convertMidiItemToAudio(this_item)

    this_item_state = getSetItemStateChunk(this_item)

    table.insert(selected_item_states, this_item_state)

    if this_is_glued_container then
      table.insert(selected_container_items, this_glued_container_pool_id)
    end
  end

  return selected_item_states, selected_container_items, this_glued_container_pool_id
end


function handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)
  local selected_item_count, multiple_user_items_are_selected, other_selected_items_count, is_nested_container_name, has_nested_item_name, item_name_addl_count_str, glued_container_init_name

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

  glued_container_init_name = pool_id .. " [" .. _double_quotation_mark .. first_selected_item_name .. _double_quotation_mark .. item_name_addl_count_str .. "]"

  return glued_container_init_name
end


function handleContainerPostGlue(glued_container, glued_container_init_name, pool_id, this_is_reglue, this_is_parent_glue)
  local glued_container_preglue_state_key, glued_container_state

  glued_container_preglue_state_key = _pool_key_prefix .. pool_id .. _container_preglue_state_suffix
  glued_container_state = getSetItemStateChunk(glued_container)

  setGluedContainerName(glued_container, glued_container_init_name, true)

  addRemoveItemImage(glued_container, true)
  storeRetrieveGluedContainerParams(pool_id, _postglue_action_step, glued_container)
  storeRetrieveItemData(glued_container, _instance_pool_id_key_suffix, pool_id)
  storeRetrieveItemData(glued_container, glued_container_preglue_state_key, glued_container_state)
end


function storeRetrieveGluedContainerParams(pool_id, action_step, glued_container)
  local retrieve, store, connector, glued_container_params_key_label, retval, glued_container_params

  retrieve = not glued_container
  store = glued_container
  connector = ":"
  glued_container_params_key_label = _pool_key_prefix .. pool_id .. connector .. action_step .. _glued_container_params_suffix

  if retrieve then
    retval, glued_container_params = storeRetrieveProjectData(glued_container_params_key_label)
    retval, glued_container_params = serpent.load(glued_container_params)

    if glued_container_params then
      glued_container_params.track = reaper.BR_GetMediaTrackByGUID(_api_current_project, glued_container_params.track_guid)
    end

    return glued_container_params

  elseif store then
    glued_container_params = getSetItemParams(glued_container)
    glued_container_params = serpent.dump(glued_container_params)

    storeRetrieveProjectData(glued_container_params_key_label, glued_container_params)
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
    active_take_num = reaper.GetMediaItemTakeInfo_Value(active_take, _api_takenumber_key)
    item_params = {
      ["state"] = getSetItemStateChunk(item),
      ["track_guid"] = track_guid,
      ["active_take_num"] = active_take_num,
      ["position"] = reaper.GetMediaItemInfo_Value(item, _api_item_position_key),
      ["source_offset"] = reaper.GetMediaItemTakeInfo_Value(active_take, _api_take_src_offset_key),
      ["length"] = reaper.GetMediaItemInfo_Value(item, _api_item_length_key),
    }
    item_params.end_point = item_params.position + item_params.length

    return item_params

  elseif set then
    reaper.SetMediaItemInfo_Value(item, _api_item_position_key, params.position)
    reaper.SetMediaItemInfo_Value(item, _api_item_length_key, params.length)
  end
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


function addRemoveItemImage(item, add_or_remove)
  local add, remove, img_path

  add = add_or_remove == true
  remove = add_or_remove == false

  if add then
    img_path = _item_bg_img_path
  elseif remove then
    img_path = ""
  end

  reaper.BR_SetMediaItemImageResource(item, img_path, 1)
end


function storeSelectedItemStates(pool_id, selected_item_states)
  local pool_item_states_key_label

  pool_item_states_key_label = _pool_key_prefix .. pool_id .. _pool_item_states_key_suffix
  selected_item_states = serpent.dump(selected_item_states)
  
  storeRetrieveProjectData(pool_item_states_key_label, selected_item_states)
end


function glueSelectedItemsIntoContainer(obey_time_selection)
  local glued_container

  glueSelectedItems(obey_time_selection)

  glued_container = getFirstSelectedItem()

  return glued_container
end


function glueSelectedItems(obey_time_selection)
  if obey_time_selection == true then
    reaper.Main_OnCommand(41588, 0)
  else
    reaper.Main_OnCommand(40362, 0)
  end
end


function handlePoolInheritanceData(active_pool_id, selected_container_items)
  local child_pool_ids_data_key_label, retval, old_child_pool_ids, child_pool_ids, i, this_child_pool_id, ref, this_old_child_pool_id

  child_pool_ids_data_key_label = _pool_key_prefix .. active_pool_id .. _child_pool_ids_data_key_suffix
  retval, old_child_pool_ids = storeRetrieveProjectData(child_pool_ids_data_key_label)

  if retval == false then
    old_child_pool_ids = {}
  else
    retval, old_child_pool_ids = serpent.load(old_child_pool_ids)
  end

  child_pool_ids = {}

  -- store a reference to this pool for all the nested pool_ids so if any get updated, they can check and update this pool
  for i = 1, #selected_container_items do
    this_child_pool_id = selected_container_items[i]
    child_pool_ids, old_child_pool_ids = storePoolReference(this_child_pool_id, active_pool_id, child_pool_ids, old_child_pool_ids)
  end

  -- store this pool's child_pool_ids list
  child_pool_ids = serpent.dump(child_pool_ids)
  storeRetrieveProjectData(child_pool_ids_data_key_label, child_pool_ids)

  -- have the child_pool_ids changed? - CHANGE CONDITION TO VAR child_pool_ids_have_changed?
  if #old_child_pool_ids > 0 then
    -- loop thru all the child_pool_ids no longer needed
    for i = 1,  #old_child_pool_ids do
      this_old_child_pool_id = old_child_pool_ids[i]
      -- remove this pool from the other pool_ids' parent_pool_ids list
      removeOldPoolFromParentPools(this_old_child_pool_id, active_pool_id)
    end
  end
end


function storePoolReference(child_pool_id, active_pool_id, child_pool_ids, old_child_pool_ids)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, i, this_parent_pool_id, this_parent_pool_id_is_active

  -- make a key for nested container to store which items are active_pool_id on it
  parent_pool_ids_data_key_label = _pool_key_prefix .. child_pool_id .. _parent_pool_ids_data_key_suffix
  
  -- see if nested container already has a list of parent_pool_ids
  retval, parent_pool_ids = storeRetrieveProjectData(parent_pool_ids_data_key_label)

  if retval == false then
    parent_pool_ids = {}
  else
    retval, parent_pool_ids = serpent.load(parent_pool_ids)
  end

  -- if this pool isn't already in list, add it
  for i = 1, #parent_pool_ids do
    this_parent_pool_id = parent_pool_ids[i]

    if this_parent_pool_id == active_pool_id then
      this_parent_pool_id_is_active = true

      break
    end
  end

  if not this_parent_pool_id_is_active then
    table.insert(parent_pool_ids, active_pool_id)

    parent_pool_ids = serpent.dump(parent_pool_ids)

    storeRetrieveProjectData(parent_pool_ids_data_key_label, parent_pool_ids)
  end

  -- now store this pool's child_pool_ids
  table.insert(child_pool_ids, child_pool_id)

  -- remove this child_pool_id from old_child_pool_ids
  for i = 1, #old_child_pool_ids do

    if old_child_pool_ids[i] == child_pool_id then
      table.remove(old_child_pool_ids, i)
    end
  end

  return child_pool_ids, old_child_pool_ids
end


function removeOldPoolFromParentPools(child_pool_id, parent_pool_id)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, i

  parent_pool_ids_data_key_label = _pool_key_prefix .. child_pool_id .. _parent_pool_ids_data_key_suffix
  retval, parent_pool_ids = storeRetrieveProjectData(parent_pool_ids_data_key_label)

  if retval == true then
    retval, parent_pool_ids = serpent.load(parent_pool_ids)

    for i = 1, #parent_pool_ids do

      if parent_pool_ids[i] == parent_pool_id then
        table.remove(parent_pool_ids, i)
      end
    end

    parent_pool_ids = serpent.dump(parent_pool_ids)

    storeRetrieveProjectData(parent_pool_ids_data_key_label, parent_pool_ids)
  end
end


function handleReglue(first_selected_item_track, restored_items_pool_id, obey_time_selection)
  local glued_container_last_glue_params, sizing_region_guid_key_label, retval, sizing_region_guid, glued_container, glued_container_params

  glued_container_last_glue_params = storeRetrieveGluedContainerParams(restored_items_pool_id, _postglue_action_step)
  sizing_region_guid_key_label = _pool_key_prefix .. restored_items_pool_id .. _sizing_region_guid_key_suffix
  retval, sizing_region_guid = storeRetrieveProjectData(sizing_region_guid_key_label)
  glued_container = handleGlue(first_selected_item_track, restored_items_pool_id, sizing_region_guid, obey_time_selection)
  glued_container_params = getSetItemParams(glued_container)
  glued_container_params.new_src = getSetItemAudioSrc(glued_container)
  glued_container_params.pool_id = restored_items_pool_id
  glued_container = restoreContainerState(glued_container, glued_container_params)

  setRegluePositionDeltas(glued_container_params, glued_container_last_glue_params)
  editParentInstances(glued_container_params.pool_id, glued_container)
  sortParentUpdates()
  deselectAllItems()
  propagatePoolChanges(glued_container, glued_container_params, sizing_region_guid, obey_time_selection)

  return glued_container
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


function restoreContainerState(glued_container, glued_container_params)
  local glued_container_preglue_state_key_label, retval, original_state

  glued_container_preglue_state_key_label = _pool_key_prefix .. glued_container_params.pool_id .. _container_preglue_state_suffix
  retval, original_state = storeRetrieveProjectData(glued_container_preglue_state_key_label)

  if retval == true and original_state then
    getSetItemStateChunk(glued_container, original_state)
    getSetItemAudioSrc(glued_container, glued_container_params.new_src)
    getSetItemParams(glued_container, glued_container_params)
  end

  return glued_container
end


function setRegluePositionDeltas(freshly_glued_container_params, glued_container_last_glue_params)
  local glued_container_preedit_params, glued_container_offset_changed_before_edit, glued_container_offset_during_edit, glued_container_offset

  glued_container_preedit_params = storeRetrieveGluedContainerParams(freshly_glued_container_params.pool_id, _preedit_action_step)
  freshly_glued_container_params, glued_container_preedit_params, glued_container_last_glue_params = numberizeElements(
    {freshly_glued_container_params, glued_container_preedit_params, glued_container_last_glue_params}, 
    {"position", "source_offset"}
  )
  glued_container_offset_changed_before_edit = glued_container_preedit_params.source_offset ~= 0
  glued_container_offset_during_edit = freshly_glued_container_params.position - glued_container_preedit_params.position
  glued_container_offset = freshly_glued_container_params.position - glued_container_preedit_params.position

  if glued_container_offset_changed_before_edit or glued_container_offset_during_edit then
    _glued_instance_offset_delta_since_last_glue = round(glued_container_preedit_params.source_offset + glued_container_offset, 13)
  end

  if _glued_instance_offset_delta_since_last_glue ~= 0 then
    _position_changed_since_last_glue = true
  end
end



-- populate _keyed_parent_instances with a nicely ordered sequence and reinsert the items of each pool into temp tracks so they can be updated
function editParentInstances(pool_id, glued_container, children_nesting_depth)
  local parent_pool_ids_data_key_label, retval, parent_pool_ids, i, this_parent_pool_id, track, restored_items, restored_item_position_deltas, this_parent_instance_params, no_parent_instances_were_found

  parent_pool_ids_data_key_label = _pool_key_prefix .. pool_id .. _parent_pool_ids_data_key_suffix
  retval, parent_pool_ids = storeRetrieveProjectData(parent_pool_ids_data_key_label)

  if not children_nesting_depth then
    children_nesting_depth = 1
  end

  if retval == true then
    retval, parent_pool_ids = serpent.load(parent_pool_ids)

    if #parent_pool_ids > 0 then
      reaper.Main_OnCommand(_save_time_selection_slot_5_action_id, 0)

      for i = 1, #parent_pool_ids do
        this_parent_pool_id = parent_pool_ids[i]

        -- check if an entry for this pool already exists
        if _keyed_parent_instances[this_parent_pool_id] then
          -- store how deeply nested this item is
          _keyed_parent_instances[this_parent_pool_id].children_nesting_depth = math.max(children_nesting_depth, _keyed_parent_instances[this_parent_pool_id].children_nesting_depth)

        -- this is the first time this pool has come up. set up for update loop
        else
          this_parent_instance_params = getFirstPoolInstanceParams(this_parent_pool_id)

-- REMOVE POOL FROM TABLE IF NONE FOUND HERE? -- PROBABLY NOT NECESSARY SINCE DATA GETS REFRESHED ON REGLUE
          if this_parent_instance_params then
          --   this_parent_instance_params = {}
          -- end

            this_parent_instance_params.pool_id = this_parent_pool_id
            this_parent_instance_params.children_nesting_depth = children_nesting_depth

            -- make track for this item's updates
            reaper.InsertTrackAtIndex(0, false)
            track = reaper.GetTrack(_api_current_project, 0)
            -- reaper.GetSetMediaTrackInfo_String(track, "P_EXT:SG_dummy", "true", true)
-- FOR TESTING
reaper.SetMediaTrackInfo_Value(track, "I_FREEMODE", "2", true)

            deselectAllItems()

            -- restore items into newly made empty track
            restored_items, restored_item_position_deltas = restorePreviouslyGluedItems(this_parent_pool_id, track, glued_container, this_parent_instance_params, nil, true)

            -- store references to temp track and items
            this_parent_instance_params.track = track
            this_parent_instance_params.restored_items = restored_items

            this_parent_instance_params.restored_item_position_deltas = restored_item_position_deltas

            -- store this item in _keyed_parent_instances
            _keyed_parent_instances[this_parent_pool_id] = this_parent_instance_params

            -- check if this pool also has parent_pool_ids
            editParentInstances(this_parent_pool_id, glued_container, children_nesting_depth + 1)
          end
        end
      end

      reaper.Main_OnCommand(_restore_time_selection_slot_5_action_id, 0)
    end
  end
end


function getFirstPoolInstanceParams(pool_id)
  local i, all_items_count, this_item, this_item_instance_pool_id, parent_instance_params

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)
    this_item_instance_pool_id = tonumber(this_item_instance_pool_id)

    if this_item_instance_pool_id == pool_id then
      parent_instance_params = getSetItemParams(this_item)

-- logV("getFirstPoolInstanceParams() pool_id",pool_id)
-- logV("getFirstPoolInstanceParams() parent_instance_params.length",parent_instance_params.length)

      return parent_instance_params
    end
  end

  return false
end


function restorePreviouslyGluedItems(pool_id, active_track, glued_container, this_parent_instance_params, glued_container_preedit_params, this_is_parent_update)
  local pool_item_states_key_label, retval, stored_items, stored_items_table, restored_items, glued_container_postglue_params, restored_item_position_deltas, i, stored_item_state, restored_item, this_restored_item_track_is_dummy, this_restored_item_is_child_of_pool_parent, restored_instance_pool_id, restored_item_position_delta_to_parent, restored_item_position_delta_params

  pool_item_states_key_label = _pool_key_prefix .. pool_id .. _pool_item_states_key_suffix
  retval, stored_items = storeRetrieveProjectData(pool_item_states_key_label)

  stored_items_table = retrieveStoredItemStates(stored_items)
  restored_items = {}
  glued_container_postglue_params = storeRetrieveGluedContainerParams(pool_id, _postglue_action_step)
  restored_item_position_deltas = {}

  for i = 1, #stored_items_table do
    stored_item_state = stored_items_table[i]

    if stored_item_state then
      restored_item = restoreItem(active_track, stored_item_state, this_is_parent_update)
-- Debug("PREADJUST // restorePreviouslyGluedItems()", "", 0, true)
      restored_item = adjustRestoredItem(restored_item, glued_container, this_parent_instance_params, glued_container_preedit_params, glued_container_postglue_params, this_is_parent_update)

      reaper.SetMediaItemSelected(restored_item, true)
      table.insert(restored_items, restored_item)

      restored_instance_pool_id = storeRetrieveItemData(restored_item, _instance_pool_id_key_suffix)
      restored_item_position_delta_to_parent = storeRetrieveItemData(restored_item, _item_offset_to_container_position_key_suffix)
      restored_item_position_delta_params = {
        ["pool_id"] = restored_instance_pool_id,
        ["delta_to_parent"] = restored_item_position_delta_to_parent
      }
      
      if restored_item_position_delta_to_parent and restored_item_position_delta_to_parent ~= "" then
        table.insert(restored_item_position_deltas, restored_item_position_delta_params)
      end
    end
  end


-- Debug("restorePreviouslyGluedItems()", "", 0, true)
  

  return restored_items, restored_item_position_deltas
end


function retrieveStoredItemStates(items)
  local retval, items_table

  retval, items_table = serpent.load(items)
  items_table.track = reaper.BR_GetMediaTrackByGUID(_api_current_project, items_table.track_guid)

  return items_table
end


function restoreItem(track, state, this_is_parent_update)
  local restored_item

  restored_item = reaper.AddMediaItemToTrack(track)

  getSetItemStateChunk(restored_item, state)

  if not this_is_parent_update then
    restoreOriginalTake(restored_item)
  end

  addRemoveItemImage(restored_item, true)

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


function adjustRestoredItem(restored_item, glued_container, this_parent_instance_params, glued_container_preedit_params, glued_container_last_glue_params, this_is_parent_update)
  local restored_item_params, this_restored_instance_pool_id, is_restored_child_instance, this_child_is_from_active_pool

  restored_item_params = getSetItemParams(restored_item)
  -- this_restored_instance_pool_id = storeRetrieveItemData(restored_item, _instance_pool_id_key_suffix)
  -- is_restored_child_instance = this_restored_instance_pool_id and this_restored_instance_pool_id ~= ""

  if not this_is_parent_update then
    restored_item_params.position = shiftRestoredItemPositionSinceLastGlue(restored_item_params.position, glued_container_preedit_params, glued_container_last_glue_params)
  
  elseif this_is_parent_update then
    this_restored_item_parent_pool_id = storeRetrieveItemData(restored_item, _restored_item_pool_id_key_suffix)
    this_restored_item_parent_pool_id = tonumber(this_restored_item_parent_pool_id)
    this_child_is_from_active_pool = this_restored_item_parent_pool_id == this_parent_instance_params.pool_id
    
    if this_child_is_from_active_pool then
      restored_item_offset_to_parent = storeRetrieveItemData(restored_item, _item_offset_to_container_position_key_suffix)
  -- logV("restored_item_offset_to_parent",restored_item_offset_to_parent)
      restored_item_params.position = this_parent_instance_params.position + restored_item_offset_to_parent
      -- adjustInstance(glued_container, restored_item, restored_item_params, this_parent_instance_params)
      -- cropItemToParent(restored_item, this_parent_instance_params)
    end
  end

  -- getSetItemParams(restored_item, restored_item_params)
  reaper.SetMediaItemPosition(restored_item, restored_item_params.position, false)

  return restored_item
end


function shiftRestoredItemPositionSinceLastGlue(restored_item_params_position, glued_container_preedit_params, glued_container_last_glue_params)
  local this_instance_delta_to_last_glued_instance = glued_container_preedit_params.position - glued_container_preedit_params.source_offset - glued_container_last_glue_params.position
  
  restored_item_params_position = restored_item_params_position + this_instance_delta_to_last_glued_instance 

  return restored_item_params_position
end


function sortParentUpdates()
  local k, this_parent_instance_params

  for k, this_parent_instance_params in pairs(_keyed_parent_instances) do

-- log("this_parent_instance_params")
-- logTableMediaItems(this_parent_instance_params.restored_items)

    table.insert(_numeric_parent_instances, this_parent_instance_params)
  end

  -- sort parent instances by how nested they are: convert _keyed_parent_instances to a numeric array then sort by nesting value
  table.sort( _numeric_parent_instances, function(a, b)
    return a.children_nesting_depth < b.children_nesting_depth end
  )

-- log("=====")
-- local i
-- for i = 1, #_numeric_parent_instances do
--   log("_numeric_parent_instances[i]")
--   logTableMediaItems(_numeric_parent_instances[i].restored_items)
-- end



-- logV("sortParentUpdates() _numeric_parent_instances[1].restored_items[1] type",tostring(reaper.ValidatePtr(_numeric_parent_instances[1].restored_items[1], "MediaItem*")))
-- logV("sortParentUpdates() _numeric_parent_instances[1].restored_items[2] type",tostring(reaper.ValidatePtr(_numeric_parent_instances[1].restored_items[2], "MediaItem*")))
end


function propagatePoolChanges(glued_container, glued_container_params, sizing_region_guid, obey_time_selection)
  local i

  handlePoolInstances(glued_container, glued_container_params)

  for i = 1, #_numeric_parent_instances do
     _active_instance_params = getFirstPoolInstanceParams(_numeric_parent_instances[i].pool_id)

    reglueParentInstance(_numeric_parent_instances[i], obey_time_selection, sizing_region_guid)
  end

  reaper.ClearPeakCache()
end


function handlePoolInstances(glued_container, glued_container_params)
  local all_items_count, i, this_item

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)

    updateInstance(this_item, glued_container, glued_container_params)
  end
-- Debug("POST UPDATE LOOP // updateInstance()", "", 0, true)
end


function updateInstance(instance, glued_container, glued_container_params)
  local this_instance_pool_id, this_item_is_active_pool_instance, this_instance_track, retval, this_restored_item_track_is_dummy, this_restored_item_track_is_dummy, current_src, this_instance_needs_update

  glued_container_params.pool_id = tonumber(glued_container_params.pool_id)
  this_instance_pool_id = storeRetrieveItemData(instance, _instance_pool_id_key_suffix)
  this_instance_pool_id = tonumber(this_instance_pool_id)
  this_item_is_active_pool_instance = this_instance_pool_id == glued_container_params.pool_id

-- logV("this_instance_pool_id",tostring(this_instance_pool_id))
-- logV("glued_container_params.pool_id",tostring(glued_container_params.pool_id))

  this_instance_track = reaper.GetMediaItem_Track(instance)


  -- retval, this_restored_item_track_is_dummy = reaper.GetSetMediaTrackInfo_String(this_instance_track, "P_EXT:SG_dummy", "", false)
  -- this_restored_item_is_child_of_pool_parent = this_restored_item_track_is_dummy == "true"
  -- this_instance_parent_pool_id = storeRetrieveItemData(instance, _restored_item_pool_id_key_suffix)
-- logV("this_instance_parent_pool_id",this_instance_parent_pool_id)
-- logV("glued_container_params.pool_id",glued_container_params.pool_id)
--   this_restored_item_is_child_of_pool_parent = this_instance_parent_pool_id == glued_container_params.pool_id

-- logV("this_item_is_active_pool_instance",tostring(this_item_is_active_pool_instance))
-- logV("this_restored_item_is_child_of_pool_parent",tostring(this_restored_item_is_child_of_pool_parent))

  if this_item_is_active_pool_instance then
    current_src = getSetItemAudioSrc(instance)
    this_instance_needs_update = current_src ~= glued_container_params.new_src

-- logV("handlePoolInstances() _numeric_parent_instances[1].restored_items[1] type",tostring(reaper.ValidatePtr(_numeric_parent_instances[1].restored_items[1], "MediaItem*")))
    if this_instance_needs_update --[[and not this_restored_item_is_child_of_pool_parent--]] then
-- reaper.ClearPeakCache()
-- Debug("PRE_SRC // updateInstance()", "", 0, true)
      getSetItemAudioSrc(instance, glued_container_params.new_src)
-- reaper.ClearPeakCache()
      adjustInstance(instance, glued_container, glued_container_params)
-- Debug("POST ADJUST // updateInstance()", "", 0, true)
    end
  end
-- logV("handlePoolInstances() _numeric_parent_instances[1].restored_items[1] type",tostring(reaper.ValidatePtr(_numeric_parent_instances[1].restored_items[1], "MediaItem*")))
--   if this_restored_item_is_child_of_pool_parent then
-- -- Debug("PRECROP // updateInstance()", "", 0, true)
--     cropItemToParent(instance, glued_container_params)
-- -- Debug("POSTCROP // updateInstance()", "", 0, true)
--   end
end


-- function cropInstanceToActiveGlue(instance)
--   reaper.Main_OnCommand(_save_time_selection_slot_5_action_id, 0)
--   reaper.SetMediaItemSelected(instance, true)
--   reaper.GetSet_LoopTimeRange(true, false, _active_instance_params.position, _active_instance_params.end_point, false)
--   reaper.Main_OnCommand(_crop_selected_items_to_time_selection_action_id, 0)
--   reaper.Main_OnCommand(_restore_time_selection_slot_5_action_id, 0)
-- end


function adjustInstance(instance, glued_container, glued_container_params)
  local this_instance_current_position, adjusted_pool_instance_params, user_wants_position_change, this_instance_is_parent, this_instance_is_immediate_parent, retval, this_restored_item_track_is_dummy, this_restored_item_is_child_of_pool_parent, this_instance_active_take, this_instance_track, this_instance_parent_pool_id, this_instance_position_delta_to_parent, this_instance_is_active_child, child_instances, this_parent_active_take, this_parent_current_offset, i, this_parent_adjusted_offset, child_instance_guid, active_child_instance_params, child_pool_id, child_position_delta_to_parent, this_child_is_from_active_pool, active_child_instances, current_length, this_instance_new_length, this_pool_instance_is_independent, this_pool_instance_is_parent, this_pool_instance_is_elder, this_pool_instance_is_child

  if not _position_change_response and _position_changed_since_last_glue == true then
    _position_change_response = launchPropagatePositionDialog()
  end

  user_wants_position_change = _position_change_response == _msg_response_yes
  this_instance_params = getSetItemParams(instance)
  glued_container_params.children_nesting_depth = tonumber(glued_container_params.children_nesting_depth)
  this_instance_is_parent = glued_container_params.children_nesting_depth and glued_container_params.children_nesting_depth > 0
  this_instance_parent_pool_id = storeRetrieveItemData(instance, _restored_item_pool_id_key_suffix)
  this_instance_parent_pool_id = tonumber(this_instance_parent_pool_id)
  this_item_is_child = this_instance_parent_pool_id and this_instance_parent_pool_id ~= ""
  this_pool_instance_is_independent = not this_instance_is_parent and not this_item_is_child
  this_pool_instance_is_parent = this_instance_is_parent and not this_item_is_child
  -- this_pool_instance_is_elder = this_pool_instance_is_parent and not 
  this_pool_instance_is_child = this_item_is_child
  this_instance_current_position = reaper.GetMediaItemInfo_Value(instance, _api_item_position_key)
  this_instance_active_take = reaper.GetTake(instance, this_instance_params.active_take_num)

  if this_pool_instance_is_independent then
    this_instance_params.position = this_instance_current_position + _glued_instance_offset_delta_since_last_glue
    this_instance_params.length = glued_container_params.length

    getSetItemParams(instance, this_instance_params)

  elseif this_pool_instance_is_parent then
    -- this_instance_new_length = this_instance_params.length - _glued_instance_offset_delta_since_last_glue

    -- reaper.SetMediaItemLength(instance, this_instance_new_length, false)
    -- reaper.SetMediaItemTakeInfo_Value(this_instance_active_take, _api_take_src_offset_key, -_glued_instance_offset_delta_since_last_glue)


  -- elseif this_pool_instance_is_elder then
    -- not sure if nec


  elseif this_pool_instance_is_child then
    -- reduce length by offset delta since last glue
    -- set take offset to negative offset delta since last glue?
    this_instance_params.position = this_instance_current_position + _glued_instance_offset_delta_since_last_glue
    this_instance_params.length = this_instance_params.length - _glued_instance_offset_delta_since_last_glue
-- logV("this_pool_instance_is_child",tostring(this_pool_instance_is_child))

    getSetItemParams(instance, this_instance_params)
    -- reaper.SetMediaItemLength(instance, this_instance_params.length, false)
    -- reaper.SetMediaItemTakeInfo_Value(this_instance_active_take, _api_take_src_offset_key, -_glued_instance_offset_delta_since_last_glue)
  end






--   if user_wants_position_change then
--     this_instance_is_parent = this_instance_params.children_nesting_depth and this_instance_params.children_nesting_depth > 0
--     -- this_instance_is_immediate_parent = this_instance_params.children_nesting_depth == 1
--     -- this_child_is_from_active_pool = this_instance_params.pool_id == _active_glue_pool_id
--     this_instance_active_take = reaper.GetTake(instance, this_instance_params.active_take_num)
--     -- this_instance_track = reaper.BR_GetMediaTrackByGUID(_api_current_project, this_instance_params.track_guid)
--     -- retval, this_restored_item_track_is_dummy = reaper.GetSetMediaTrackInfo_String(this_instance_track, "P_EXT:SG_dummy", "", false)
--     -- this_restored_item_is_child_of_pool_parent = this_restored_item_track_is_dummy == "true"
--     this_instance_current_position = reaper.GetMediaItemInfo_Value(instance, _api_item_position_key)

--     if not this_instance_is_parent then
--       if not this_item_is_active_pool_instance then
--       -- if this_child_is_from_active_pool then
--       -- if not this_instance_is_parent then
--         -- adjusted_pool_instance_params = {
--         --   ["position"] = this_instance_current_position + _glued_instance_offset_delta_since_last_glue,
--         --   ["length"] = this_instance_params.length
--         -- }
--         this_instance_params.position = this_instance_current_position + _glued_instance_offset_delta_since_last_glue

--         getSetItemParams(instance, this_instance_params)
--     -- Debug("adjustInstance()", "", 0, true)

--       -- end
--       elseif this_item_is_active_pool_instance then
-- -- Debug("adjustInstance() this_restored_item_is_child_of_pool_parent", "", 0, true)

--         this_instance_new_length = this_instance_params.length - _glued_instance_offset_delta_since_last_glue

--         reaper.SetMediaItemLength(instance, this_instance_params.length, false)
--         reaper.SetMediaItemTakeInfo_Value(this_instance_active_take, _api_take_src_offset_key, -_glued_instance_offset_delta_since_last_glue)
--   -- Debug("adjustInstance() _glued_instance_offset_delta_since_last_glue", _glued_instance_offset_delta_since_last_glue, 0, true)
--       end

--       -- this_instance_params.position = this_instance_current_position + _glued_instance_offset_delta_since_last_glue

--       -- logV("this_restored_item_is_child_of_pool_parent instance",tostring(reaper.ValidatePtr(instance, "MediaItem*")))
--     end
--   end
end


function launchPropagatePositionDialog()
  return reaper.ShowMessageBox("Do you want to adjust other pool instances' position to match?", "The left edge location of the container item you're regluing has changed!", _msg_type_yes_no)
end


function reglueParentInstance(parent_instance_params, obey_time_selection, sizing_region_guid)
  local parent_instance_track, parent_dummy_track, parent_instance

  deselectAllItems()
-- logV("parent_instance_params.position",parent_instance_params.position)
-- logV("parent_instance_params.end_point",parent_instance_params.end_point)
  
  -- parent_instance_track = reaper.BR_GetMediaTrackByGUID(_api_current_project, parent_instance_params.track_guid)
  parent_dummy_track = parent_instance_params.track

-- Debug("PRE EMPTY ITEM CREATION // reglueParentInstance()", "", 0, true)
  -- createEmptySpacingItem(parent_instance_track, _active_instance_params)
-- Debug("POST EMPTY ITEM CREATION // reglueParentInstance()", "", 0, true)

-- logV("reglueParentInstance() restored_items[1] type",tostring(reaper.ValidatePtr(parent_instance_params.restored_items[1], "MediaItem*")))

  selectDeselectItems(parent_instance_params.restored_items, true)

  -- log(reaper.GetMediaTrackInfo_Value(parent_instance_track, "IP_TRACKNUMBER"))
  -- log(reaper.GetMediaTrackInfo_Value(parent_dummy_track, "IP_TRACKNUMBER"))
  parent_instance = handleGlue(parent_dummy_track, parent_instance_params.pool_id, sizing_region_guid, obey_time_selection, true)
  parent_instance_params.new_src = getSetItemAudioSrc(parent_instance)
  -- parent_instance_params.length = _active_instance_params.length

  deselectAllItems()
  handlePoolInstances(parent_instance, parent_instance_params)
  reaper.DeleteTrack(parent_instance_params.track)
end
  

function initEdit()
  local selected_item_count, glued_containers, this_pool_id, other_open_instance

  selected_item_count = initAction("edit")

  if selected_item_count == false then return end

  glued_containers = getSelectedGlueReversibleItems(selected_item_count)

  if isNotSingleGluedContainer(#glued_containers) == true then return end

  this_pool_id = storeRetrieveItemData(glued_containers[1], _instance_pool_id_key_suffix)

  if otherInstanceIsOpen(this_pool_id) then
    other_open_instance = glued_containers[1]

    handleOtherOpenInstance(other_open_instance, this_pool_id)

    return
  end
  
  handleEdit(this_pool_id)
end


function isNotSingleGluedContainer(glued_containers_count)
  local multiitem_result, user_wants_to_edit_1st_container

  if glued_containers_count == 0 then
    reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible Edit can only Edit previously glued container items." , _msg_type_ok)

    return true
  
  elseif glued_containers_count > 1 then
    multiitem_result = reaper.ShowMessageBox("Would you like to Edit the first selected container item from the top track only?", "Glue-Reversible Edit can only open one glued container item per action call.", _msg_type_ok_cancel)
    user_wants_to_edit_1st_container = multiitem_result == 2

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
    restored_item_pool_id = storeRetrieveItemData(this_item, _restored_item_pool_id_key_suffix)

    if restored_item_pool_id == edit_pool_id then
      return true
    end
  end
end


function handleOtherOpenInstance(item, edit_pool_id)
  deselectAllItems()
  reaper.SetMediaItemSelected(item, true)
  scrollToSelectedItem()

  edit_pool_id = tostring(edit_pool_id)

  reaper.ShowMessageBox("Reglue the other open instance from pool " .. edit_pool_id .. " before trying to edit this glued container item. It will be selected and scrolled to now.", "Only one glued container item per pool can be Edited at a time.", _msg_type_ok)
end


function scrollToSelectedItem()
  reaper.Main_OnCommand(_scroll_action_id, 0)
end


function handleEdit(pool_id)
  local glued_container

  glued_container = getFirstSelectedItem()

  storeRetrieveGluedContainerParams(pool_id, _preedit_action_step, glued_container)
  processEdit(glued_container, pool_id)
  cleanUpAction(_edit_undo_block_string)
end


function processEdit(glued_container, pool_id)
  local glued_container_preedit_params, active_track, restored_items, glued_container_postglue_params

  glued_container_preedit_params = getSetItemParams(glued_container)

  deselectAllItems()

  active_track = reaper.BR_GetMediaTrackByGUID(_api_current_project, glued_container_preedit_params.track_guid)
  restored_items = restorePreviouslyGluedItems(pool_id, active_track, glued_container, nil, glued_container_preedit_params)
  
  createSizingRegionFromContainer(glued_container, pool_id)

  glued_container_postglue_params = storeRetrieveGluedContainerParams(pool_id, _postglue_action_step)

  reaper.DeleteTrackMediaItem(active_track, glued_container)
end


function createSizingRegionFromContainer(glued_container, pool_id)
  local glued_container_params = getSetItemParams(glued_container)

  getSetSizingRegion(pool_id, glued_container_params)
end


function initSmartAction(obey_time_selection)
  local selected_item_count, pool_id
  
  selected_item_count = doPreGlueChecks()
  
  if selected_item_count == false then return end

  prepareAction("glue")
  
  -- refresh in case item selection changed
  selected_item_count = getSelectedItemsCount()
  
  if itemsAreSelected(selected_item_count) == false then return end

  pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)

  if containerSelectionIsInvalid(selected_item_count) == true then return end

  if triggerAction(selected_item_count, obey_time_selection) == false then 
    reaper.ShowMessageBox(_msg_change_selected_items, "Glue-Reversible Smart Glue/Edit can't determine which script to run.", _msg_type_ok)
    setResetItemSelectionSet(false)

    return
  end

  reaper.Undo_EndBlock(_smart_glue_edit_undo_block_string, -1)
end


function getSmartAction(selected_item_count)
  local glued_containers, restored_items, glued_containers_count, no_glued_containers_are_selected, single_glued_container_is_selected, glued_containers_are_selected, restored_item_count, no_open_instances_are_selected, single_open_instance_is_selected, no_restored_items_are_selected, restored_items_are_selected

  glued_containers, restored_items = getSelectedGlueReversibleItems(selected_item_count)
  glued_containers_count = #glued_containers
  no_glued_containers_are_selected = glued_containers_count == 0
  single_glued_container_is_selected = glued_containers_count == 1
  glued_containers_are_selected = glued_containers_count > 0
  restored_item_count = #restored_items
  no_open_instances_are_selected = restored_item_count == 0
  single_open_instance_is_selected =restored_item_count == 1
  no_restored_items_are_selected = restored_item_count == 0
  restored_items_are_selected = restored_item_count > 0

  if single_glued_container_is_selected and no_open_instances_are_selected and no_restored_items_are_selected then
    return "edit"
  
  elseif single_open_instance_is_selected and glued_containers_are_selected then
    return "glue/abort"
  
  elseif (no_glued_containers_are_selected and single_open_instance_is_selected) or (glued_containers_are_selected and no_open_instances_are_selected) or (restored_items_are_selected and noglued_containers_are_selected and no_open_instances_are_selected) then
    return "glue"
  end
end


function triggerAction(selected_item_count, obey_time_selection)
  glue_reversible_action = getSmartAction(selected_item_count)

  if glue_reversible_action == "edit" then
    initEdit()

  elseif glue_reversible_action == "glue" then
    initGlue(obey_time_selection)

  elseif glue_reversible_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("Are you sure you want to glue them?", "You have selected both an open container and glued container(s).", _msg_type_ok_cancel)

    if glue_abort_dialog == 2 then
      setResetItemSelectionSet(false)

      return
    
    else
      initGlue(obey_time_selection)
    end

  else
    return false
  end
end




--- UTILITY FUNCTIONS ---

function getTableSize(t)
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end


function round(num, precision)
   return math.floor(num*(10^precision)+0.5) / 10^precision
end




--- DEV FUNCTIONS ---


function updateSelectedItems()
  local i
  for i = 0, reaper.CountSelectedMediaItems(0)-1 do
    reaper.UpdateItemInProject(reaper.GetMediaItem(0,i))
  end
end


function log(...)
  local arg = {...}
  local msg = "", i, v
  for i,v in ipairs(arg) do
    msg = msg..v..", "
  end
  msg = msg.."\n"
  reaper.ShowConsoleMsg(msg)
end

function logV(name, val)
  val = val or ""
  reaper.ShowConsoleMsg(name.." = "..val.."\n")
end

function logStr(val)
  reaper.ShowConsoleMsg(tostring(val)..", \n")
end

function logTable(t, name)
  local k,v
  if name then
    log("Iterate through table " .. name)
  end
  for k,v in pairs(t) do
    logV(k,tostring(v))
  end
end

function logTableMediaItems(t, name)
  local k,v
  if name then
    log("Iterate through table " .. name)
  end
  for k,v in pairs(t) do
    logV(k,tostring(reaper.ValidatePtr(v, "MediaItem*")))
  end

end



local DebugType = 0

function Debug(message, value, spacesToAdd, forceMsgBox)
updateSelectedItems()
refreshUI()
    if DebugType < 0 then return end

    local text = ""
    local a = tostring(message)
    local b = tostring(value)
    
    if message ~= nil then text = a end
    if value ~= nil then 
      if value ~= "" then text = text .. " = " .. b 
      elseif value == "" then text = text .. b
      end
    end
    
    local space = ""
    
    if spacesToAdd ~= nil and spacesToAdd > 0 then 
        for i=1, spacesToAdd do space = space .. "\n" end      
    end
    
    text = space .. text
    
    if forceMsgBox then reaper.ShowMessageBox(text, "DEBUG", 0) end
    
    if DebugType == 0 then reaper.ShowConsoleMsg(text .. "\n") return 
    elseif DebugType == 1 and not forceMsgBox then reaper.ShowMessageBox(text, "DEBUG", 0) return end

updateSelectedItems()
refreshUI()
end