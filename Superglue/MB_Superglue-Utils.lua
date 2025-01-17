-- @description MB_Superglue-Utils: Codebase for MB_Superglue scripts' functionality
-- @author MonkeyBars
-- @version 1.755
-- @changelog Add option: Toggle expand to time selection (https://github.com/MonkeyBars3k/ReaScripts/issues/186)
-- @provides [nomain] .
--   serpent.lua
--   rtk.lua
--   sg-bg-restored.png
--   sg-bg-superglued.png
-- @link Forum https://forum.cockos.com/showthread.php?t=136273
-- @about Code for Superglue scripts



-- ==== SUPERGLUE UTILS SCRIPT NOTES ====
-- Superglue requires Reaper SWS plug-in extension. https://standingwaterstudios.com/
-- Superglue uses serpent, a serialization library for LUA, for table-string and string-table conversion. https://github.com/pkulchenko/serpent
-- Superglue uses Reaper's Master Track P_EXT to store project-wide script data because its changes are saved in Reaper's undo points, a feature that functions correctly since Reaper v6.43.
-- Data is also stored in media items' P_EXT.
-- General utility functions at bottom

-- for dev only
-- require("sg-dev-functions")
 

local serpent = require("serpent")
local rtk = require('rtk')


local _script_path, _superglued_item_bg_img_path, _restored_item_bg_img_path, _peak_data_filename_extension, _scroll_action_id, _save_time_selection_slot_5_action_id, _restore_time_selection_slot_5_action_id, _crop_selected_items_to_time_selection_action_id, _glue_undo_block_string, _unglue_undo_block_string, _explode_undo_block_string, _depool_undo_block_string, _smart_action_undo_block_string, _color_undo_block_string, _reinstate_sizing_region_undo_block_string, _sizing_region_label, _sizing_region_color, _api_current_project, _api_include_all_undo_states, _api_marker_region_undo_states, _api_item_image_full_height, _api_time_value_decimal_resolution, _api_extstate_persist_enabled, _api_data_key, _api_project_region_guid_key_prefix, _api_item_mute_key, _api_item_position_key, _api_item_length_key, _api_item_notes_key, _api_item_color_key, _api_take_src_offset_key, _api_take_name_key, _api_takenumber_key, _api_null_takes_val, _global_script_prefix, _global_script_item_name_prefix, _global_options_section, _global_option_toggle_expand_to_time_selection_key, _global_option_toggle_item_images_key, _global_option_propagate_position_default_key, _global_option_toggle_sizing_region_deletion_msg_key, _global_option_toggle_depool_all_siblings_on_reglue_key, _global_option_toggle_depool_all_siblings_on_reglue_warning_key, _all_global_options_params, _separator, _superglued_container_name_prefix, _pool_key_prefix, _sizing_region_guid_key_suffix, _sizing_region_defer_loop_suffix, _pool_contained_item_states_key_suffix, _pool_parent_position_key_suffix, _pool_parent_length_key_suffix, _instance_pool_id_key_suffix, _parent_pool_id_key_suffix, _descendant_pool_ids_key_suffix, _last_pool_id_key_suffix, _preglue_active_take_guid_key_suffix, _glue_data_key_suffix, _edit_data_key_suffix, _superglued_container_params_suffix, _parent_pool_ids_data_key_suffix, _container_preglue_state_suffix, _item_offset_to_container_position_key_suffix, _postglue_action_step, _preedit_action_step, _container_name_default_prefix, _nested_item_default_name, _double_quotation_mark, _msg_type_ok, _msg_type_ok_cancel, _msg_type_yes_no, _msg_response_ok, _msg_response_yes, _msg_response_no, _msg_change_selected_items, _data_storage_track, _active_glue_pool_id, _position_start_of_project, _src_offset_reset_value, _sizing_region_1st_display_num, _sizing_region_defer_timing, _superglued_instance_offset_delta_since_last_glue, _restored_items_project_start_position_delta, _preglue_restored_item_states, _ancestor_pools_params, _position_changed_since_last_glue, _position_change_response, _user_wants_to_depool_all_siblings

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
_depool_undo_block_string = "MB_Superglue-DePool"
_smart_action_undo_block_string = "MB_Superglue-Smart-Action"
_color_undo_block_string = "MB_Superglue-Color"
_reinstate_sizing_region_undo_block_string = "MB_Superglue-Reinstate-Sizing-Region"
_sizing_region_label = "SG: DO NOT DELETE – Use to increase size – Pool #"
_sizing_region_color = reaper.ColorToNative(255, 255, 255)|0x1000000
_api_current_project = 0
_api_include_all_undo_states = -1
_api_marker_region_undo_states = 8
_api_item_image_full_height = 5
_api_time_value_decimal_resolution = 12
_api_extstate_persist_enabled = true
_api_data_key = "P_EXT:"
_api_project_region_guid_key_prefix = "MARKER_GUID:"
_api_item_mute_key = "B_MUTE"
_api_item_position_key = "D_POSITION"
_api_item_length_key = "D_LENGTH"
_api_item_notes_key = "P_NOTES"
_api_item_color_key = "I_CUSTOMCOLOR"
_api_take_src_offset_key = "D_STARTOFFS"
_api_take_name_key = "P_NAME"
_api_takenumber_key = "IP_TAKENUMBER"
_api_null_takes_val = "TAKE NULL"
_global_script_prefix = "SG_"
_global_script_item_name_prefix = "sg"
_global_options_section = "MB_SUPERGLUE-OPTIONS"
_global_option_toggle_expand_to_time_selection_key = "expand_to_time_selection_enabled"
_global_option_toggle_item_images_key = "item_images_enabled"
_global_option_propagate_position_default_key = "propagate_position_default"
_global_option_toggle_sizing_region_deletion_msg_key = "sizing_region_deletion_msg_enabled"
_global_option_toggle_depool_all_siblings_on_reglue_key = "depool_all_siblings_on_reglue_enabled"
_global_option_toggle_depool_all_siblings_on_reglue_warning_key = "depool_all_siblings_on_reglue_warning_enabled"
_all_global_options_params = {
  {
    ["name"] = "expand_to_time_selection",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_expand_to_time_selection_key,
    ["user_readable_text"] = "Expand superglue to time selection",
    ["default_value"] = "false"
  },
  {
    ["name"] = "item_images",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_item_images_key,
    ["user_readable_text"] = "Insert item background images on superglue",
    ["default_value"] = "true"
  },
  {
    ["name"] = "sizing_region_deletion_msg",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_sizing_region_deletion_msg_key,
    ["user_readable_text"] = "Prompt on deletion of Unglue sizing region (disabled = explode unglued items on sizing region deletion)",
    ["default_value"] = "true"
  },
  {
    ["name"] = "depool_all_siblings_on_reglue",
    ["type"] = "checkbox",
    ["ext_state_key"] = _global_option_toggle_depool_all_siblings_on_reglue_key,
    ["user_readable_text"] = "Remove all sibling instances from pool on Reglue (disable & undo pooling)",
    ["default_value"] = "false"
  },
  {
    ["name"] = "propagate_position_change_default",
    ["type"] = "dropdown",
    ["ext_state_key"] = _global_option_propagate_position_default_key,
    ["user_readable_text"] = "Propagate left edge position change on Reglue by default",
    ["values"] = {
      {"always", "Always propagate"},
      {"ask", "Ask"},
      {"no", "Don't propagate"}
    },
    ["default_value"] = "ask"
  }
}
_separator = ":"
_superglued_container_name_prefix = _global_script_item_name_prefix .. _separator
_pool_key_prefix = "pool-"
_sizing_region_guid_key_suffix = ":sizing-region-guid"
_sizing_region_defer_loop_suffix = "_sizing_region_loop_active"
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
_msg_response_no = 7
_msg_change_selected_items = "Change the items selected and try again."
_data_storage_track = reaper.GetMasterTrack(_api_current_project)
_active_glue_pool_id = nil
_position_start_of_project = 0
_src_offset_reset_value = 0
_sizing_region_1st_display_num = 0
_sizing_region_defer_timing = 0.5
_superglued_instance_offset_delta_since_last_glue = 0
_restored_items_project_start_position_delta = 0
_preglue_restored_item_states = nil
_ancestor_pools_params = {}
_position_changed_since_last_glue = false
_position_change_response = nil
_user_wants_to_depool_all_siblings = nil



function setDefaultOptionValues()
  local i, this_option_ext_state_key, this_option_exists_in_extstate

  for i = 1, #_all_global_options_params do
    this_option_ext_state_key = _all_global_options_params[i].ext_state_key
    this_option_exists_in_extstate = reaper.HasExtState(_global_options_section, this_option_ext_state_key)

    if not this_option_exists_in_extstate or this_option_exists_in_extstate == "nil" then
      reaper.SetExtState(_global_options_section, this_option_ext_state_key, _all_global_options_params[i].default_value, _api_extstate_persist_enabled)
    end
  end
end

setDefaultOptionValues()



function toggleOption(option_name)
  local i, active_option_idx, active_option, current_val, new_val

  for i = 1, #_all_global_options_params do

    if _all_global_options_params[i].name == option_name then
      active_option_idx = i

      break
    end
  end

  active_option = _all_global_options_params[active_option_idx]

  if not active_option then return end

  current_val = reaper.GetExtState(_global_options_section, active_option.ext_state_key)

  if current_val == "false" then
    new_val = "true"

  elseif current_val == "true" then
    new_val = "false"
  end

  reaper.SetExtState(_global_options_section, active_option.ext_state_key, new_val, true)
end


function openOptionsWindow()
  local all_option_controls, options_window, options_window_content, options_window_title, option_form_buttons, option_form_submit, option_form_cancel

  all_option_controls = {}
  options_window = rtk.Window{halign = "center"}
  options_window_content = rtk.VBox{w = 0.75, margin = "0 35 35 35"}
  options_window_title = rtk.Heading{"MB_Superglue Global Options", w = 1, margin = 35, halign = "center"}
  option_form_buttons = rtk.HBox{margin = "40 10 10 10", spacing = 10}
  option_form_submit = rtk.Button{"Submit", color = "#656565", textcolor = "#343434", elevation = 0, hover = true, gradient = 0}
  option_form_cancel = rtk.Button{"Cancel"}
  option_form_cancel.onclick = function() 
    options_window:close()
  end

  option_form_buttons:add(option_form_submit)
  option_form_buttons:add(option_form_cancel)
  options_window_content:add(options_window_title)

  all_option_controls, options_window_content = populateOptionControls(all_option_controls, options_window_content,option_form_submit)
  option_form_submit.onclick = function()
    submitOptionChanges(all_option_controls, options_window)
  end

  options_window_content:add(option_form_buttons)
  options_window:add(options_window_content)
  options_window:open{halign = "center", valign = "center"}
end


function populateOptionControls(all_option_controls, options_window_content, option_form_submit)
  local i, this_option, this_option_name

  for i = 1, #_all_global_options_params do
    this_option = _all_global_options_params[i]
    this_option_name = this_option.name

    if this_option.type == "checkbox" then
      all_option_controls[this_option_name] = getOptionCheckbox(this_option, option_form_submit)

    elseif this_option.type == "dropdown" then
      all_option_controls[this_option_name] = getOptionDropdown(this_option, option_form_submit)
    end

    options_window_content:add(all_option_controls[this_option_name])
  end

  return all_option_controls, options_window_content
end


function getOptionCheckbox(option, option_form_submit)
  local option_saved_value, checkbox_value, option_checkbox

  option_saved_value = reaper.GetExtState(_global_options_section, option.ext_state_key)

  if option_saved_value == "true" then
    checkbox_value = true
  
  else
    checkbox_value = false
  end

  option_checkbox = rtk.CheckBox{option.user_readable_text, value = checkbox_value, margin = "10 0"}
  option_checkbox.onchange = function()
    activateOptionSubmitButton(option_form_submit)
  end

  return option_checkbox
end


function activateOptionSubmitButton(submit_button)
  submit_button:attr("color", rtk.Attribute.DEFAULT):attr("textcolor", rtk.Attribute.DEFAULT):attr("elevation", rtk.Attribute.DEFAULT):attr("hover", rtk.Attribute.DEFAULT):attr("gradient", rtk.Attribute.DEFAULT)
end


function getOptionDropdown(option, option_form_submit)
  local option_saved_value, option_dropdown_box, dropdown_label, dropdown_control, dropdown_menu, i, this_option_value, this_option_value_menu_item

  option_saved_value = reaper.GetExtState(_global_options_section, option.ext_state_key)
  option_dropdown_box = rtk.HBox{spacing = 10}
  dropdown_label = rtk.Text{option.user_readable_text, margin = "15 0 5", wrap = "wrap_normal"}
  dropdown_control = rtk.OptionMenu{margin = "15 0 5"}
  dropdown_menu = {}

  for i = 1, #option.values do
    this_option_value = option.values[i]
    this_option_value_menu_item = {this_option_value[2], id = this_option_value[1]}

    table.insert(dropdown_menu, this_option_value_menu_item)
  end

  dropdown_control:attr("menu", dropdown_menu)
  dropdown_control:select(option_saved_value)

  dropdown_control.onchange = function()
    activateOptionSubmitButton(option_form_submit)
  end
  
  option_dropdown_box:add(dropdown_control)
  option_dropdown_box:add(dropdown_label)

  return option_dropdown_box
end


function submitOptionChanges(all_option_controls, options_window)
  local i, this_option, this_option_saved_value, this_option_form_value, dropdown

  for i = 1, #_all_global_options_params do
    this_option = _all_global_options_params[i]
    this_option_saved_value = reaper.GetExtState(_global_options_section, this_option.ext_state_key)

    if this_option.type == "checkbox" then
      this_option_form_value = tostring(all_option_controls[this_option.name].value)

    elseif this_option.type == "dropdown" then
      dropdown = all_option_controls[this_option.name]:get_child(1)
      this_option_form_value = dropdown.selected
    end

    if this_option_form_value ~= this_option_saved_value then
      reaper.SetExtState(_global_options_section, this_option.ext_state_key, this_option_form_value, _api_extstate_persist_enabled)

      -- reset depool all siblings warning
      if this_option.ext_state_key == _global_option_toggle_depool_all_siblings_on_reglue_key then
        reaper.SetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_warning_key, "true", _api_extstate_persist_enabled)
      end
    end
  end

  options_window:close()
end


function openContainerItemInfoWindow()
  local selected_item_count, selected_container_item

  selected_item_count = reaper.CountSelectedMediaItems(_api_current_project)

  if selected_item_count == false then return end

  if selected_item_count > 1 then
    reaper.ShowMessageBox("Select only one item and try again.", "You have more than one item selected.", _msg_type_ok)

    return
  end

  selected_container_item = reaper.GetSelectedMediaItem(_api_current_project, 0)
  selected_container_instance_pool_id = storeRetrieveItemData(selected_container_item, _instance_pool_id_key_suffix)

  if not selected_container_instance_pool_id or selected_container_instance_pool_id == "" then
    reaper.ShowMessageBox("Select a superglued container item and try again.", "The item selected is not a superglued container item.", _msg_type_ok)

    return
  end

  handleContainerItemInfoWindow(selected_container_item, selected_container_instance_pool_id)
end


function handleContainerItemInfoWindow(selected_container_item, selected_container_instance_pool_id)
  local selected_container_parent_pool_id, selected_container_descendant_pool_ids_key, retval, selected_container_descendant_pool_ids, selected_container_descendant_pool_ids_list, selected_container_item_params

  selected_container_parent_pool_id = storeRetrieveItemData(selected_container_item, _parent_pool_id_key_suffix)
  selected_container_descendant_pool_ids_key = _pool_key_prefix .. selected_container_instance_pool_id .. _descendant_pool_ids_key_suffix
  retval, selected_container_descendant_pool_ids = storeRetrieveProjectData(selected_container_descendant_pool_ids_key)
  retval, selected_container_descendant_pool_ids = serpent.load(selected_container_descendant_pool_ids)
  selected_container_descendant_pool_ids_list = stringifyArray(selected_container_descendant_pool_ids)
  
  if not selected_container_parent_pool_id or selected_container_parent_pool_id == "" then
    selected_container_parent_pool_id = "none"
  end

  selected_container_item_params = {
    {
      "Pool ID: ",
      selected_container_instance_pool_id
    },
    {
      "Parent Pool ID: ",
      selected_container_parent_pool_id
    },
    {
      "Descendant Pool IDs: ",
      selected_container_descendant_pool_ids_list
    }
  }

  populateContainerItemWindow(selected_container_item, selected_container_item_params)
end


function populateContainerItemWindow(selected_container_item, selected_container_item_params)
  local item_info_window, item_info_content, item_info_title, item_info, item_info_text

  item_info_window = rtk.Window{halign = "center"}
  item_info_content = rtk.VBox{w = 0.75, margin = "0 35 35 35"}
  item_info_title = rtk.Heading{"MB_Superglue Container Item Info", w = 1, margin = 35, halign = "center"}
  item_info_name = rtk.Text{getSetItemName(selected_container_item), w = 1, halign = "center", textalign = "center", bmargin = 20, fontscale = 1.3, wrap = "wrap_normal"}
  item_info = ""

  for i = 1, #selected_container_item_params do
    item_info = item_info .. selected_container_item_params[i][1] .. selected_container_item_params[i][2] .. "\n"
  end
  
  item_info_text = rtk.Text{item_info, wrap = "wrap_normal", spacing = 13}

  item_info_content:add(item_info_title)
  item_info_content:add(item_info_name)
  item_info_content:add(item_info_text)
  item_info_window:add(item_info_content)
  item_info_window:open{halign = "center", valign = "center"}
end


function initSuperglue()
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

  superglued_container = triggerSuperglue(selected_items, restored_items_pool_id, first_selected_item_track, selected_items)
  
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
  local selected_item_groups, superglued_containers, restored_items, multiple_instances_from_same_pool_are_selected, i, this_restored_item, this_restored_item_parent_pool_id, this_is_2nd_or_later_restored_item_with_pool_id, this_item_belongs_to_different_pool_than_active_edit, last_restored_item_parent_pool_id, recursive_container_is_being_glued

  selected_item_groups = getSelectedSuperglueItemTypes(selected_item_count, {"superglued", "restored"})
  superglued_containers = selected_item_groups["superglued"]["selected_items"]
  restored_items = selected_item_groups["restored"]["selected_items"]
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


function getSelectedSuperglueItemTypes(selected_item_count, requested_types)
  local item_types, item_types_data, i, this_item_type, this_item, superglued_container_pool_id, restored_item_pool_id, j, this_requested_item_type

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

    for j = 1, #requested_types do
      this_requested_item_type = requested_types[j]
      
      if item_types_data[this_requested_item_type]["is"] then
        table.insert(item_types_data[this_requested_item_type]["selected_items"], this_item)
      end
    end
  end

  return item_types_data
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


function triggerSuperglue(selected_items, restored_items_pool_id, first_selected_item_track)
  local superglued_container

  if restored_items_pool_id then
    superglued_container = handleReglue(selected_items, first_selected_item_track, restored_items_pool_id)
  else
    superglued_container = handleGlue(selected_items, first_selected_item_track, nil, nil, nil, nil)
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


function handleGlue(selected_items, first_selected_item_track, pool_id, sizing_region_guid, restored_items_position_adjustment, depool_container_params, this_is_parent_update)
  local this_is_new_glue, this_is_depool, this_is_reglue, first_selected_item, first_selected_item_name, sizing_params, time_selection_was_set_by_code, global_option_toggle_depool_all_siblings_on_reglue, pool_contained_item_states_key, retval, selected_item_states, selected_instances_pool_ids, earliest_item_delta_to_superglued_container_position, superglued_container

  this_is_new_glue = not pool_id
  this_is_depool = depool_container_params
  this_is_reglue = pool_id
  first_selected_item = getFirstSelectedItem()
  first_selected_item_name = getSetItemName(first_selected_item)

  deselectAllItems()

  if this_is_new_glue then
    pool_id = handlePoolId()

    if this_is_depool then
      sizing_params, time_selection_was_set_by_code = setUpDePool(depool_container_params)
    end

  elseif this_is_reglue then
    sizing_params, time_selection_was_set_by_code = setUpReglue(this_is_parent_update, first_selected_item_track, pool_id, restored_items_position_adjustment, sizing_region_guid, selected_items)
    global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_key)

    if global_option_toggle_depool_all_siblings_on_reglue then  
      pool_contained_item_states_key = _pool_key_prefix .. pool_id .. _pool_contained_item_states_key_suffix
      retval, _preglue_restored_item_states = storeRetrieveProjectData(pool_contained_item_states_key)
    end
  end

  selected_item_states, selected_instances_pool_ids, earliest_item_delta_to_superglued_container_position = handlePreglueItems(selected_items, pool_id, sizing_params, first_selected_item_track, this_is_parent_update)
  superglued_container = glueSelectedItemsIntoContainer()

  handlePostGlue(selected_items, pool_id, first_selected_item_name, superglued_container, earliest_item_delta_to_superglued_container_position, selected_instances_pool_ids, sizing_params, this_is_reglue, this_is_parent_update, time_selection_was_set_by_code)

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


function setUpReglue(this_is_parent_update, first_selected_item_track, pool_id, restored_items_position_adjustment, sizing_region_guid, selected_items)
  local obey_time_selection, user_selected_instance_is_being_reglued

  obey_time_selection = reaper.GetExtState(_global_options_section, _global_option_toggle_expand_to_time_selection_key)
  user_selected_instance_is_being_reglued = not this_is_parent_update

  if this_is_parent_update then
    return setUpParentUpdate(first_selected_item_track, pool_id, restored_items_position_adjustment, obey_time_selection)

  elseif user_selected_instance_is_being_reglued then
    return setUpUserSelectedInstanceReglue(sizing_region_guid, first_selected_item_track, selected_items, pool_id, obey_time_selection)
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

  if obey_time_selection == "false" then
    setResetGlueTimeSelection(sizing_params, "set")

    time_selection_was_set_by_code = true
  end

  return sizing_params, time_selection_was_set_by_code
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


function setUpUserSelectedInstanceReglue(sizing_region_guid, active_track, selected_items, pool_id, obey_time_selection)
  local sizing_params, is_active_container_reglue, time_selection_start, time_selection_end, no_time_selection_exists, time_selection_was_set_by_code, sizing_region_defer_loop_is_active_key

  sizing_params = getSetSizingRegion(sizing_region_guid)
  is_active_container_reglue = sizing_params
  time_selection_start, time_selection_end = reaper.GetSet_LoopTimeRange(false, false, nil, nil, false)
  no_time_selection_exists = time_selection_end == 0
  time_selection_was_set_by_code = false
  sizing_region_defer_loop_is_active_key = _pool_key_prefix .. pool_id .. _sizing_region_defer_loop_suffix

  if is_active_container_reglue then
    if obey_time_selection == "false" or (obey_time_selection == "true" and no_time_selection_exists) then
      sizing_params = calculateSizingTimeSelection(selected_items, sizing_params)

      setResetGlueTimeSelection(sizing_params, "set")

      time_selection_was_set_by_code = true
    end

    storeRetrieveProjectData(sizing_region_defer_loop_is_active_key, "false")
    getSetSizingRegion(sizing_region_guid, "delete")
  end

  return sizing_params, time_selection_was_set_by_code
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


function setUpDePool(depool_container_params)
  local sizing_params, time_selection_was_set_by_code

  sizing_params = {
    ["position"] = depool_container_params.position,
    ["end_point"] = depool_container_params.end_point
  }
  time_selection_was_set_by_code = true

  setResetGlueTimeSelection(sizing_params, "set")

  return sizing_params, time_selection_was_set_by_code
end


function handlePreglueItems(selected_items, pool_id, sizing_params, first_selected_item_track, this_is_parent_update)
  local earliest_item_delta_to_superglued_container_position, selected_item_states, selected_instances_pool_ids, i

  earliest_item_delta_to_superglued_container_position = setPreglueItemsData(selected_items, pool_id, sizing_params)
  selected_item_states, selected_instances_pool_ids = getSelectedItemStates(selected_items, pool_id)

  storeSelectedItemStates(pool_id, selected_item_states)
  selectDeselectItems(selected_items, true)

  if this_is_parent_update then

    for i = 1, #selected_items do
      cropItemToSizingParams(selected_items[i], sizing_params, first_selected_item_track)
    end
  end

  return selected_item_states, selected_instances_pool_ids, earliest_item_delta_to_superglued_container_position
end


function setPreglueItemsData(preglue_items, pool_id, sizing_params)
  local this_is_new_glue, this_is_reglue_or_depool, earliest_item_delta_to_superglued_container_position, i, this_item, this_is_1st_item, this_item_position, first_item_position, offset_position, this_item_delta_to_superglued_container_position

  this_is_new_glue = not sizing_params
  this_is_reglue_or_depool = sizing_params
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

    elseif this_is_reglue_or_depool then
      offset_position = math.min(first_item_position, sizing_params.position)
    end
    
    this_item_delta_to_superglued_container_position = this_item_position - offset_position
    earliest_item_delta_to_superglued_container_position = math.min(earliest_item_delta_to_superglued_container_position, this_item_delta_to_superglued_container_position)

    storeRetrieveItemData(this_item, _item_offset_to_container_position_key_suffix, this_item_delta_to_superglued_container_position)
  end

  return earliest_item_delta_to_superglued_container_position
end


function getSelectedItemStates(selected_items, active_pool_id)
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


function storeSelectedItemStates(pool_id, selected_item_states)
  local pool_item_states_key_label

  pool_item_states_key_label = _pool_key_prefix .. pool_id .. _pool_contained_item_states_key_suffix
  selected_item_states = serpent.dump(selected_item_states)
  
  storeRetrieveProjectData(pool_item_states_key_label, selected_item_states)
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


function cropItemToSizingParams(restored_item, sizing_item_params, active_track)
  local restored_item_params, restored_item_starts_before_parent, restored_item_ends_later_than_parent, restored_item_parent_pool_id, right_hand_split_item, restored_item_cropped_position_delta, restored_item_active_take, restored_vs_sizing_item_length_delta, restored_item_new_length, end_point_delta

  restored_item_params = getSetItemParams(restored_item)
  restored_item_starts_before_parent = round(restored_item_params.position, _api_time_value_decimal_resolution) < round(sizing_item_params.position, _api_time_value_decimal_resolution)
  restored_item_ends_later_than_parent = round(restored_item_params.end_point, _api_time_value_decimal_resolution) > round(sizing_item_params.end_point, _api_time_value_decimal_resolution)
  restored_item_parent_pool_id = storeRetrieveItemData(restored_item, _parent_pool_id_key_suffix)

  if restored_item_starts_before_parent then
    restored_item_cropped_position_delta = sizing_item_params.position - restored_item_params.position
    restored_item_active_take = reaper.GetTake(restored_item, restored_item_params.active_take_num)

    reaper.SetMediaItemPosition(restored_item, sizing_item_params.position, true)
    reaper.SetMediaItemTakeInfo_Value(restored_item_active_take, _api_take_src_offset_key, restored_item_cropped_position_delta)

    restored_item_params.length = reaper.GetMediaItemInfo_Value(restored_item, _api_item_length_key)
    restored_vs_sizing_item_length_delta = restored_item_params.length - sizing_item_params.length
    
    if restored_vs_sizing_item_length_delta > 0 then
      restored_item_new_length = restored_item_params.length - restored_vs_sizing_item_length_delta
      
      reaper.SetMediaItemLength(restored_item, restored_item_new_length, false)
    end
  end

  if restored_item_ends_later_than_parent then
    end_point_delta = restored_item_params.end_point - sizing_item_params.end_point
    restored_item_new_length = restored_item_params.length - end_point_delta
    
    reaper.SetMediaItemLength(restored_item, restored_item_new_length, false)
  end
end


function glueSelectedItemsIntoContainer()
  local superglued_container

  glueSelectedItemsToTimeSelection()

  superglued_container = getFirstSelectedItem()

  return superglued_container
end


function glueSelectedItemsToTimeSelection()
  reaper.Main_OnCommand(41588, 0)
end


function handlePostGlue(selected_items, pool_id, first_selected_item_name, superglued_container, earliest_item_delta_to_superglued_container_position, child_instances_pool_ids, sizing_params, this_is_reglue, this_is_parent_update, time_selection_was_set_by_code)
  local user_selected_instance_is_being_reglued, superglued_container_init_name

  user_selected_instance_is_being_reglued = not this_is_parent_update
  superglued_container_init_name = handleAddtionalItemCountLabel(selected_items, pool_id, first_selected_item_name)

  handleSupergluedContainerPostGlue(superglued_container, superglued_container_init_name, pool_id, earliest_item_delta_to_superglued_container_position, this_is_reglue, this_is_parent_update)
  handleDescendantPoolReferences(pool_id, child_instances_pool_ids)

  if user_selected_instance_is_being_reglued then
    handleParentPoolReferencesInChildPools(pool_id, child_instances_pool_ids)
  end

  if time_selection_was_set_by_code then
    setResetGlueTimeSelection(sizing_params, "reset")
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


function handleSupergluedContainerPostGlue(superglued_container, superglued_container_init_name, pool_id, earliest_item_delta_to_superglued_container_position, this_is_reglue, this_is_parent_update)
  local superglued_container_preglue_state_key_suffix, superglued_container_state, pool_parent_position_key_label, pool_parent_length_key_label, pool_parent_params

  superglued_container_state = getSetItemStateChunk(superglued_container)
  pool_parent_position_key_label = _pool_key_prefix .. pool_id .. _pool_parent_position_key_suffix
  pool_parent_length_key_label = _pool_key_prefix .. pool_id .. _pool_parent_length_key_suffix
  pool_parent_params = getSetItemParams(superglued_container)

  setGluedContainerName(superglued_container, superglued_container_init_name, true)
  addRemoveItemImage(superglued_container, "superglued")
  storeRetrieveSupergluedContainerParams(pool_id, _postglue_action_step, superglued_container)
  storeRetrieveItemData(superglued_container, _instance_pool_id_key_suffix, pool_id)
  storeRetrieveProjectData(pool_parent_position_key_label, pool_parent_params.position)
  storeRetrieveProjectData(pool_parent_length_key_label, pool_parent_params.length)
end


function setGluedContainerName(item, item_name_ending)
  local take, new_item_name

  take = reaper.GetActiveTake(item)
  new_item_name = _superglued_container_name_prefix .. item_name_ending

  reaper.GetSetMediaItemTakeInfo_String(take, _api_take_name_key, new_item_name, true)
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
  local item_images_are_enabled = reaper.GetExtState(_global_options_section, _global_option_toggle_item_images_key) == "true"

  if item_images_are_enabled then
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

    reaper.BR_SetMediaItemImageResource(item, img_path, _api_item_image_full_height)
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


function handleReglue(selected_items, first_selected_item_track, restored_items_pool_id)
  local superglued_container_last_glue_params, sizing_region_guid_key_label, retval, sizing_region_guid, superglued_container, superglued_container_params

  cleanUnselectedRestoredItemsFromPool(restored_items_pool_id)

  superglued_container_last_glue_params = storeRetrieveSupergluedContainerParams(restored_items_pool_id, _postglue_action_step)
  sizing_region_guid_key_label = _pool_key_prefix .. restored_items_pool_id .. _sizing_region_guid_key_suffix
  retval, sizing_region_guid = storeRetrieveProjectData(sizing_region_guid_key_label)
  superglued_container = handleGlue(selected_items, first_selected_item_track, restored_items_pool_id, sizing_region_guid, nil, nil)
  superglued_container_params = getSetItemParams(superglued_container)
  superglued_container_params.updated_src = getSetItemAudioSrc(superglued_container)
  superglued_container_params.pool_id = restored_items_pool_id
  superglued_container = restoreContainerState(superglued_container, superglued_container_params)

  setRegluePositionDeltas(superglued_container_params, superglued_container_last_glue_params)
  adjustPostGlueTakeEnvelopes(superglued_container)
  unglueAncestors(superglued_container_params.pool_id, superglued_container)
  deselectAllItems()
  propagatePoolChanges(superglued_container_params, sizing_region_guid)

  return superglued_container
end


function cleanUnselectedRestoredItemsFromPool(pool_id)
  local all_items_count, i, this_item, this_item_is_selected, this_item_parent_pool_id

  all_items_count = reaper.CountMediaItems(_api_current_project)

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_item_is_selected = reaper.IsMediaItemSelected(this_item)

    if not this_item_is_selected then
      this_item_parent_pool_id = storeRetrieveItemData(this_item, _parent_pool_id_key_suffix)

      if this_item_parent_pool_id == pool_id then
        storeRetrieveItemData(this_item, _parent_pool_id_key_suffix, "")
        addRemoveItemImage(this_item, false)
      end
    end
  end
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
  local superglued_container_preglue_state_key_label, retval, superglued_container_last_glue_state, active_take

  superglued_container_preglue_state_key_label = _pool_key_prefix .. superglued_container_params.pool_id .. _container_preglue_state_suffix
  retval, superglued_container_last_glue_state = storeRetrieveProjectData(superglued_container_preglue_state_key_label)
  active_take = reaper.GetActiveTake(superglued_container)

  if retval == true and superglued_container_last_glue_state then
    getSetItemStateChunk(superglued_container, superglued_container_last_glue_state)
    getSetItemAudioSrc(superglued_container, superglued_container_params.updated_src)
    getSetItemParams(superglued_container, superglued_container_params)
    reaper.SetMediaItemTakeInfo_Value(active_take, _api_take_src_offset_key, _src_offset_reset_value)
  end

  return superglued_container
end


function setRegluePositionDeltas(freshly_superglued_container_params, superglued_container_last_glue_params)
  local superglued_container_preedit_params, superglued_container_offset_changed_before_edit, superglued_container_offset_during_edit, superglued_container_offset_changed_during_edit, superglued_container_offset

  superglued_container_preedit_params = storeRetrieveSupergluedContainerParams(freshly_superglued_container_params.pool_id, _preedit_action_step)
  freshly_superglued_container_params, superglued_container_preedit_params, superglued_container_last_glue_params = numberizeElements(
    {freshly_superglued_container_params, superglued_container_preedit_params, superglued_container_last_glue_params}, 
    {"position", "source_offset"}
  )
  superglued_container_offset_changed_before_edit = superglued_container_preedit_params.source_offset ~= 0
  superglued_container_offset_during_edit = freshly_superglued_container_params.position - superglued_container_preedit_params.position
  superglued_container_offset_changed_during_edit = superglued_container_offset_during_edit ~= 0
  superglued_container_offset = freshly_superglued_container_params.position - superglued_container_preedit_params.position

  if superglued_container_offset_changed_before_edit or superglued_container_offset_changed_during_edit then
    _superglued_instance_offset_delta_since_last_glue = round(superglued_container_preedit_params.source_offset + superglued_container_offset, _api_time_value_decimal_resolution)
  end

  if _superglued_instance_offset_delta_since_last_glue ~= 0 then
    _position_changed_since_last_glue = true
  end
end


function adjustPostGlueTakeEnvelopes(instance)
  local instance_active_take, take_envelopes_count, i, this_take_envelope, envelope_points_count, j, retval, this_envelope_point_time, adjusted_envelope_point_time

  instance_active_take = reaper.GetActiveTake(instance)
  take_envelopes_count = reaper.CountTakeEnvelopes(instance_active_take)

  for i = 0, take_envelopes_count-1 do
    this_take_envelope = reaper.GetTakeEnvelope(instance_active_take, i)
    envelope_points_count = reaper.CountEnvelopePoints(this_take_envelope)

    for j = 0, envelope_points_count-1 do
      retval, this_envelope_point_time = reaper.GetEnvelopePoint(this_take_envelope, j)
      adjusted_envelope_point_time = this_envelope_point_time - _superglued_instance_offset_delta_since_last_glue

      reaper.SetEnvelopePoint(this_take_envelope, j, adjusted_envelope_point_time, nil, nil, nil, nil, true)
    end
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

    restored_items = restoreContainedItems(this_parent_pool_id, parent_unglue_temp_track, superglued_container, nil, true)
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


function restoreContainedItems(pool_id, active_track, superglued_container, superglued_container_preedit_params, this_is_parent_update, this_is_explode)
  local retval, stored_item_states_table, pool_item_states_key_label, stored_item_states, restored_items, superglued_container_postglue_params, item_guid, stored_item_state, restored_instances_near_project_start, restored_item, restored_instance_pool_id, this_instance_params

  if this_is_explode and _preglue_restored_item_states then
    retval, stored_item_states_table = serpent.load(_preglue_restored_item_states)

  else
    pool_item_states_key_label = _pool_key_prefix .. pool_id .. _pool_contained_item_states_key_suffix
    retval, stored_item_states = storeRetrieveProjectData(pool_item_states_key_label)
    stored_item_states_table = retrieveStoredItemStates(stored_item_states)
  end

  restored_items = {}
  superglued_container_postglue_params = storeRetrieveSupergluedContainerParams(pool_id, _postglue_action_step)

  for item_guid, stored_item_state in pairs(stored_item_states_table) do

    if stored_item_state then
      restored_instances_near_project_start, restored_item = handleRestoredItem(active_track, stored_item_state, superglued_container_preedit_params, superglued_container_postglue_params, this_is_parent_update, this_is_explode)

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


function handleRestoredItem(active_track, stored_item_state, superglued_container_preedit_params, superglued_container_postglue_params, this_is_parent_update, this_is_explode)
  local restored_item, restored_item_negative_position_delta, restored_instances_near_project_start, restored_instance_pool_id

  restored_item = restoreItem(active_track, stored_item_state, this_is_parent_update, this_is_explode)
  restored_item, restored_item_negative_position_delta = adjustRestoredItem(restored_item, superglued_container_preedit_params, superglued_container_postglue_params, this_is_parent_update)
  restored_instances_near_project_start = {}

  reaper.SetMediaItemSelected(restored_item, true)

  restored_instance_pool_id = storeRetrieveItemData(restored_item, _instance_pool_id_key_suffix)

  if this_is_explode then
    storeRetrieveItemData(restored_item, _parent_pool_id_key_suffix, "")
  end

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


function adjustRestoredItem(restored_item, superglued_container_preedit_params, superglued_container_last_glue_params, this_is_parent_update)
  local siblings_are_being_updated, restored_item_params, adjusted_restored_item_position_is_before_project_start, restored_item_negative_position

  siblings_are_being_updated = not this_is_parent_update
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

    if this_restored_item_is_not_instance then
      addRemoveItemImage(restored_item, false)
    end

  elseif this_restored_item_is_not_instance then
    addRemoveItemImage(restored_item, "restored")
  end
end


function propagatePoolChanges(active_superglued_instance_params, sizing_region_guid)
  local parent_pools_near_project_start, ancestor_pools_params_by_children_nesting_depth, i, this_parent_pool_params, this_parent_pool_id, active_track, selected_items, restored_items_position_adjustment

  parent_pools_near_project_start = updateActivePoolSiblings(active_superglued_instance_params, false)
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
      
    reglueParentInstance(this_parent_pool_params, sizing_region_guid, restored_items_position_adjustment)
  end

  reaper.ClearPeakCache()
end


function updateActivePoolSiblings(active_superglued_instance_params, this_is_parent_update)
  local all_items_count, siblings_are_being_updated, parent_pools_near_project_start, i, this_item, this_active_pool_sibling, global_option_toggle_depool_all_siblings_on_reglue, global_option_toggle_depool_all_siblings_on_reglue_warning, attempted_negative_instance_position, this_sibling_parent_pool_id, this_sibling_position_is_earlier_than_prev_sibling

  all_items_count = reaper.CountMediaItems(_api_current_project)
  parent_pools_near_project_start = {}

  for i = 0, all_items_count-1 do
    this_item = reaper.GetMediaItem(_api_current_project, i)
    this_active_pool_sibling = getActivePoolSibling(this_item, active_superglued_instance_params)

    if this_active_pool_sibling then
      global_option_toggle_depool_all_siblings_on_reglue = reaper.GetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_key)

      if global_option_toggle_depool_all_siblings_on_reglue == "true" then
        global_option_toggle_depool_all_siblings_on_reglue = handleDePoolSibling(this_active_pool_sibling)
      end

      if global_option_toggle_depool_all_siblings_on_reglue == "false" then
        parent_pools_near_project_start = handleActivePoolSibling(this_active_pool_sibling, active_superglued_instance_params, this_item, parent_pools_near_project_start, this_is_parent_update)
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


function handleDePoolSibling(active_pool_sibling)
  local global_option_toggle_depool_all_siblings_on_reglue_warning, global_option_toggle_depool_all_siblings_on_reglue

  global_option_toggle_depool_all_siblings_on_reglue_warning = reaper.GetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_warning_key)

  if global_option_toggle_depool_all_siblings_on_reglue_warning == "true" and _user_wants_to_depool_all_siblings == nil then
    _user_wants_to_depool_all_siblings = reaper.ShowMessageBox("Select yes to continue and remove all of this item's siblings from its pool, or no to disable this option.", "Warning: You have the option to remove all sibling instances from pool enabled.", _msg_type_yes_no)

    if _user_wants_to_depool_all_siblings == _msg_response_no then
      reaper.SetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_key, "false", _api_extstate_persist_enabled)
      
      global_option_toggle_depool_all_siblings_on_reglue = "false"

    elseif _user_wants_to_depool_all_siblings == _msg_response_yes then
      reaper.SetExtState(_global_options_section, _global_option_toggle_depool_all_siblings_on_reglue_warning_key, "false", _api_extstate_persist_enabled)

      initDePool(active_pool_sibling)
    end

  else
    initDePool(active_pool_sibling)
  end

  return global_option_toggle_depool_all_siblings_on_reglue
end


function handleActivePoolSibling(active_pool_sibling, active_superglued_instance_params, item, parent_pools_near_project_start, this_is_parent_update)
  local siblings_are_being_updated, attempted_negative_instance_position, sibling_parent_pool_id

  getSetItemAudioSrc(active_pool_sibling, active_superglued_instance_params.updated_src)

  siblings_are_being_updated = not this_is_parent_update

  if siblings_are_being_updated then
    attempted_negative_instance_position = adjustActivePoolSibling(active_pool_sibling, active_superglued_instance_params)

    if attempted_negative_instance_position then
      sibling_parent_pool_id = storeRetrieveItemData(item, _parent_pool_id_key_suffix)

      if not parent_pools_near_project_start[sibling_parent_pool_id] then
        parent_pools_near_project_start[sibling_parent_pool_id] = attempted_negative_instance_position

      elseif parent_pools_near_project_start[sibling_parent_pool_id] then
        this_sibling_position_is_earlier_than_prev_sibling = attempted_negative_instance_position < parent_pools_near_project_start[sibling_parent_pool_id]

        if this_sibling_position_is_earlier_than_prev_sibling then
          parent_pools_near_project_start[sibling_parent_pool_id] = attempted_negative_instance_position
        end
      end
    end
  end

  return parent_pools_near_project_start
end


function adjustActivePoolSibling(instance, active_superglued_instance_params)
  local instance_adjusted_length, active_instance_position_has_changed, user_wants_position_change, instance_current_position, instance_adjusted_position, instance_would_get_adjusted_before_project_start

  instance_adjusted_length = active_superglued_instance_params.length

  reaper.SetMediaItemLength(instance, instance_adjusted_length, false)
  adjustPostGlueTakeEnvelopes(instance)

  active_instance_position_has_changed = not _position_change_response and _position_changed_since_last_glue == true

  if active_instance_position_has_changed then
    _position_change_response = launchPropagatePositionDialog()
  end

  user_wants_position_change = _position_change_response == _msg_response_yes

  if user_wants_position_change then
    instance_current_position = reaper.GetMediaItemInfo_Value(instance, _api_item_position_key)
    instance_adjusted_position = instance_current_position + _superglued_instance_offset_delta_since_last_glue
    instance_would_get_adjusted_before_project_start = instance_adjusted_position < _position_start_of_project
    
    if instance_would_get_adjusted_before_project_start then
      active_take = reaper.GetActiveTake(instance)

      reaper.SetMediaItemPosition(instance, _position_start_of_project, false)
      reaper.SetMediaItemTakeInfo_Value(active_take, _api_take_src_offset_key, -instance_adjusted_position)

      return instance_adjusted_position
    else
      reaper.SetMediaItemPosition(instance, instance_adjusted_position, false)
    end
  end
end


function launchPropagatePositionDialog()
  local global_option_propagate_position_default = reaper.GetExtState(_global_options_section, _global_option_propagate_position_default_key)

  if global_option_propagate_position_default == "ask" then
    return reaper.ShowMessageBox("Do you want to adjust other pool instances' position to match so their audio position remains the same?", "The left edge location of the superglued container item you're regluing has changed!", _msg_type_yes_no)

  elseif global_option_propagate_position_default == "always" then
    return _msg_response_yes

  elseif global_option_propagate_position_default == "no" then
    return _msg_response_no
  end
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


function reglueParentInstance(parent_instance_params, sizing_region_guid, restored_items_position_adjustment)
  local selected_items, parent_instance

  deselectAllItems()
  selectDeselectItems(parent_instance_params.restored_items, true)

  selected_items = getSelectedItems(#parent_instance_params.restored_items)
  parent_instance = handleGlue(selected_items, parent_instance_params.track, parent_instance_params.pool_id, sizing_region_guid, restored_items_position_adjustment, nil, true)
  parent_instance_params.updated_src = getSetItemAudioSrc(parent_instance)

  deselectAllItems()
  updateActivePoolSiblings(parent_instance_params, true)
  reaper.DeleteTrack(parent_instance_params.track)
end
  

function initUnglueExplode(action)
  local selected_item_count, selected_item_groups, superglued_containers, this_pool_id, other_open_instance

  selected_item_count = initAction(action)
  selected_item_groups = getSelectedSuperglueItemTypes(selected_item_count, {"superglued"})
  superglued_containers = selected_item_groups["superglued"]["selected_items"]

  if isNotSingleSupergluedContainer(#superglued_containers, action) == true then return end

  this_pool_id = storeRetrieveItemData(superglued_containers[1], _instance_pool_id_key_suffix)
  other_open_instance = otherInstanceIsOpen(this_pool_id)

  if other_open_instance then
    handleOtherOpenInstance(other_open_instance, this_pool_id, action)

    return
  end
  
  handleUnglueExplode(this_pool_id, action)

  return this_pool_id
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
      return this_item
    end
  end
end


function handleOtherOpenInstance(instance, open_instance_pool_id, action)
  open_instance_pool_id = tostring(open_instance_pool_id)

  reaper.ShowMessageBox("Reglue the other open instance from pool " .. open_instance_pool_id .. " before trying to " .. action .. " this superglued container item. It will be selected and scrolled to now.", "Superglue can only " .. action .. " one superglued pool instance at a time.", _msg_type_ok)
  
  deselectAllItems()
  reaper.SetMediaItemSelected(instance, true)
  scrollToSelectedItem()
end


function scrollToSelectedItem()
  reaper.Main_OnCommand(_scroll_action_id, 0)
end


function handleUnglueExplode(pool_id, action)
  local superglued_container, undo_block_string

  superglued_container = getFirstSelectedItem()

  if action == "Unglue" then
    storeRetrieveSupergluedContainerParams(pool_id, _preedit_action_step, superglued_container)

    undo_block_string = _unglue_undo_block_string

  elseif action == "Explode" then
    undo_block_string = _explode_undo_block_string
  end

  processUnglueExplode(superglued_container, pool_id, action)

  if action ~= "DePool" then
    cleanUpAction(undo_block_string)
  end
end


function processUnglueExplode(superglued_container, pool_id, action)
  local superglued_container_preedit_params, active_track, this_is_explode, superglued_container_preglue_state_key_suffix, superglued_container_state, restored_items, sizing_region_guid

  superglued_container_preedit_params = getSetItemParams(superglued_container)

  deselectAllItems()

  active_track = reaper.BR_GetMediaTrackByGUID(_api_current_project, superglued_container_preedit_params.track_guid)

  if action == "Explode" or action == "DePool" then
    this_is_explode = true

  elseif action == "Unglue" then
    superglued_container_preglue_state_key_suffix = _pool_key_prefix .. pool_id .. _container_preglue_state_suffix
    superglued_container_state = getSetItemStateChunk(superglued_container)

    storeRetrieveProjectData(superglued_container_preglue_state_key_suffix, superglued_container_state)
  end

  restored_items = restoreContainedItems(pool_id, active_track, superglued_container, superglued_container_preedit_params, nil, this_is_explode)

  if action == "Unglue" then
    sizing_region_guid = createSizingRegionFromSupergluedContainer(superglued_container, pool_id)

    initSizingRegionCheck(sizing_region_guid, pool_id)
  end

  reaper.DeleteTrackMediaItem(active_track, superglued_container)

  return active_track, restored_items
end


function createSizingRegionFromSupergluedContainer(superglued_container, pool_id)
  local superglued_container_params, sizing_region_guid

  superglued_container_params = getSetItemParams(superglued_container)
  sizing_region_guid = getSetSizingRegion(pool_id, superglued_container_params)
  
  return sizing_region_guid
end


function initSizingRegionCheck(sizing_region_guid, pool_id)
  local sizing_region_params, defer_start_time, defer_start_project_state, sizing_region_defer_loop_is_active_key

  sizing_region_params = getSetSizingRegion(sizing_region_guid)
  defer_start_time = os.time()
  defer_start_project_state = reaper.GetProjectStateChangeCount(_api_current_project)
  sizing_region_defer_loop_is_active_key = _pool_key_prefix .. pool_id .. _sizing_region_defer_loop_suffix

  storeRetrieveProjectData(sizing_region_defer_loop_is_active_key, "true")
  startSizingRegionCheckLoop(defer_start_time, defer_start_project_state, sizing_region_guid, sizing_region_params, sizing_region_defer_loop_is_active_key, pool_id)
end


function startSizingRegionCheckLoop(defer_loop_start_time, project_state, sizing_region_guid, sizing_region_params, sizing_region_defer_loop_is_active_key, pool_id)
  local current_time, time_elapsed, sizing_region_deletion_msg_is_enabled

  current_time = os.time()
  time_elapsed = current_time - defer_loop_start_time
  sizing_region_deletion_msg_is_enabled = reaper.GetExtState(_global_options_section, _global_option_toggle_sizing_region_deletion_msg_key)

  if time_elapsed > _sizing_region_defer_timing then
    local new_project_state = reaper.GetProjectStateChangeCount(_api_current_project)

    if new_project_state ~= project_state then

      defer_loop_start_time, project_state = checkSizingRegionDeleted(sizing_region_guid, current_time, new_project_state, sizing_region_defer_loop_is_active_key, sizing_region_params, pool_id, sizing_region_deletion_msg_is_enabled)

    else
      defer_loop_start_time = current_time
    end
  end

  if defer_loop_start_time then
    local retval, sizing_region_defer_loop_is_active = storeRetrieveProjectData(sizing_region_defer_loop_is_active_key)
    
    if retval and sizing_region_defer_loop_is_active == "true" then
      reaper.defer(function() 
        startSizingRegionCheckLoop(defer_loop_start_time, project_state, sizing_region_guid, sizing_region_params, sizing_region_defer_loop_is_active_key, pool_id, sizing_region_deletion_msg_is_enabled)
      end)
    end
  end
end


function checkSizingRegionDeleted(sizing_region_guid, current_time, new_project_state, sizing_region_defer_loop_is_active_key, sizing_region_params, pool_id, sizing_region_deletion_msg_is_enabled)
  local region_idx, retval, this_guid, defer_loop_start_time, project_state

  region_idx = 0

  repeat
    retval, this_guid = reaper.GetSetProjectInfo_String(_api_current_project, _api_project_region_guid_key_prefix .. region_idx, "", false)
    
    if retval and this_guid == sizing_region_guid then
      defer_loop_start_time = current_time
      project_state = new_project_state

      break
    end

    region_idx = region_idx + 1

  until retval == false

  if retval == false then
    storeRetrieveProjectData(sizing_region_defer_loop_is_active_key, "false")
    handleSizingRegionDeletion(sizing_region_params, pool_id, sizing_region_deletion_msg_is_enabled)

    return false
  end

  return defer_loop_start_time, project_state
end


function handleSizingRegionDeletion(sizing_region_params, pool_id, sizing_region_deletion_msg_is_enabled)
  local sizing_region_deletion_result, user_wants_to_reinstate_sizing_region, user_wants_to_explode, sizing_region_guid, selected_item_count, i, this_selected_item, this_selected_item_instance_pool_id

  if sizing_region_deletion_msg_is_enabled == "true" then
    sizing_region_deletion_result = reaper.ShowMessageBox('Select "yes" to Explode or "no" to reinstate the deleted sizing region.', "MB_Superglue: An active Unglue sizing region got deleted!", _msg_type_yes_no)
    user_wants_to_reinstate_sizing_region = sizing_region_deletion_result == _msg_response_no
    user_wants_to_explode = sizing_region_deletion_result == _msg_response_yes

  elseif sizing_region_deletion_msg_is_enabled == "false" then
    user_wants_to_explode = true
  end

  if user_wants_to_reinstate_sizing_region then
    reaper.Undo_BeginBlock()

    sizing_region_guid = getSetSizingRegion(pool_id, sizing_region_params)
    
    reaper.Undo_EndBlock(_reinstate_sizing_region_undo_block_string, _api_marker_region_undo_states)
    initSizingRegionCheck(sizing_region_guid, pool_id)

  elseif user_wants_to_explode then
    selected_item_count = reaper.CountSelectedMediaItems(_api_current_project)

    for i = 0, selected_item_count-1 do
      this_selected_item = reaper.GetSelectedMediaItem(_api_current_project, i)
      this_selected_item_instance_pool_id = storeRetrieveItemData(this_selected_item, _instance_pool_id_key_suffix)

      storeRetrieveItemData(this_selected_item, _parent_pool_id_key_suffix, "")
      handleRestoredItemImage(this_selected_item, this_selected_item_instance_pool_id, true)
    end
  end
end


function initSmartAction(unglue_or_explode)
  local selected_item_count, pool_id
  
  selected_item_count = doPreGlueChecks()
  
  if selected_item_count == false then return end

  prepareAction("glue")
  
  if itemsAreSelected(selected_item_count) == false then return end

  pool_id = getFirstPoolIdFromSelectedItems(selected_item_count)

  if containerSelectionIsInvalid(selected_item_count, unglue_or_explode) == true then return end

  if triggerAction(selected_item_count, unglue_or_explode) == false then 
    reaper.ShowMessageBox(_msg_change_selected_items, "Superglue Smart Action can't determine which script to run.", _msg_type_ok)
    setResetItemSelectionSet(false)

    return
  end

  reaper.Undo_EndBlock(_smart_action_undo_block_string, _api_include_all_undo_states)
end


function getSmartAction(selected_item_count)
  local selected_item_groups, parent_instances_count, no_parent_instances_are_selected, single_parent_instance_is_selected, parent_instances_are_selected, multiple_parent_instances_are_selected, noncontainers_count, no_noncontainers_are_selected, noncontainers_are_selected, child_instances_count, no_child_instances_are_selected

  selected_item_groups = getSelectedSuperglueItemTypes(selected_item_count, {"noncontainer", "child_instance", "parent_instance"})
  parent_instances_count = #selected_item_groups["parent_instance"]["selected_items"]
  no_parent_instances_are_selected = parent_instances_count == 0
  single_parent_instance_is_selected = parent_instances_count == 1
  parent_instances_are_selected = parent_instances_count > 0
  multiple_parent_instances_are_selected = parent_instances_count > 1
  noncontainers_count = #selected_item_groups["noncontainer"]["selected_items"]
  no_noncontainers_are_selected = noncontainers_count == 0
  noncontainers_are_selected = noncontainers_count > 0
  child_instances_count = #selected_item_groups["child_instance"]["selected_items"]
  no_child_instances_are_selected = child_instances_count == 0
  single_child_instance_is_selected = child_instances_count == 1

  if single_parent_instance_is_selected and no_noncontainers_are_selected and no_child_instances_are_selected then
    return "unglue_or_explode"
  
  elseif parent_instances_are_selected and single_child_instance_is_selected then
    return "glue/abort"
  
  elseif (multiple_parent_instances_are_selected and no_noncontainers_are_selected and no_child_instances_are_selected) or (noncontainers_are_selected and no_child_instances_are_selected) or (no_parent_instances_are_selected and single_child_instance_is_selected) then
    return "glue"
  end
end


function triggerAction(selected_item_count, unglue_or_explode)
  local superglue_action, glue_abort_dialog

  superglue_action = getSmartAction(selected_item_count)

  if superglue_action == "unglue_or_explode" then
    initUnglueExplode(unglue_or_explode)

  elseif superglue_action == "glue" then
    initSuperglue()

  elseif superglue_action == "glue/abort" then
    glue_abort_dialog = reaper.ShowMessageBox("Are you sure you want to superglue them?", "You have selected both superglued container(s) and restored item(s) from an unglued container.", _msg_type_ok_cancel)

    if glue_abort_dialog == 2 then
      setResetItemSelectionSet(false)

      return
    
    else
      initSuperglue()
    end

  else
    return false
  end
end


function initDePool(target_item)
  local this_is_user_initiated_depool, target_item_params, target_item_state, active_track, restored_items, superglued_container

  this_is_user_initiated_depool = not target_item

  if this_is_user_initiated_depool then
    target_item = getFirstSelectedItem()
  end

  target_item_params = getSetItemParams(target_item)
  target_item_state = getSetItemStateChunk(target_item)
  active_track, target_item_params, restored_items = processDePool(target_item, target_item_params, this_is_user_initiated_depool)
  superglued_container = handleGlue(restored_items, active_track, nil, nil, nil, target_item_params, false, false)

  handleDePoolPostGlue(superglued_container, target_item_state, target_item_params)

  if this_is_user_initiated_depool then
    cleanUpAction(_depool_undo_block_string)
  end
end


function processDePool(target_item, target_item_params, this_is_user_initiated_depool)
  local restored_items, active_track, selected_items_count, i, this_restored_item

  restored_items = {}
  this_is_sibling_depool = not this_is_user_initiated_depool

  if this_is_user_initiated_depool then
    active_track = reaper.GetMediaItemTrack(target_item)
    target_item_params.pool_id = initUnglueExplode("DePool")
    selected_items_count = reaper.CountSelectedMediaItems(_api_current_project)

    for i = 0, selected_items_count-1 do
      this_restored_item = reaper.GetSelectedMediaItem(_api_current_project, i)

      cropItemToSizingParams(this_restored_item, target_item_params, active_track)
    end

    selected_items_count = reaper.CountSelectedMediaItems(_api_current_project)

    for i = 0, selected_items_count-1 do
      this_restored_item = reaper.GetSelectedMediaItem(_api_current_project, i)

      table.insert(restored_items, this_restored_item)
    end

  elseif this_is_sibling_depool then
    target_item_params.pool_id = storeRetrieveItemData(target_item, _instance_pool_id_key_suffix)
    active_track, restored_items = processUnglueExplode(target_item, target_item_params.pool_id, "Explode")

    for i = 1, #restored_items do
      this_restored_item = restored_items[i]

      cropItemToSizingParams(this_restored_item, target_item_params, active_track)
    end
  end

  return active_track, target_item_params, restored_items
end


function handleDePoolPostGlue(superglued_container, target_item_state, target_item_params)
  local active_take, active_take_name, updated_src, new_pool_id

  active_take = reaper.GetActiveTake(superglued_container)
  active_take_name = getSetItemName(superglued_container)
  updated_src = getSetItemAudioSrc(superglued_container)
  new_pool_id = storeRetrieveItemData(superglued_container, _instance_pool_id_key_suffix)

  getSetItemStateChunk(superglued_container, target_item_state)
  getSetItemName(superglued_container, active_take_name)
  storeRetrieveItemData(superglued_container, _instance_pool_id_key_suffix, new_pool_id)
end


function changeSupergluedContainerItemsColor()
  local current_window, retval, color, all_items_count, i, this_item, this_item_instance_pool_id

  current_window = reaper.GetMainHwnd()
  retval, color = reaper.GR_SelectColor(current_window)

  if retval ~= 0 then
    prepareAction("color")

    all_items_count = reaper.CountMediaItems(_api_current_project)

    for i = 0, all_items_count-1 do
      this_item = reaper.GetMediaItem(_api_current_project, i)
      this_item_instance_pool_id = storeRetrieveItemData(this_item, _instance_pool_id_key_suffix)

      if this_item_instance_pool_id and this_item_instance_pool_id ~= "" then
        reaper.SetMediaItemInfo_Value(this_item, _api_item_color_key, color|0x1000000)
      end
    end
    
    cleanUpAction(_color_undo_block_string)
  end
end



--- UTILITY FUNCTIONS ---

function stringifyArray(t)
  local s = ""
  local this_item
  for i = 1, #t do
    this_item = t[i]
    s = s .. this_item
    if i ~= #t then
       s = s .. ", "
    end
  end
  if not s or s == "" then
    s = "none"
  end
  return s
end

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
