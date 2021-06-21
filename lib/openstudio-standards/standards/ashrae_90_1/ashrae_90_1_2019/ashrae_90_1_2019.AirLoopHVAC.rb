class ASHRAE9012019 < ASHRAE901
  # @!group AirLoopHVAC

  # Determine the limits for the type of economizer present on the AirLoopHVAC, if any.
  # @return [Array<Double>] [drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  def air_loop_hvac_economizer_limits(air_loop_hvac, climate_zone)
    drybulb_limit_f = nil
    enthalpy_limit_btu_per_lb = nil
    dewpoint_limit_f = nil

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return [nil, nil, nil] # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType
    oa_control.resetEconomizerMinimumLimitDryBulbTemperature

    case economizer_type
    when 'NoEconomizer'
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} no economizer")
      return [nil, nil, nil]
    when 'FixedDryBulb'
      search_criteria = {
        'template' => template,
        'climate_zone' => climate_zone
      }
      econ_limits = model_find_object(standards_data['economizers'], search_criteria)
      drybulb_limit_f = econ_limits['fixed_dry_bulb_high_limit_shutoff_temp']
    when 'FixedEnthalpy'
      enthalpy_limit_btu_per_lb = 28.0
    when 'FixedDewPointAndDryBulb'
      drybulb_limit_f = 75.0
      dewpoint_limit_f = 55.0
    when 'DifferentialDryBulb', 'DifferentialEnthalpy'
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer type = #{economizer_type}, no limits defined.")
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer type = #{economizer_type}, limits [#{drybulb_limit_f},#{enthalpy_limit_btu_per_lb},#{dewpoint_limit_f}]")

    return [drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  end

  # Determine if the system economizer must be integrated or not.
  # All economizers must be integrated in 90.1-2019
  def air_loop_hvac_integrated_economizer_required?(air_loop_hvac, climate_zone)
    integrated_economizer_required = true
    return integrated_economizer_required
  end

  # Check the economizer type currently specified in the ControllerOutdoorAir object on this air loop
  # is acceptable per the standard.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if allowable, if the system has no economizer or no OA system.
  # Returns false if the economizer type is not allowable.
  def air_loop_hvac_economizer_type_allowable?(air_loop_hvac, climate_zone)
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return true # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType

    # Return true if no economizer is present
    if economizer_type == 'NoEconomizer'
      return true
    end

    # Determine the prohibited types
    prohibited_types = []
    case climate_zone
    when 'ASHRAE 169-2006-0B',
         'ASHRAE 169-2006-1B',
         'ASHRAE 169-2006-2B',
         'ASHRAE 169-2006-3B',
         'ASHRAE 169-2006-3C',
         'ASHRAE 169-2006-4B',
         'ASHRAE 169-2006-4C',
         'ASHRAE 169-2006-5B',
         'ASHRAE 169-2006-6B',
         'ASHRAE 169-2006-7A',
         'ASHRAE 169-2006-7B',
         'ASHRAE 169-2006-8A',
         'ASHRAE 169-2006-8B',
         'ASHRAE 169-2013-0B',
         'ASHRAE 169-2013-1B',
         'ASHRAE 169-2013-2B',
         'ASHRAE 169-2013-3B',
         'ASHRAE 169-2013-3C',
         'ASHRAE 169-2013-4B',
         'ASHRAE 169-2013-4C',
         'ASHRAE 169-2013-5B',
         'ASHRAE 169-2013-6B',
         'ASHRAE 169-2013-7A',
         'ASHRAE 169-2013-7B',
         'ASHRAE 169-2013-8A',
         'ASHRAE 169-2013-8B'
      prohibited_types = ['FixedEnthalpy']
    when 'ASHRAE 169-2006-0A',
         'ASHRAE 169-2006-1A',
         'ASHRAE 169-2006-2A',
         'ASHRAE 169-2006-3A',
         'ASHRAE 169-2006-4A',
         'ASHRAE 169-2013-0A',
         'ASHRAE 169-2013-1A',
         'ASHRAE 169-2013-2A',
         'ASHRAE 169-2013-3A',
         'ASHRAE 169-2013-4A'
      prohibited_types = ['FixedDryBulb', 'DifferentialDryBulb']
    when 'ASHRAE 169-2006-5A',
         'ASHRAE 169-2006-6A',
         'ASHRAE 169-2013-5A',
         'ASHRAE 169-2013-6A'
      prohibited_types = []
    end

    # Check if the specified type is allowed
    economizer_type_allowed = true
    if prohibited_types.include?(economizer_type)
      economizer_type_allowed = false
    end

    return economizer_type_allowed
  end

  # Determine if multizone vav optimization is required.
  #
  # @code_sections [90.1-2019_6.5.3.3]
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for
  #   systems with AIA healthcare ventilation requirements
  #   dual duct systems
  def air_loop_hvac_multizone_vav_optimization_required?(air_loop_hvac, climate_zone)
    multizone_opt_required = false

    # Not required for systems with fan-powered terminals
    num_fan_powered_terminals = 0
    air_loop_hvac.demandComponents.each do |comp|
      if comp.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized || comp.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized
        num_fan_powered_terminals += 1
      end
    end
    if num_fan_powered_terminals > 0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, multizone vav optimization is not required because the system has #{num_fan_powered_terminals} fan-powered terminals.")
      return multizone_opt_required
    end

    # Get the OA intake
    controller_oa = nil
    controller_mv = nil
    oa_system = nil
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, multizone optimization is not applicable because system has no OA intake.")
      return multizone_opt_required
    end

    # Get the AHU design supply air flow rate
    dsn_flow_m3_per_s = nil
    if air_loop_hvac.designSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
    elsif air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} design supply air flow rate is not available, cannot apply efficiency standard.")
      return multizone_opt_required
    end
    dsn_flow_cfm = OpenStudio.convert(dsn_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Get the minimum OA flow rate
    min_oa_flow_m3_per_s = nil
    if controller_oa.minimumOutdoorAirFlowRate.is_initialized
      min_oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
    elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
      min_oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{controller_oa.name}: minimum OA flow rate is not available, cannot apply efficiency standard.")
      return multizone_opt_required
    end
    min_oa_flow_cfm = OpenStudio.convert(min_oa_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Calculate the percent OA at design airflow
    pct_oa = min_oa_flow_m3_per_s / dsn_flow_m3_per_s

    # Not required for systems where
    # exhaust is more than 70% of the total OA intake.
    if pct_oa > 0.7
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{controller_oa.name}: multizone optimization is not applicable because system is more than 70% OA.")
      return multizone_opt_required
    end

    # TODO: Not required for dual-duct systems
    # if self.isDualDuct
    # OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{controller_oa.name}: multizone optimization is not applicable because it is a dual duct system")
    # return multizone_opt_required
    # end

    # If here, multizone vav optimization is required
    multizone_opt_required = true

    return multizone_opt_required
  end

  # Determines the OA flow rates above which an economizer is required.
  # Two separate rates, one for systems with an economizer and another
  # for systems without.
  # are zero for both types.
  # @return [Array<Double>] [min_oa_without_economizer_cfm, min_oa_with_economizer_cfm]
  def air_loop_hvac_demand_control_ventilation_limits(air_loop_hvac)
    min_oa_without_economizer_cfm = 3000
    min_oa_with_economizer_cfm = 750
    return [min_oa_without_economizer_cfm, min_oa_with_economizer_cfm]
  end

  # Determine the air flow and number of story limits for whether motorized OA damper is required.
  # @return [Array<Double>] [minimum_oa_flow_cfm, maximum_stories]
  def air_loop_hvac_motorized_oa_damper_limits(air_loop_hvac, climate_zone)
    case climate_zone
    when 'ASHRAE 169-2006-0A',
         'ASHRAE 169-2006-1A',
         'ASHRAE 169-2006-0B',
         'ASHRAE 169-2006-1B',
         'ASHRAE 169-2006-2A',
         'ASHRAE 169-2006-2B',
         'ASHRAE 169-2006-3A',
         'ASHRAE 169-2006-3B',
         'ASHRAE 169-2006-3C',
         'ASHRAE 169-2013-0A',
         'ASHRAE 169-2013-1A',
         'ASHRAE 169-2013-0B',
         'ASHRAE 169-2013-1B',
         'ASHRAE 169-2013-2A',
         'ASHRAE 169-2013-2B',
         'ASHRAE 169-2013-3A',
         'ASHRAE 169-2013-3B',
         'ASHRAE 169-2013-3C'
      minimum_oa_flow_cfm = 0
      maximum_stories = 999 # Any number of stories
    else
      minimum_oa_flow_cfm = 0
      maximum_stories = 0
    end

    return [minimum_oa_flow_cfm, maximum_stories]
  end

  # Determine the number of stages that should be used as controls for single zone DX systems.
  # 90.1-2019 depends on the cooling capacity of the system.
  #
  # @return [Integer] the number of stages: 0, 1, 2
  def air_loop_hvac_single_zone_controls_num_stages(air_loop_hvac, climate_zone)
    min_clg_cap_btu_per_hr = 65_000
    clg_cap_btu_per_hr = OpenStudio.convert(air_loop_hvac_total_cooling_capacity(air_loop_hvac), 'W', 'Btu/hr').get
    if clg_cap_btu_per_hr >= min_clg_cap_btu_per_hr
      num_stages = 2
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: two-stage control is required since cooling capacity of #{clg_cap_btu_per_hr.round} Btu/hr exceeds the minimum of #{min_clg_cap_btu_per_hr.round} Btu/hr .")
    else
      num_stages = 1
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: two-stage control is not required since cooling capacity of #{clg_cap_btu_per_hr.round} Btu/hr is less than the minimum of #{min_clg_cap_btu_per_hr.round} Btu/hr .")
    end

    return num_stages
  end

  # Determine if the system required supply air temperature (SAT) reset.
  # For 90.1-2019, SAT reset requirements are based on climate zone.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_supply_air_temperature_reset_required?(air_loop_hvac, climate_zone)
    is_sat_reset_required = false

    # Only required for multizone VAV systems
    unless air_loop_hvac_multizone_vav_system?(air_loop_hvac)
      return is_sat_reset_required
    end

    case climate_zone
    when 'ASHRAE 169-2006-0A',
         'ASHRAE 169-2006-1A',
         'ASHRAE 169-2006-2A',
         'ASHRAE 169-2006-3A',
         'ASHRAE 169-2013-0A',
         'ASHRAE 169-2013-1A',
         'ASHRAE 169-2013-2A',
         'ASHRAE 169-2013-3A'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Supply air temperature reset is not required per 6.5.3.4 Exception 1, the system is located in climate zone #{climate_zone}.")
      return is_sat_reset_required
    when 'ASHRAE 169-2006-0B',
         'ASHRAE 169-2006-1B',
         'ASHRAE 169-2006-2B',
         'ASHRAE 169-2006-3B',
         'ASHRAE 169-2006-3C',
         'ASHRAE 169-2006-4A',
         'ASHRAE 169-2006-4B',
         'ASHRAE 169-2006-4C',
         'ASHRAE 169-2006-5A',
         'ASHRAE 169-2006-5B',
         'ASHRAE 169-2006-5C',
         'ASHRAE 169-2006-6A',
         'ASHRAE 169-2006-6B',
         'ASHRAE 169-2006-7A',
         'ASHRAE 169-2006-7B',
         'ASHRAE 169-2006-8A',
         'ASHRAE 169-2006-8B',
         'ASHRAE 169-2013-0B',
         'ASHRAE 169-2013-1B',
         'ASHRAE 169-2013-2B',
         'ASHRAE 169-2013-3B',
         'ASHRAE 169-2013-3C',
         'ASHRAE 169-2013-4A',
         'ASHRAE 169-2013-4B',
         'ASHRAE 169-2013-4C',
         'ASHRAE 169-2013-5A',
         'ASHRAE 169-2013-5B',
         'ASHRAE 169-2013-5C',
         'ASHRAE 169-2013-6A',
         'ASHRAE 169-2013-6B',
         'ASHRAE 169-2013-7A',
         'ASHRAE 169-2013-7B',
         'ASHRAE 169-2013-8A',
         'ASHRAE 169-2013-8B'
      is_sat_reset_required = true
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Supply air temperature reset is required.")
      return is_sat_reset_required
    end
  end

  # Determine the airflow limits that govern whether or not an ERV is required.
  # Based on climate zone and % OA, plus the number of operating hours the system has.
  # @return [Double] the flow rate above which an ERV is required.
  # if nil, ERV is never required.
  def air_loop_hvac_energy_recovery_ventilator_flow_limit(air_loop_hvac, climate_zone, pct_oa)
    # Calculate the number of system operating hours
    # based on the availability schedule.
    ann_op_hrs = 0.0
    avail_sch = air_loop_hvac.availabilitySchedule
    if avail_sch == air_loop_hvac.model.alwaysOnDiscreteSchedule
      ann_op_hrs = 8760.0
    elsif avail_sch.to_ScheduleRuleset.is_initialized
      avail_sch = avail_sch.to_ScheduleRuleset.get
      ann_op_hrs = schedule_ruleset_annual_hours_above_value(avail_sch, 0.0)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.ashrae_90_1_2019.AirLoopHVAC', "For #{air_loop_hvac.name}: could not determine annual operating hours. Assuming less than 8,000 for ERV determination.")
    end

    if ann_op_hrs < 8000.0
      # Table 6.5.6.1-1, less than 8000 hrs
      search_criteria = {
        'template' => template,
        'climate_zone' => climate_zone,
        'under_8000_hours' => true
      }
      energy_recovery_limits = model_find_object(standards_data['energy_recovery'], search_criteria)
      if energy_recovery_limits.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.ashrae_90_1_2019.AirLoopHVAC', "Cannot find energy recovery limits for template '#{template}', climate zone '#{climate_zone}', and under 8000 hours, assuming no energy recovery required.")
        return nil
      end

      if pct_oa < 0.1
        erv_cfm = nil
      elsif pct_oa >= 0.1 && pct_oa < 0.2
        erv_cfm = energy_recovery_limits['10_to_20_percent_oa']
      elsif pct_oa >= 0.2 && pct_oa < 0.3
        erv_cfm = energy_recovery_limits['20_to_30_percent_oa']
      elsif pct_oa >= 0.3 && pct_oa < 0.4
        erv_cfm = energy_recovery_limits['30_to_40_percent_oa']
      elsif pct_oa >= 0.4 && pct_oa < 0.5
        erv_cfm = energy_recovery_limits['40_to_50_percent_oa']
      elsif pct_oa >= 0.5 && pct_oa < 0.6
        erv_cfm = energy_recovery_limits['50_to_60_percent_oa']
      elsif pct_oa >= 0.6 && pct_oa < 0.7
        erv_cfm = energy_recovery_limits['60_to_70_percent_oa']
      elsif pct_oa >= 0.7 && pct_oa < 0.8
        erv_cfm = energy_recovery_limits['70_to_80_percent_oa']
      elsif pct_oa >= 0.8
        erv_cfm = energy_recovery_limits['greater_than_80_percent_oa']
      end
    else
      # Table 6.5.6.1-2, above 8000 hrs
      search_criteria = {
        'template' => template,
        'climate_zone' => climate_zone,
        'under_8000_hours' => false
      }
      energy_recovery_limits = model_find_object(standards_data['energy_recovery'], search_criteria)
      if energy_recovery_limits.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.ashrae_90_1_2019.AirLoopHVAC', "Cannot find energy recovery limits for template '#{template}', climate zone '#{climate_zone}', and under 8000 hours, assuming no energy recovery required.")
        return nil
      end
      if pct_oa < 0.1
        erv_cfm = nil
      elsif pct_oa >= 0.1 && pct_oa < 0.2
        erv_cfm = energy_recovery_limits['10_to_20_percent_oa']
      elsif pct_oa >= 0.2 && pct_oa < 0.3
        erv_cfm = energy_recovery_limits['20_to_30_percent_oa']
      elsif pct_oa >= 0.3 && pct_oa < 0.4
        erv_cfm = energy_recovery_limits['30_to_40_percent_oa']
      elsif pct_oa >= 0.4 && pct_oa < 0.5
        erv_cfm = energy_recovery_limits['40_to_50_percent_oa']
      elsif pct_oa >= 0.5 && pct_oa < 0.6
        erv_cfm = energy_recovery_limits['50_to_60_percent_oa']
      elsif pct_oa >= 0.6 && pct_oa < 0.7
        erv_cfm = energy_recovery_limits['60_to_70_percent_oa']
      elsif pct_oa >= 0.7 && pct_oa < 0.8
        erv_cfm = energy_recovery_limits['70_to_80_percent_oa']
      elsif pct_oa >= 0.8
        erv_cfm = energy_recovery_limits['greater_than_80_percent_oa']
      end
    end

    return erv_cfm
  end

  # Adjust minimum VAV damper positions and set minimum design
  # system outdoor air flow following ASHRAE Std. 62.1-2019
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def air_loop_hvac_adjust_minimum_vav_damper_positions(air_loop_hvac)
    # Do not apply the adjustment to some of the system in
    # the hospital and outpatient which have their minimum
    # damper position determined based on AIA 2001 ventilation
    # requirements
    if (@instvarbuilding_type == 'Hospital' && (air_loop_hvac.name.to_s.include?('VAV_ER') || air_loop_hvac.name.to_s.include?('VAV_ICU') ||
                                                air_loop_hvac.name.to_s.include?('VAV_OR') || air_loop_hvac.name.to_s.include?('VAV_LABS') ||
                                                air_loop_hvac.name.to_s.include?('VAV_PATRMS'))) ||
       (@instvarbuilding_type == 'Outpatient' && air_loop_hvac.name.to_s.include?('Outpatient F1'))

      return true
    end

    # Total uncorrected outdoor airflow rate
    v_ou = 0.0
    air_loop_hvac.thermalZones.each do |zone|
      # Vou is the system uncorrected outdoor airflow:
      # Zone airflow is multiplied by the zone multiplier
      v_ou += thermal_zone_outdoor_airflow_rate(zone) * zone.multiplier.to_f
    end

    v_ou_cfm = OpenStudio.convert(v_ou, 'm^3/s', 'cfm').get

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: v_ou = #{v_ou_cfm.round} cfm.")

    # Retrieve the sum of the zone minimum primary airflow
    vpz_min_sum = air_loop_hvac.autosizeSumMinimumHeatingAirFlowRates

    air_loop_hvac.thermalZones.sort.each do |zone|
      # Breathing zone airflow rate
      v_bz = thermal_zone_outdoor_airflow_rate(zone)

      # Zone air distribution, assumed 1 per PNNL
      e_z = 1.0

      # Zone airflow rate
      v_oz = v_bz / e_z

      # Primary design airflow rate
      # max of heating and cooling
      # design air flow rates
      v_pz = 0.0
      clg_dsn_flow = zone.autosizedCoolingDesignAirFlowRate
      if clg_dsn_flow.is_initialized
        clg_dsn_flow = clg_dsn_flow.get
        if clg_dsn_flow > v_pz
          v_pz = clg_dsn_flow
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: #{zone.name} clg_dsn_flow could not be found.")
      end
      htg_dsn_flow = zone.autosizedHeatingDesignAirFlowRate
      if htg_dsn_flow.is_initialized
        htg_dsn_flow = htg_dsn_flow.get
        if htg_dsn_flow > v_pz
          v_pz = htg_dsn_flow
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: #{zone.name} htg_dsn_flow could not be found.")
      end

      # Zone ventilation efficiency calculation is computed
      # on a per zone basis, the zone primary airflow is
      # adjusted to removed the zone multiplier
      v_pz /= zone.multiplier.to_f

      # Set minimum damper position
      air_loop_hvac_set_minimum_damper_position(zone, 1.5 * v_oz / v_pz)
    end

    # Occupant diversity (D): Ps / sum(Pz)
    # Current value is based on school prototypes
    # which are assumed to have the most diversity
    occ_diver_d = 0.66

    # From ASHRAE Std 62.1-2019 Section 6.2.5.3
    if occ_diver_d < 0.6
      e_v = 0.88 * occ_diver_d + 0.22
    else
      e_v = 0.75
    end

    # Total system outdoor intake flow rate
    v_ot = v_ou / e_v
    v_ot_cfm = OpenStudio.convert(v_ot, 'm^3/s', 'cfm').get

    # Get maximum OA fraction schedule
    oa_ctrl = air_loop_hvac.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir
    max_oa_frac_sch = oa_ctrl.maximumFractionofOutdoorAirSchedule

    if !max_oa_frac_sch.is_initialized
      max_oa_frac_sch = OpenStudio::Model::ScheduleConstant.new(air_loop_hvac.model)
      max_oa_frac_sch.setName("#{air_loop_hvac.name}_MAX_OA_FRAC")
      max_oa_frac_sch.setValue(1.0)
      max_oa_frac_sch_type = 'Schedule:Constant'
      oa_ctrl.setMaximumFractionofOutdoorAirSchedule(max_oa_frac_sch)
    else
      if max_oa_frac_sch.to_ScheduleRuleset.is_initialized
        max_oa_frac_sch = max_oa_frac_sch.to_ScheduleRuleset.get
        max_oa_frac_sch_type = 'Schedule:Year'
      elsif max_oa_frac_sch.to_ScheduleConstant.is_initialized
        max_oa_frac_sch = max_oa_frac_sch.to_ScheduleConstant.get
        max_oa_frac_sch_type = 'Schedule:Constant'
      elsif max_oa_frac_sch.to_ScheduleCompact.is_initialized
        max_oa_frac_sch = max_oa_frac_sch.to_ScheduleCompact.get
        max_oa_frac_sch_type = 'Schedule:Compact'
      end
    end

    # Add EMS to "cap" the OA calculated by the
    # Controller:MechanicalVentilation object
    # to the design v_ot using the maximum OA
    # fraction schedule

    # Add EMS sensors
    # OA mass flow calculated by the Controller:MechanicalVentilation
    air_loop_hvac_name_ems = "EMS_#{air_loop_hvac.name.to_s.gsub(' ', '_')}"
    oa_vrp_mass_flow = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Air System Outdoor Air Mechanical Ventilation Requested Mass Flow Rate')
    oa_vrp_mass_flow.setKeyName(air_loop_hvac.name.to_s)
    oa_vrp_mass_flow.setName("#{air_loop_hvac_name_ems}_OA_VRP")
    # Actual sensed OA mass flow
    oa_mass_flow = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Air System Outdoor Air Mass Flow Rate')
    oa_mass_flow.setKeyName(air_loop_hvac.name.to_s)
    oa_mass_flow.setName("#{air_loop_hvac_name_ems}_OA")
    # Actual sensed volumetric OA flow
    oa_vol_flow = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'System Node Standard Density Volume Flow Rate')
    oa_vol_flow.setKeyName("#{air_loop_hvac.name} Mixed Air Node")
    oa_vol_flow.setName("#{air_loop_hvac_name_ems}_SUPPLY_FLOW")

    # Add EMS actuator
    max_oa_fraction = OpenStudio::Model::EnergyManagementSystemActuator.new(max_oa_frac_sch, max_oa_frac_sch_type, 'Schedule Value')
    max_oa_fraction.setName("#{air_loop_hvac_name_ems}_MAX_OA_FRAC")

    # Add EMS program
    max_oa_ems_prog = OpenStudio::Model::EnergyManagementSystemProgram.new(air_loop_hvac.model)
    max_oa_ems_prog.setName("#{air_loop_hvac.name}_MAX_OA_FRAC")
    max_oa_ems_prog_body = <<-EMS
    IF #{air_loop_hvac_name_ems}_OA > #{air_loop_hvac_name_ems}_OA_VRP,
    SET #{air_loop_hvac_name_ems}_MAX_OA_FRAC = NULL,
    ELSE,
    IF #{air_loop_hvac_name_ems}_SUPPLY_FLOW > 0,
    SET #{air_loop_hvac_name_ems}_MAX_OA_FRAC = #{v_ot} / #{air_loop_hvac_name_ems}_SUPPLY_FLOW,
    ELSE,
    SET #{air_loop_hvac_name_ems}_MAX_OA_FRAC = NULL,
    ENDIF,
    ENDIF
    EMS
    max_oa_ems_prog.setBody(max_oa_ems_prog_body)

    max_oa_ems_prog_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(air_loop_hvac.model)
    max_oa_ems_prog_manager.setName("SET_#{air_loop_hvac.name.to_s.gsub(' ', '_')}_MAX_OA_FRAC")
    max_oa_ems_prog_manager.setCallingPoint('InsideHVACSystemIterationLoop')
    max_oa_ems_prog_manager.addProgram(max_oa_ems_prog)

    # Hard-size the sizing:system
    # object with the calculated min OA flow rate
    sizing_system = air_loop_hvac.sizingSystem
    sizing_system.setDesignOutdoorAirFlowRate(v_ot)
    sizing_system.setSystemOutdoorAirMethod('ZoneSum')

    return true
  end
end
