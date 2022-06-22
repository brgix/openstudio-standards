class ASHRAE901PRM < Standard
  # @!group Model

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

  # This method creates customized infiltration objects for each
  # space and removes the SpaceType-level infiltration objects.
  #
  # @return [Bool] true if successful, false if not
  def model_apply_infiltration_standard(model, climate_zone)
    # Model shouldn't use SpaceInfiltrationEffectiveLeakageArea
    # Excerpt from the EnergyPlus Input/Output reference manual:
    #     "This model is based on work by Sherman and Grimsrud (1980)
    #     and is appropriate for smaller, residential-type buildings."
    # Return an error if the model does use this object
    ela = 0
    model.getSpaceInfiltrationEffectiveLeakageAreas.sort.each do |eff_la|
      ela += 1
    end
    if ela > 0
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', 'The current model cannot include SpaceInfiltrationEffectiveLeakageArea. These objects cannot be used to model infiltration according to the 90.1-PRM rules.')
    end

    # Get the space building envelope area
    # According to the 90.1 definition, building envelope include:
    # - "the elements of a building that separate conditioned spaces from the exterior"
    # - "the elements of a building that separate conditioned space from unconditioned
    #    space or that enclose semiheated spaces through which thermal energy may be
    #    transferred to or from the exterior, to or from unconditioned spaces or to or
    #    from conditioned spaces."
    building_envelope_area_m2 = 0
    model.getSpaces.sort.each do |space|
      building_envelope_area_m2 += space_envelope_area(space, climate_zone)
    end
    if building_envelope_area_m2 == 0.0
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', 'Calculated building envelope area is 0 m2, no infiltration will be added.')
      return 0.0
    end

    # Calculate current model air leakage rate @ 75 Pa and report it
    curr_tot_infil_m3_per_s_per_envelope_area = model_current_building_envelope_infiltration_at_75pa(model, building_envelope_area_m2)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The proposed model I_75Pa is estimated to be #{curr_tot_infil_m3_per_s_per_envelope_area} m3/s per m2 of total building envelope.")

    # Calculate building adjusted building envelope
    # air infiltration following the 90.1 PRM rules
    tot_infil_m3_per_s = model_adjusted_building_envelope_infiltration(model, building_envelope_area_m2)

    # Find infiltration method used in the model, if any.
    #
    # If multiple methods are used, use per above grade wall
    # area (i.e. exterior wall area), if air/changes per hour
    # or exterior surface area is used, use Flow/ExteriorWallArea
    infil_method = model_get_infiltration_method(model)
    infil_method = 'Flow/ExteriorWallArea' if infil_method != 'Flow/Area' || infil_method != 'Flow/ExteriorWallArea'
    infil_coefficients = model_get_infiltration_coefficients(model)

    # Set the infiltration rate at each space
    model.getSpaces.sort.each do |space|
      space_apply_infiltration_rate(space, tot_infil_m3_per_s, infil_method, infil_coefficients)
    end

    # Remove infiltration rates set at the space type
    model.getSpaceTypes.sort.each do |space_type|
      space_type.spaceInfiltrationDesignFlowRates.each(&:remove)
    end

    return true
  end

  # This method retrieves the type of infiltration input
  # used in the model. If input is inconsitent, returns
  # Flow/Area
  #
  # @return [String] infiltration input type
  def model_get_infiltration_method(model)
    infil_method = nil
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space.spaceInfiltrationDesignFlowRates[0]
        old_infil_method = old_infil.designFlowRateCalculationMethod.to_s
        # Return flow per space floor area if method is inconsisten in proposed model
        return 'Flow/Area' if infil_method != old_infil_method && !infil_method.nil?

        infil_method = old_infil_method
      end

      # Infiltration at the space type level
      if infil_method.nil? && space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
          old_infil_method = old_infil.designFlowRateCalculationMethod.to_s
          # Return flow per space floor area if method is inconsisten in proposed model
          return 'Flow/Area' if infil_method != old_infil_method && !infil_method.nil?

          infil_method = old_infil_method
        end
      end
    end

    return infil_method
  end

  # This method retrieves the infiltration coefficients
  # used in the model. If input is inconsitent, returns
  # [0, 0, 0.224, 0] as per PRM user manual
  #
  # @return [String] infiltration input type
  def model_get_infiltration_coefficients(model)
    cst = nil
    temp = nil
    vel = nil
    vel_2 = nil
    infil_coeffs = [cst, temp, vel, vel_2]
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space.spaceInfiltrationDesignFlowRates[0]
        cst = old_infil.constantTermCoefficient
        temp = old_infil.temperatureTermCoefficient
        vel = old_infil.velocityTermCoefficient
        vel_2 = old_infil.velocitySquaredTermCoefficient
        old_infil_coeffs = [cst, temp, vel, vel_2] if !(cst.nil? && temp.nil? && vel.nil? && vel_2.nil?)
        # Return flow per space floor area if method is inconsisten in proposed model
        return [0.0, 0.0, 0.224, 0.0] if infil_coeffs != old_infil_coeffs && !(infil_coeffs[0].nil? &&
                                                                                    infil_coeffs[1].nil? &&
                                                                                    infil_coeffs[2].nil? &&
                                                                                    infil_coeffs[3].nil?)

        infil_coeffs = old_infil_coeffs
      end

      # Infiltration at the space type level
      if infil_coeffs == [nil, nil, nil, nil] && space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
          cst = old_infil.constantTermCoefficient
          temp = old_infil.temperatureTermCoefficient
          vel = old_infil.velocityTermCoefficient
          vel_2 = old_infil.velocitySquaredTermCoefficient
          old_infil_coeffs = [cst, temp, vel, vel_2] if !(cst.nil? && temp.nil? && vel.nil? && vel_2.nil?)
          # Return flow per space floor area if method is inconsisten in proposed model
          return [0.0, 0.0, 0.224, 0.0] unless infil_coeffs != old_infil_coeffs && !(infil_coeffs[0].nil? &&
                                                                                      infil_coeffs[1].nil? &&
                                                                                      infil_coeffs[2].nil? &&
                                                                                      infil_coeffs[3].nil?)

          infil_coeffs = old_infil_coeffs
        end
      end
    end
    return infil_coeffs
  end

  # This methods calculate the current model air leakage rate @ 75 Pa.
  # It assumes that the model follows the PRM methods, see G3.1.1.4
  # in 90.1-2019 for reference.
  #
  # @param [OpenStudio::Model::Model] OpenStudio Model object
  # @param [Double] Building envelope area as per 90.1 in m^2
  #
  # @return [Float] building model air leakage rate
  def model_current_building_envelope_infiltration_at_75pa(model, building_envelope_area_m2)
    bldg_air_leakage_rate = 0
    model.getSpaces.sort.each do |space|
      # Infiltration at the space level
      unless space.spaceInfiltrationDesignFlowRates.empty?
        infil_obj = space.spaceInfiltrationDesignFlowRates[0]
        unless infil_obj.designFlowRate.is_initialized
          if infil_obj.flowperSpaceFloorArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperSpaceFloorArea.get * space.floorArea
          elsif infil_obj.flowperExteriorSurfaceArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperExteriorSurfaceArea.get * space.exteriorArea
          elsif infil_obj.flowperExteriorWallArea.is_initialized
            bldg_air_leakage_rate += infil_obj.flowperExteriorWallArea.get * space.exteriorWallArea
          elsif infil_obj.airChangesperHour.is_initialized
            bldg_air_leakage_rate += infil_obj.airChangesperHour.get * space.volume / 3600
          end
        end
      end

      # Infiltration at the space type level
      if space.spaceType.is_initialized
        space_type = space.spaceType.get
        unless space_type.spaceInfiltrationDesignFlowRates.empty?
          infil_obj = space_type.spaceInfiltrationDesignFlowRates[0]
          unless infil_obj.designFlowRate.is_initialized
            if infil_obj.flowperSpaceFloorArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperSpaceFloorArea.get * space.floorArea
            elsif infil_obj.flowperExteriorSurfaceArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperExteriorSurfaceArea.get * space.exteriorArea
            elsif infil_obj.flowperExteriorWallArea.is_initialized
              bldg_air_leakage_rate += infil_obj.flowperExteriorWallArea.get * space.exteriorWallArea
            elsif infil_obj.airChangesperHour.is_initialized
              bldg_air_leakage_rate += infil_obj.airChangesperHour.get * space.volume / 3600
            end
          end
        end
      end
    end
    # adjust_infiltration_to_prototype_building_conditions(1) corresponds
    # to the 0.112 shown in G3.1.1.4
    curr_tot_infil_m3_per_s_per_envelope_area = bldg_air_leakage_rate / adjust_infiltration_to_prototype_building_conditions(1) / building_envelope_area_m2
    return curr_tot_infil_m3_per_s_per_envelope_area
  end

  # This method calculates the building envelope infiltration,
  # this approach uses the 90.1 PRM rules
  #
  # @return [Float] building envelope infiltration
  def model_adjusted_building_envelope_infiltration(model, building_envelope_area_m2)
    # Determine the total building baseline infiltration rate in cfm per ft2 of the building envelope at 75 Pa
    basic_infil_rate_cfm_per_ft2 = space_infiltration_rate_75_pa

    # Do nothing if no infiltration
    return 0.0 if basic_infil_rate_cfm_per_ft2.zero?

    # Conversion factor
    conv_fact = OpenStudio.convert(1, 'm^3/s', 'ft^3/min').to_f / OpenStudio.convert(1, 'm^2', 'ft^2').to_f

    # Adjust the infiltration rate to the average pressure for the prototype buildings.
    # adj_infil_rate_cfm_per_ft2 = 0.112 * basic_infil_rate_cfm_per_ft2
    adj_infil_rate_cfm_per_ft2 = adjust_infiltration_to_prototype_building_conditions(basic_infil_rate_cfm_per_ft2)
    adj_infil_rate_m3_per_s_per_m2 = adj_infil_rate_cfm_per_ft2 / conv_fact

    # Calculate the total infiltration
    tot_infil_m3_per_s = adj_infil_rate_m3_per_s_per_m2 * building_envelope_area_m2

    return tot_infil_m3_per_s
  end

  # Reduces the SRR to the values specified by the PRM. SRR reduction will be done by shrinking vertices toward the centroid.
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  def model_apply_prm_baseline_skylight_to_roof_ratio(model)
    # Loop through all spaces in the model, and
    # per the 90.1-2019 PRM User Manual, only
    # account for exterior roofs for enclosed
    # spaces. Include space multipliers.
    roof_m2 = 0.001 # Avoids divide by zero errors later
    sky_m2 = 0
    total_roof_m2 = 0.001
    total_subsurface_m2 = 0
    model.getSpaces.sort.each do |space|
      next if space_conditioning_category(space) == 'Unconditioned'

      # Loop through all surfaces in this space
      roof_area_m2 = 0
      sky_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # This roof's gross area (including skylight area)
        roof_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          sky_area_m2 += ss.netArea * space.multiplier
        end
      end

      total_roof_m2 += roof_area_m2
      total_subsurface_m2 += sky_area_m2
    end

    # Calculate the SRR of each category
    srr = ((total_subsurface_m2 / total_roof_m2) * 100.0).round(1)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The skylight to roof ratios (SRRs) is: : #{srr.round}%.")

    # SRR limit
    srr_lim = model_prm_skylight_to_roof_ratio_limit(model)

    # Check against SRR limit
    red = srr > srr_lim

    # Stop here unless skylights need reducing
    return true unless red

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all skylights equally down to the limit of #{srr_lim.round}%.")

    # Determine the factors by which to reduce the skylight area
    mult = srr_lim / srr

    # Reduce the skylight area if any of the categories necessary
    model.getSpaces.sort.each do |space|
      next if space_conditioning_category(space) == 'Unconditioned'

      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'

        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          next unless ss.subSurfaceType == 'Skylight'

          # Reduce the size of the skylight
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, red)
        end
      end
    end

    return true
  end

  # Add design day schedule objects for space loads, for PRM 2019 baseline models
  # @author Xuechen (Jerry) Lei, PNNL
  # @param model [OpenStudio::model::Model] OpenStudio model object
  #
  def model_apply_prm_baseline_sizing_schedule(model)
    space_loads = model.getSpaceLoads
    loads = []
    space_loads.sort.each do |space_load|
      load_type = space_load.iddObjectType.valueName.sub('OS_', '').strip.sub('_', '')
      casting_method_name = "to_#{load_type}"
      if space_load.respond_to?(casting_method_name)
        casted_load = space_load.public_send(casting_method_name).get
        loads << casted_load
      else
        p 'Need Debug, casting method not found @JXL'
      end
    end

    load_schedule_name_hash = {
      'People' => 'numberofPeopleSchedule',
      'Lights' => 'schedule',
      'ElectricEquipment' => 'schedule',
      'GasEquipment' => 'schedule',
      'SpaceInfiltration_DesignFlowRate' => 'schedule'
    }

    loads.each do |load|
      load_type = load.iddObjectType.valueName.sub('OS_', '').strip
      load_schedule_name = load_schedule_name_hash[load_type]
      next unless !load_schedule_name.nil?

      # check if the load is in a dwelling space
      if load.spaceType.is_initialized
        space_type = load.spaceType.get
      elsif load.space.is_initialized && load.space.get.spaceType.is_initialized
        space_type = load.space.get.spaceType.get
      else
        space_type = nil
        puts "No hosting space/spacetype found for load: #{load.name}"
      end
      if !space_type.nil? && /apartment/i =~ space_type.standardsSpaceType.to_s
        load_in_dwelling = true
      else
        load_in_dwelling = false
      end

      load_schedule = load.public_send(load_schedule_name).get
      schedule_type = load_schedule.iddObjectType.valueName.sub('OS_', '').strip.sub('_', '')
      load_schedule = load_schedule.public_send("to_#{schedule_type}").get

      case schedule_type
      when 'ScheduleRuleset'
        load_schmax = get_8760_values_from_schedule(model, load_schedule).max
        load_schmin = get_8760_values_from_schedule(model, load_schedule).min
        load_schmode = get_weekday_values_from_8760(model,
                                                    Array(get_8760_values_from_schedule(model, load_schedule)),
                                                    value_includes_holiday = true).mode[0]

        # AppendixG-2019 G3.1.2.2.1
        if load_type == 'SpaceInfiltration_DesignFlowRate'
          summer_value = load_schmax
          winter_value = load_schmax
        else
          summer_value = load_schmax
          winter_value = load_schmin
        end

        # AppendixG-2019 Exception to G3.1.2.2.1
        if load_in_dwelling
          summer_value = load_schmode
        end

        # set cooling design day schedule
        summer_dd_schedule = OpenStudio::Model::ScheduleDay.new(model)
        summer_dd_schedule.setName("#{load.name} Summer Design Day")
        summer_dd_schedule.addValue(OpenStudio::Time.new(1.0), summer_value)
        load_schedule.setSummerDesignDaySchedule(summer_dd_schedule)

        # set heating design day schedule
        winter_dd_schedule = OpenStudio::Model::ScheduleDay.new(model)
        winter_dd_schedule.setName("#{load.name} Winter Design Day")
        winter_dd_schedule.addValue(OpenStudio::Time.new(1.0), winter_value)
        load_schedule.setWinterDesignDaySchedule(winter_dd_schedule)

      when 'ScheduleConstant'
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "Space load #{load.name} has schedule type of ScheduleConstant. Nothing to be done for ScheduleConstant")
        next
      end
    end
  end

  # Identifies non mechanically cooled ("nmc") systems, if applicable
  #
  # TODO: Zone-level evaporative cooler is not currently supported by
  #       by OpenStudio, will need to be added to the method when
  #       supported.
  #
  # @param model [OpenStudio::model::Model] OpenStudio model object
  # @return zone_nmc_sys_type [Hash] Zone to nmc system type mapping
  def model_identify_non_mechanically_cooled_systems(model)
    # Iterate through zones to find out if they are served by nmc systems
    model.getThermalZones.sort.each do |zone|
      # Check if airloop has economizer and either:
      # - No cooling coil and/or,
      # - An evaporative cooling coil
      air_loop = zone.airLoopHVAC

      unless air_loop.empty?
        # Iterate through all the airloops assigned to a zone
        zone.airLoopHVACs.each do |airloop|
          air_loop = air_loop.get
          if (!air_loop_hvac_include_cooling_coil?(air_loop) &&
            air_loop_hvac_include_evaporative_cooler?(air_loop)) ||
             (!air_loop_hvac_include_cooling_coil?(air_loop) &&
               air_loop_hvac_include_economizer?(air_loop))
            air_loop.additionalProperties.setFeature('non_mechanically_cooled', true)
            air_loop.thermalZones.each do |thermal_zone|
              thermal_zone.additionalProperties.setFeature('non_mechanically_cooled', true)
            end
          end
        end
      end
    end
  end

  # Specify supply air temperature setpoint for unit heaters based on 90.1 Appendix G G3.1.2.8.2
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone Object
  #
  # @return [Double] for zone with unit heaters, return design supply temperature; otherwise, return nil
  def thermal_zone_prm_unitheater_design_supply_temperature(thermal_zone)
    thermal_zone.equipment.each do |eqt|
      if eqt.to_ZoneHVACUnitHeater.is_initialized
        return OpenStudio.convert(105, 'F', 'C').get
      end
    end
    return nil
  end

  # Specify supply to room delta for laboratory spaces based on 90.1 Appendix G Exception to G3.1.2.8.1
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] OpenStudio ThermalZone Object
  #
  # @return [Double] for zone with laboratory space, return 17; otherwise, return nil
  def thermal_zone_prm_lab_delta_t(thermal_zone)
    # For labs, add 17 delta-T; otherwise, add 20 delta-T
    thermal_zone.spaces.each do |space|
      space_std_type = space.spaceType.get.standardsSpaceType.get
      if space_std_type == 'laboratory'
        return 17
      end
    end
    return nil
  end

  # Indicate if fan power breakdown (supply, return, and relief)
  # are needed
  #
  # @return [Boolean] true if necessary, false otherwise
  def model_get_fan_power_breakdown
    return true
  end

  # Template method for adding a setpoint manager for a coil control logic to a heating coil.
  # ASHRAE 90.1-2019 Appendix G.
  #
  # @param model [OpenStudio::Model::Model] Openstudio model
  # @param thermalZones Array([OpenStudio::Model::ThermalZone]) thermal zone array
  # @param coil Heating Coils
  # @return [Boolean] true
  def model_set_central_preheat_coil_spm(model, thermalZones, coil)
    # search for the highest zone setpoint temperature
    max_heat_setpoint = 0.0
    coil_name = coil.name.get.to_s
    thermalZones.each do |zone|
      tstat = zone.thermostatSetpointDualSetpoint
      if tstat.is_initialized
        tstat = tstat.get
        setpoint_sch = tstat.heatingSetpointTemperatureSchedule
        setpoint_min_max = search_min_max_value_from_design_day_schedule(setpoint_sch, 'heating')
        setpoint_c = setpoint_min_max['max']
        if setpoint_c > max_heat_setpoint
          max_heat_setpoint = setpoint_c
        end
      end
    end
    # in this situation, we hard set the temperature to be 22 F
    # (ASHRAE 90.1 Room heating stepoint temperature is 72 F)
    max_heat_setpoint = 22.2 if max_heat_setpoint == 0.0

    max_heat_setpoint_f = OpenStudio.convert(max_heat_setpoint, 'C', 'F').get
    preheat_setpoint_f = max_heat_setpoint_f - 20
    preheat_setpoint_c = OpenStudio.convert(preheat_setpoint_f, 'F', 'C').get

    # create a new constant schedule and this method will add schedule limit type
    preheat_coil_sch = model_add_constant_schedule_ruleset(model,
                                                           preheat_setpoint_c,
                                                           name = "#{coil_name} Setpoint Temp - #{preheat_setpoint_f.round}F")
    preheat_coil_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, preheat_coil_sch)
    preheat_coil_manager.setName("#{coil_name} Preheat Coil Setpoint Manager")

    if coil.to_CoilHeatingWater.is_initialized
      preheat_coil_manager.addToNode(coil.airOutletModelObject.get.to_Node.get)
    elsif coil.to_CoilHeatingElectric.is_initialized
      preheat_coil_manager.addToNode(coil.outletModelObject.get.to_Node.get)
    elsif coil.to_CoilHeatingGas.is_initialized
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.models.CoilHeatingGas', 'Preheat coils in baseline system shall only be electric or hydronic. Current coil type: Natural Gas')
      preheat_coil_manager.addToNode(coil.airOutletModelObject.get.to_Node.get)
    end

    return true
  end

  # Add zone additional property "zone DCV implemented in user model":
  #   - 'true' if zone OA flow requirement is specified as per person & airloop supporting this zone has DCV enabled
  #   - 'false' otherwise
  def model_mark_zone_dcv_existence(model)
    model.getAirLoopHVACs.each do |air_loop_hvac|
      next unless air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized

      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      next unless controller_mv.demandControlledVentilation == true

      air_loop_hvac.thermalZones.each do |thermal_zone|
        zone_dcv = false
        thermal_zone.spaces.each do |space|
          dsn_oa = space.designSpecificationOutdoorAir
          next if dsn_oa.empty?

          dsn_oa = dsn_oa.get
          next if dsn_oa.outdoorAirMethod == 'Maximum'

          if dsn_oa.outdoorAirFlowperPerson > 0
            # only in this case the thermal zone is considered to be implemented with DCV
            zone_dcv = true
          end
        end

        if zone_dcv == true
          thermal_zone.additionalProperties.setFeature('zone DCV implemented in user model', true)
        end
      end
    end

    # mark unmarked zones
    model.getThermalZones.each do |zone|
      next if zone.additionalProperties.hasFeature('zone DCV implemented in user model')

      zone.additionalProperties.setFeature('zone DCV implemented in user model', false)
    end

    model.getThermalZones.each do |zone| # TODO: JXL delete this block, this is for testing
      puts zone.name
      puts zone.additionalProperties.getFeatureAsBoolean('zone DCV implemented in user model').get
      # puts zone.additionalProperties.getFeatureAsBoolean('user specified DCV exception').get
    end

    return true
  end

  # read user data and add to zone additional properties
  # "airloop user specified DCV exception"
  # "one user specified DCV exception"
  def model_add_dcv_user_exception_properties(model)
    model.getAirLoopHVACs.each do |air_loop_hvac|
      dcv_airloop_user_exception = false
      # TODO: JXL check `model_find_object` search with insensitive case
      if standards_data.key?('userdata_airloop_hvac')
        standards_data['userdata_airloop_hvac'].each do |row|
          next unless row['name'].to_s.downcase.strip == air_loop_hvac.name.to_s.downcase.strip

          if row['dcv_exception_airloop'].to_s.upcase.strip == 'TRUE'
            dcv_airloop_user_exception = true
            break
          end
        end
      end
      air_loop_hvac.thermalZones.each do |thermal_zone|
        if dcv_airloop_user_exception
          thermal_zone.additionalProperties.setFeature('airloop user specified DCV exception', true)
        end
      end
    end

    # zone level exception tagging is put outside of airloop because it directly reads from user data and
    # a zone not under an airloop in user model may be in an airloop in baseline
    model.getThermalZones.each do |thermal_zone|
      dcv_zone_user_exception = false
      if standards_data.key?('userdata_thermal_zone')
        standards_data['userdata_thermal_zone'].each do |row|
          next unless row['name'].to_s.downcase.strip == thermal_zone.name.to_s.downcase.strip

          if row['dcv_exception_thermal_zone'].to_s.upcase.strip == 'TRUE'
            dcv_zone_user_exception = true
            break
          end
        end
      end
      if dcv_zone_user_exception
        thermal_zone.additionalProperties.setFeature('zone user specified DCV exception', true)
      end
    end

    # mark unmarked zones
    model.getThermalZones.each do |zone|
      next if zone.additionalProperties.hasFeature('airloop user specified DCV exception')

      zone.additionalProperties.setFeature('airloop user specified DCV exception', false)
    end

    model.getThermalZones.each do |zone|
      next if zone.additionalProperties.hasFeature('zone user specified DCV exception')

      zone.additionalProperties.setFeature('zone user specified DCV exception', false)
    end
  end

  # add zone additional property "airloop dcv required by 901"
  # - "true" if the airloop supporting this zone is required by 90.1 (non-exception requirement + user provided exception flag) to have DCV regarding user model
  # - "false" otherwise
  # add zone additional property "zone dcv required by 901"
  # - "true" if the zone is required by 90.1(non-exception requirement + user provided exception flag) to have DCV regarding user model
  # - 'flase' otherwise
  def model_add_dcv_requirement_properties(model)
    # TODO: JXL this method uses existing dcv requirement checking from OSSTD, double check to make sure they align
    model.getAirLoopHVACs.each do |air_loop_hvac|
      if user_model_air_loop_hvac_demand_control_ventilation_required?(air_loop_hvac)
        air_loop_hvac.thermalZones.each do |thermal_zone|
          thermal_zone.additionalProperties.setFeature('airloop dcv required by 901', true)

          # the zone level dcv requirement can only be true if it is in an airloop that is required to have DCV
          if user_model_zone_demand_control_ventilation_required?(thermal_zone)
            thermal_zone.additionalProperties.setFeature('zone dcv required by 901', true)
          end
        end
      end
    end

    # mark unmarked zones
    model.getThermalZones.each do |zone|
      next if zone.additionalProperties.hasFeature('airloop dcv required by 901')

      zone.additionalProperties.setFeature('airloop dcv required by 901', false)
    end

    model.getThermalZones.each do |zone|
      next if zone.additionalProperties.hasFeature('zone dcv required by 901')

      zone.additionalProperties.setFeature('zone dcv required by 901', false)
    end
  end


  # based on previously added flag, raise error if DCV is required but not implemented in zones, in which case
  # baseline generation will be terminated; raise warning if DCV is not required but implemented, and continue baseline
  # generation
  def model_raise_user_model_dcv_errors(model)
    model.getThermalZones.each do |thermal_zone|
      if thermal_zone.additionalProperties.getFeatureAsBoolean('zone DCV implemented in user model').get &&
        (!thermal_zone.additionalProperties.getFeatureAsBoolean('zone dcv required by 901').get ||
          !thermal_zone.additionalProperties.getFeatureAsBoolean('airloop dcv required by 901').get)
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "For thermal zone #{thermal_zone.name}, ASHRAE 90.1 2019 6.4.3.8 does NOT require this zone to have demand control ventilation, but it was implemented in the user model, Appendix G baseline generation will continue!")
      end
      if thermal_zone.additionalProperties.getFeatureAsBoolean('zone dcv required by 901').get &&
         thermal_zone.additionalProperties.getFeatureAsBoolean('airloop dcv required by 901').get &&
         !thermal_zone.additionalProperties.getFeatureAsBoolean('zone DCV implemented in user model').get
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "For thermal zone #{thermal_zone.name}, ASHRAE 90.1 2019 6.4.3.8 requires this zone to have demand control ventilation, but it was not implemented in the user model, Appendix G baseline generation should be terminated!")
      end
    end
  end

  # Check if zones in the baseline model (to be created) should have DCV based on 90.1 2019 G3.1.2.5. Zone additional
  # property 'apxg no need to have DCV' added
  def model_add_apxg_dcv_properties(model)
    model.getAirLoopHVACs.each do |air_loop_hvac|
      if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
        oa_flow_m3_per_s = get_airloop_hvac_design_oa_from_sql(air_loop_hvac)
        # oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
        # controller_oa = oa_system.getControllerOutdoorAir
        # if controller_oa.minimumOutdoorAirFlowRate.is_initialized
        #   oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
        # elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
        #   oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
        # end
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, DCV not applicable because it has no OA intake.")
        return false
      end
      oa_flow_cfm = OpenStudio.convert(oa_flow_m3_per_s, 'm^3/s', 'cfm').get
      if oa_flow_cfm <= 3000
        air_loop_hvac.thermalZones.each do |thermal_zone|
          thermal_zone.additionalProperties.setFeature('apxg no need to have DCV', true)
        end
      else # oa_flow_cfg > 3000, check zone people density
        air_loop_hvac.thermalZones.each do |thermal_zone|
          area_served_m2 = 0
          num_people = 0
          thermal_zone.spaces.each do |space|
            area_served_m2 += space.floorArea
            num_people += space.numberOfPeople
          end
          area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get
          occ_per_1000_ft2 = num_people / area_served_ft2 * 1000
          if occ_per_1000_ft2 <= 100
            thermal_zone.additionalProperties.setFeature('apxg no need to have DCV', true)
          else
            thermal_zone.additionalProperties.setFeature('apxg no need to have DCV', false)
          end
        end
      end
    end
    # if a zone does not have this additional property, it means it was not served by airloop.
  end

  def model_set_baseline_demand_control_ventilation(model, climate_zone)
    model.getAirLoopHVACs.each do |air_loop_hvac|
      if baseline_air_loop_hvac_demand_control_ventilation_required?(air_loop_hvac)
        air_loop_hvac_enable_demand_control_ventilation(air_loop_hvac, climate_zone)
        air_loop_hvac.thermalZones.sort.each do |zone|
          unless baseline_thermal_zone_demand_control_ventilation_required?(zone)
            thermal_zone_convert_oa_req_to_per_area(zone)
          end
        end
      end
    end
  end
end
