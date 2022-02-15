class ASHRAE901PRM2019 < ASHRAE901PRM
  # @!group Model

  # Determine if there is a need for a proposed model sizing run.
  # A typical application of such sizing run is to determine space
  # conditioning type.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  #
  # @return [Boolean] Returns true if a sizing run is required
  def model_create_prm_baseline_building_requires_proposed_model_sizing_run(model)
    return true
  end

  # Determines the area of the building above which point
  # the non-dominant area type gets it's own HVAC system type.
  # @return [Double] the minimum area (m^2)
  def model_prm_baseline_system_group_minimum_area(model, custom)
    exception_min_area_ft2 = 20_000
    # Customization - Xcel EDA Program Manual 2014
    # 3.2.1 Mechanical System Selection ii
    if custom == 'Xcel Energy CO EDA'
      exception_min_area_ft2 = 5000
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Customization; per Xcel EDA Program Manual 2014 3.2.1 Mechanical System Selection ii, minimum area for non-predominant conditions reduced to #{exception_min_area_ft2} ft2.")
    end
    exception_min_area_m2 = OpenStudio.convert(exception_min_area_ft2, 'ft^2', 'm^2').get
    return exception_min_area_m2
  end

  # Determines which system number is used
  # for the baseline system.
  # @return [String] the system number: 1_or_2, 3_or_4,
  # 5_or_6, 7_or_8, 9_or_10
  def model_prm_baseline_system_number(model, climate_zone, area_type, fuel_type, area_ft2, num_stories, custom)
    sys_num = nil

    # Customization - Xcel EDA Program Manual 2014
    # Table 3.2.2 Baseline HVAC System Types
    if custom == 'Xcel Energy CO EDA'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Xcel EDA Program Manual 2014 Table 3.2.2 Baseline HVAC System Types, the 90.1-2010 lookup for HVAC system types shall be used.')

      # Set the area limit
      limit_ft2 = 25_000

      case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
          # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
          # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
      when 'heatedonly'
        sys_num = '9_or_10'
      when 'retail'
        # Should only be hit by Xcel EDA
        sys_num = '3_or_4'
      end

    else

      # Set the area limit
      limit_ft2 = 25_000

      case area_type
      when 'residential'
        sys_num = '1_or_2'
      when 'nonresidential'
        # nonresidential and 3 floors or less and <25,000 ft2
        if num_stories <= 3 && area_ft2 < limit_ft2
          sys_num = '3_or_4'
        # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
        elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
          sys_num = '5_or_6'
        # nonresidential and more than 5 floors or >150,000 ft2
        elsif num_stories >= 5 || area_ft2 > 150_000
          sys_num = '7_or_8'
        end
      when 'heatedonly'
        sys_num = '9_or_10'
      when 'retail'
        sys_num = '3_or_4'
      end

    end

    return sys_num
  end

  # Change the fuel type based on climate zone, depending on the standard.
  # For 90.1-2013, fuel type is based on climate zone, not the proposed model.
  # @return [String] the revised fuel type
  def model_prm_baseline_system_change_fuel_type(model, fuel_type, climate_zone, custom = nil)
    if custom == 'Xcel Energy CO EDA'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', 'Custom; per Xcel EDA Program Manual 2014 Table 3.2.2 Baseline HVAC System Types, the 90.1-2010 rules for heating fuel type (based on proposed model) rules apply.')
      return fuel_type
    end

    # For 90.1-2013 the fuel type is determined based on climate zone.
    # Don't change the fuel if it purchased heating or cooling.
    if fuel_type == 'electric' || fuel_type == 'fossil'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
           'ASHRAE 169-2006-2A',
           'ASHRAE 169-2006-3A',
           'ASHRAE 169-2013-1A',
           'ASHRAE 169-2013-2A',
           'ASHRAE 169-2013-3A'
        fuel_type = 'electric'
      else
        fuel_type = 'fossil'
      end
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Heating fuel is #{fuel_type} for 90.1-2013, climate zone #{climate_zone}.  This is independent of the heating fuel type in the proposed building, per G3.1.1-3.  This is different than previous versions of 90.1.")
    end

    return fuel_type
  end

  # Determines the fan type used by VAV_Reheat and VAV_PFP_Boxes systems.
  # Variable speed fan for 90.1-2013
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_baseline_system_vav_fan_type(model)
    fan_type = 'Variable Speed Fan'
    return fan_type
  end

  # Determines the skylight to roof ratio limit for a given standard
  # 3% for 90.1-PRM-2019
  # @return [Double] the skylight to roof ratio, as a percent: 5.0 = 5%
  def model_prm_skylight_to_roof_ratio_limit(model)
    srr_lim = 3.0
    return srr_lim
  end

  # Analyze HVAC, window-to-wall ratio and SWH building (area) types from user data inputs in the @standard_data library
  # This function returns True, but the values are stored in the multi-building_data argument.
  # The hierarchy for process the building types
  # 1. Highest: PRM rules - if rules applied against user inputs, the function will use the calculated value to reset the building type
  # 2. Second: User defined building type in the csv file.
  # 3. Third: User defined userdata_building.csv file. If an object (e.g. space, thermalzone) are not defined in their correspondent userdata csv file, use the building csv file
  # 4. Fourth: Dropdown list in the measure GUI. If none presented, use the data from the dropdown list.
  # NOTE! This function will add building types to OpenStudio objects as an additional features for hierarchy 1-3
  # The object additional feature is empty when the function determined it uses fourth hierarchy.
  #
  # @param [OpenStudio::Model::Model] model
  # @param [String] default_hvac_building_type (Fourth Hierarchy hvac building type)
  # @param [String] default_wwr_building_type (Fourth Hierarchy wwr building type)
  # @param [String] default_swh_building_type (Fourth Hierarchy swh building type)
  # @return True
  def handle_multi_building_area_types(model, default_hvac_building_type, default_wwr_building_type, default_swh_building_type)
    # Construct the user_building hashmap
    user_buildings = @standards_data.key?('userdata_building') ? @standards_data['userdata_building'] : nil

    # Build up a hvac_building_type : thermal zone hash map
    # HVAC user data process
    user_thermal_zones = @standards_data.key?('userdata_thermal_zone') ? @standards_data['userdata_thermal_zone'] : nil
    if user_thermal_zones && user_thermal_zones.length >= 1
      # First construct hvac building type -> thermal Zone hash
      bldg_type_zone_hash = {}
      model.getThermalZones.sort.each do |thermal_zone|
        user_thermal_zone_index = user_thermal_zones.index { |user_thermal_zone| user_thermal_zone['name'] == thermal_zone.get.name.get }
        hvac_building_type = nil
        if user_thermal_zone_index.nil?
          # This zone is not in the user data, check 3rd hierarchy
          if user_buildings && user_buildings.length >= 1
            building_name = thermal_zone.model.building.get.name.get
            user_building_index = user_buildings.index { |user_building| user_building['name'] == building_name }
            if user_building_index.nil?
              # This zone belongs to a building that is not in the user_buildings, set to 4th hierarchy
              hvac_building_type = default_hvac_building_type
            else
              # Found user_buildings data, set to the 3rd hierarchy
              hvac_building_type = user_buildings[user_building_index]['building_type_for_hvac']
            end
          else
            # No user_buildings defined. set to 4th hierarchy
            hvac_building_type = default_hvac_building_type
          end
        else
          # This zone has user data, set to 2nd hierarchy
          hvac_building_type = user_thermal_zones[user_thermal_zone_index]['building_type_for_hvac']
        end

        if !bldg_type_zone_hash.key?(hvac_building_type)
          bldg_type_zone_hash[hvac_building_type] = []
        end
        bldg_type_zone_hash[hvac_building_type].append(thermal_zone)
      end


      if model.building.get.conditionedFloorArea.get <= 40000
        # First get the total conditioned floor area
        model.getThermalZones.sort.each do |thermal_zone|
          # In this case, only one primary building hvac type
          building_name = thermal_zone.model.building.get.name.get
          thermal_zone.additionalProperties.setFeature('building_type_for_hvac', hvac_building_type)

        end
      end

      # add the key to the multi_building_data
      user_thermal_zones.each do |user_thermal_zone|
        user_thermal_zone_name = user_thermal_zone['name']
        hvac_building_type = user_thermal_zone['building_type_for_hvac']
        thermal_zone = model.getThermalZoneByName(user_thermal_zone_name)
        if thermal_zone.empty?
          OpenStudio.logFree(OpenStudio::Error, 'OpenStudio::Model::ThermalZone', "Cannot find a thermal zone named #{user_thermal_zone_name} in the model, check your user data inputs")
          # Skip the processing of this thermal zone.
          next
        end

        target_thermal_zone = thermal_zone.get
        target_thermal_zone.additionalProperties.setFeature('building_type_for_hvac', hvac_building_type)
      end
    end

    # SPACE user data process
    user_spaces = @standards_data.key?('userdata_space') ? @standards_data['userdata_space'] : nil
    if user_spaces && user_spaces.length >= 1
      # Loop spaces
      model.getSpaces.sort.each do |space|
        # check for 2nd level hierarchy
        found_user_data = false
        user_spaces.each do |user_space|
          if space.name.get == user_space['name'] && !user_space['building_type_for_wwr'].nil?
            space.additionalProperties.setFeature('building_type_for_wwr', user_space['building_type_for_wwr'])
            found_user_data = true
          end
        end

        # check for 3nd level hierarchy
        if !found_user_data && !user_buildings.nil?
          # get space building type
          building_name = space.model.building.get.name.get

          user_buildings.each do |user_building|
            if user_building['name'] == building_name && !user_building['building_type_for_wwr'].nil?
              space.additionalProperties.setFeature('building_type_for_wwr', user_building['building_type_for_wwr'])
            end
          end
        end
      end
    end

    # SWH user data process
    user_wateruse_equipments = @standards_data.key?('userdata_wateruse_equipment') ? @standards_data['userdata_wateruse_equipment'] : nil
    if user_wateruse_equipments && user_wateruse_equipments.length >= 1
      # loop water use equipment list

      model.getWaterUseEquipments.sort.each do |wateruse_equipment|
        # check for 2nd level hierarchy
        found_user_data = false
        # add the key to the multi_building_data
        user_wateruse_equipments.each do |user_wateruse_equipment|
          if wateruse_equipment.name.get == user_wateruse_equipment['name'] && !user_wateruse_equipment['bulding_type_for_swh'].nil?
            wateruse_equipment.additionalProperties.setFeature('bulding_type_for_swh', user_wateruse_equipment['bulding_type_for_swh'])
            found_user_data = true
          end
        end

        # check for 3nd level hierarchy
        if !found_user_data && !user_buildings.nil?
          # get space building type
          building_name = wateruse_equipment.model.building.get.name.get
          user_buildings.each do |user_building|
            if user_building['name'] == building_name && !user_building['building_type_for_wwr'].nil?
              wateruse_equipment.additionalProperties.setFeature('building_type_for_wwr', user_building['building_type_for_wwr'])
            end
          end
        end
      end
    end
    return true
  end
end
