require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

# Test suite for the ASHRAE 90.1 appendix G Performance
# Rating Method (PRM) baseline automation implementation
# in openstudio-standards.
# @author Doug Maddox (PNNL), Jeremy Lerond (PNNL), and Yunyang Ye (PNNL)
class AppendixGPRMTests < Minitest::Test
  # Set folder for JSON files related to tests and
  # parse individual JSON files used by all methods
  # in this class.
  @@json_dir = "#{File.dirname(__FILE__)}/data"
  @@prototype_list = JSON.parse(File.read("#{@@json_dir}/prototype_list.json"))
  @@wwr_building_types = JSON.parse(File.read("#{@@json_dir}/wwr_building_types.json"))
  @@hvac_building_types = JSON.parse(File.read("#{@@json_dir}/hvac_building_types.json"))
  @@swh_building_types = JSON.parse(File.read("#{@@json_dir}/swh_building_types.json"))
  @@wwr_values = JSON.parse(File.read("#{@@json_dir}/wwr_values.json"))
  @@hasres_values  = JSON.parse(File.read("#{@@json_dir}/hasres_values.json"))

  # Generate one of the ASHRAE 90.1 prototype model included in openstudio-standards.
  #
  # @param prototypes_to_generate [Array] List of prototypes to generate, see prototype_list.json to see the structure of the list
  #
  # @return [Hash] Hash of OpenStudio Model of the prototypes
  def generate_prototypes(prototypes_to_generate)
    prototypes = {}
    @lpd_space_types_alt = {}
    @bldg_type_alt = {}
    @bldg_type_alt_now = nil
    
    prototypes_to_generate.each do |id, prototype|
      # mod is an array of method intended to modify the model
      building_type, template, climate_zone, mod = prototype

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join("_")

      # Initialize weather file, necessary but not used
      epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'

      # Create output folder if it doesn't already exist
      @test_dir = "#{File.dirname(__FILE__)}/output"
      if !Dir.exist?(@test_dir)
        Dir.mkdir(@test_dir)
      end

      # Define model name and run folder if it doesn't already exist,
      # if it does, remove it and re-create it.
      model_name = "#{building_type}-#{template}-#{climate_zone}-#{mod_str}"
      run_dir = "#{@test_dir}/#{model_name}"
      if !Dir.exist?(run_dir)
        Dir.mkdir(run_dir)
      else
        FileUtils.rm_rf(run_dir)
        Dir.mkdir(run_dir)
      end

      # Create the prototype
      prototype_creator = Standard.build("#{template}_#{building_type}")
      model = prototype_creator.model_create_prototype_model(climate_zone, epw_file, run_dir)

      # Make modification if requested
      if !mod.empty?
        mod.each do |method_mod|
          mthd, arguments = method_mod
          model = public_send(mthd, model, arguments)
        end
      end

      if @bldg_type_alt_now != nil
        @bldg_type_alt[prototype] = @bldg_type_alt_now
      else
        @bldg_type_alt[prototype] = nil?
      end

      # Save prototype OSM file
      osm_path = OpenStudio::Path.new("#{run_dir}/#{model_name}.osm")
      model.save(osm_path, true)

      # Translate prototype model to an IDF file
      forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
      idf_path = OpenStudio::Path.new("#{run_dir}/#{model_name}.idf")
      idf = forward_translator.translateModel(model)
      idf.save(idf_path, true)

      # Save OpenStudio model object
      prototypes[id] = model
    end
    return prototypes
  end

  # Generate the 90.1 Appendix G baseline for a model following the 90.1-2019 PRM rules
  #
  # @param prototypes_generated [Array] List of all unique prototypes for which baseline models will be created
  # @param id_prototype_mapping [Hash] Mapping of prototypes to their identifiers generated by prototypes_to_generate()
  #
  # @return [Hash] Hash of OpenStudio Model of the prototypes
  def generate_baseline(prototypes_generated, id_prototype_mapping)
    baseline_prototypes = {}
    prototypes_generated.each do |id, model|
      building_type, template, climate_zone, mod = id_prototype_mapping[id]

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join("_")

      # Initialize Standard class
      prototype_creator = Standard.build('90.1-PRM-2019')

      # Convert standardSpaceType string for each space to values expected for prm creation
      lpd_space_types = JSON.parse(File.read("#{@@json_dir}/lpd_space_types.json"))
      model.getSpaceTypes.sort.each do |space_type|
        next if space_type.floorArea == 0

        standards_space_type = if space_type.standardsSpaceType.is_initialized
                                 space_type.standardsSpaceType.get
                               end
        std_bldg_type = space_type.standardsBuildingType.get
        bldg_type_space_type = std_bldg_type + space_type.standardsSpaceType.get
        new_space_type = lpd_space_types[bldg_type_space_type]
        alt_space_type_was_found = false
        unless @lpd_space_types_alt.nil?
          # Check alternate hash of LPD space types before replacing from JSON list
          @lpd_space_types_alt.each do |alt_bldg_space_type, new_space_type|
            if bldg_type_space_type == alt_bldg_space_type
              alt_space_type_was_found = true
              space_type.setStandardsSpaceType(new_space_type)
              break
            end
          end
        end  
        if alt_space_type_was_found == false
          puts "DEM: bldg_type_space_type = #{bldg_type_space_type}"
           space_type.setStandardsSpaceType(lpd_space_types[bldg_type_space_type])
        end
      end

      # Define run directory and run name, delete existing folder if it exists
      model_name = "#{building_type}-#{template}-#{climate_zone}-#{mod_str}"
      run_dir = "#{@test_dir}/#{model_name}"
      run_dir_baseline = "#{run_dir}-Baseline"
      if Dir.exist?(run_dir_baseline)
        FileUtils.rm_rf(run_dir_baseline)
      end

      if @bldg_type_alt[id_prototype_mapping[id]] == false
        hvac_building_type = building_type
      else
        hvac_building_type = @bldg_type_alt[id_prototype_mapping[id]]
      end

      # Create baseline model
      model_baseline = prototype_creator.model_create_prm_stable_baseline_building(model, building_type, climate_zone,
                                                                                   @@hvac_building_types[hvac_building_type],
                                                                                   @@wwr_building_types[building_type],
                                                                                   @@swh_building_types[building_type],
                                                                                   nil, run_dir_baseline, false, false)

      # Check if baseline could be created
      assert(model_baseline, "Baseline model could not be generated for #{building_type}, #{template}, #{climate_zone}.")

      # Load newly generated baseline model
      @test_dir = "#{File.dirname(__FILE__)}/output"
      model_baseline = OpenStudio::Model::Model.load("#{@test_dir}/#{building_type}-#{template}-#{climate_zone}-#{mod_str}-Baseline/final.osm")
      model_baseline = model_baseline.get

      # Do sizing run for baseline model
      sim_control = model_baseline.getSimulationControl
      sim_control.setRunSimulationforSizingPeriods(true)
      sim_control.setRunSimulationforWeatherFileRunPeriods(false)
      baseline_run = prototype_creator.model_run_simulation_and_log_errors(model_baseline, "#{@test_dir}/#{building_type}-#{template}-#{climate_zone}-Baseline/SR1")

      # Add prototype to the list of baseline prototypes generated
      baseline_prototypes[id] = model_baseline
    end
    return baseline_prototypes
  end

  # Write out a SQL query to retrieve simulation outputs
  # from the TabularDataWithStrings table in the SQL
  # database produced by OpenStudio/EnergyPlus after
  # running a simulation.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param report_name [String] Name of the report as defined in the HTM simulation output file
  # @param table_name [String] Name of the table as defined in the HTM simulation output file
  # @param row_name [String] Name of the row as defined in the HTM simulation output file
  # @param column_name [String] Name of the column as defined in the HTM simulation output file
  # @param units [String] Unit of the value to be retrieved
  #
  # @return [String] Result of the query
  def run_query_tabulardatawithstrings(model, report_name, table_name, row_name, column_name, units = '*')
    # Define the query
    query = "Select Value FROM TabularDataWithStrings WHERE
    ReportName = '#{report_name}' AND
    TableName = '#{table_name}' AND
    RowName = '#{row_name}' AND
    ColumnName = '#{column_name}' AND
    Units = '#{units}'"
    # Run the query if the expected output is a string
    return model.sqlFile.get.execAndReturnFirstString(query).get unless !units.empty?

    # Run the query if the expected output is a double
    return model.sqlFile.get.execAndReturnFirstDouble(query).get
  end

  # Identify individual prototypes to be created
  #
  # @param tests [Array] Names of the tests to be performed
  # @param prototype_list [Hash] List of prototypes needed for each test
  #
  # @return [Hash] Prototypes to be generated
  def get_prototype_to_generate(tests, prototype_list)
    # Initialize prototype identifier
    id = 0
    # Associate model description to identifiers
    prototypes_to_generate = {}
    prototype_list.each do |utest, prototypes|
      prototypes.each do |prototype|
        if !prototypes_to_generate.values.include?(prototype) && tests.include?(utest)
          prototypes_to_generate[id] = prototype
          id += 1
        end
      end
    end
    return prototypes_to_generate
  end

  # Assign prototypes to each individual tests
  #
  # @param prototypes_generated [Hash] Hash containing all the OpenStudio model objects of the prototypes that have been created
  # @param tests [Array] List of tests to be performed
  # @param id_prototype_mapping [Hash] Mapping of prototypes to their respective ids
  #
  # @return [Hash] Association of OpenStudio model object to model description for each test
  def assign_prototypes(prototypes_generated, tests, id_prototype_mapping)
    test_prototypes = {}
    tests.each do |test|
      test_prototypes[test] = {}
      puts "DEM: test each"
      @@prototype_list[test].each do |prototype|
        puts "DEM: list each"
        # Find prototype id in mapping
        prototype_id = -9999.0
        id_prototype_mapping.each do |id, prototype_description|
          puts "DEM: mapping each"
          if prototype_description == prototype
            prototype_id = id
          end
        end
        test_prototypes[test][prototype] = prototypes_generated[prototype_id]
      end
    end
    return test_prototypes
  end

  # Check Window-to-Wall Ratio (WWR) for the baseline models
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_wwr(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, mod = prototype

      # Get WWR of baseline model
      wwr_baseline = run_query_tabulardatawithstrings(model_baseline, 'InputVerificationandResultsSummary', 'Conditioned Window-Wall Ratio', 'Gross Window-Wall Ratio', 'Total', '%').to_f

      # Check WWR against expected WWR
      wwr_goal = 100 * @@wwr_values[building_type].to_f
      assert(wwr_baseline == wwr_goal, "Baseline WWR for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The WWR of the baseline model is #{wwr_baseline} but should be #{wwr_goal}.")
    end
  end

  # Check that no daylighting controls are modeled in the baseline models
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_daylighting_control(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, mod = prototype
      # Check the model include daylighting control objects
      model_baseline.getSpaces.sort.each do |space|
        existing_daylighting_controls = space.daylightingControls
        assert(existing_daylighting_controls.empty?, "The baseline model for the #{building_type}-#{template} in #{climate_zone} has daylighting control.")
      end
    end
  end

  # Check if the IsResidential flag used by the PRM works as intended (i.e. should be false for commercial spaces)
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_residential_flag(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, mod = prototype
      # Determine whether any space is residential
      has_res = 'false'
      std = Standard.build("#{template}_#{building_type}")
      model_baseline.getSpaces.sort.each do |space|
        if std.space_residential?(space)
          has_res = 'true'
        end
      end
      # Check whether space_residential? function is working
      has_res_goal = @@hasres_values[building_type]
      assert(has_res == has_res_goal, "Failure to set space_residential? for #{building_type}, #{template}, #{climate_zone}.")
    end
  end

  # Check envelope requirements lookups
  #
  # @param prototypes_base [Hash] Baseline prototypes
  #
  # TODO: Add residential and semi-heated spaces lookup
  def check_envelope(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, mod = prototype
      # Define name of surfaces used for verification
      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod}"

      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join("_")

      opaque_exterior_name = JSON.parse(File.read("#{@@json_dir}/envelope.json"))[run_id]['opaque_exterior_name']
      exterior_fenestration_name = JSON.parse(File.read("#{@@json_dir}/envelope.json"))[run_id]['exterior_fenestration_name']
      exterior_door_name = JSON.parse(File.read("#{@@json_dir}/envelope.json"))[run_id]['exterior_door_name']

      # Get U-value of envelope in baseline model
      u_value_baseline = {}
      construction_baseline = {}
      opaque_exterior_name.each do |val|
        u_value_baseline[val[0]] = run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Opaque Exterior', val[0], 'U-Factor with Film', 'W/m2-K').to_f
        construction_baseline[val[0]] = run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Opaque Exterior', val[0], 'Construction', '').to_s
      end
      exterior_fenestration_name.each do |val|
        u_value_baseline[val[0]] = run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Exterior Fenestration', val[0], 'Glass U-Factor', 'W/m2-K').to_f
        construction_baseline[val[0]] = run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Exterior Fenestration', val[0], 'Construction', '').to_s
      end
      exterior_door_name.each do |val|
        u_value_baseline[val[0]] = run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Exterior Door', val[0], 'U-Factor with Film', 'W/m2-K').to_f
        construction_baseline[val[0]] = run_query_tabulardatawithstrings(model_baseline, 'EnvelopeSummary', 'Exterior Door', val[0], 'Construction', '').to_s
      end

      # Check U-value against expected U-value
      u_value_goal = opaque_exterior_name + exterior_fenestration_name + exterior_door_name
      u_value_goal.each do |key, value|
        value_si = OpenStudio.convert(value, 'Btu/ft^2*hr*R', 'W/m^2*K').get
        assert(((u_value_baseline[key] - value_si).abs < 0.001 || u_value_baseline[key] == 5.838), "Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The U-value of the #{key} is #{u_value_baseline[key]} but should be #{value_si}.")
        if key != 'PERIMETER_ZN_3_WALL_NORTH_DOOR1'
          assert((construction_baseline[key].include? 'PRM'), "Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The construction of the #{key} is #{construction_baseline[key]}, which is not from PRM_Construction tab.")
        end
      end
    end
  end

  # Check LPD requirements lookups
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_lpd(prototypes_base)
    prototypes_base.each do |prototype, model_baseline|
      building_type, template, climate_zone, mod = prototype
      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join("_")
      # Define name of spaces used for verification
      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod_str}"
      space_name = JSON.parse(File.read("#{@@json_dir}/lpd.json"))[run_id]

      # Get LPD in baseline model
      lpd_baseline = {}
      space_name.each do |val|
        lpd_baseline[val[0]] = run_query_tabulardatawithstrings(model_baseline, 'LightingSummary', 'Interior Lighting', val[0], 'Lighting Power Density', 'W/m2').to_f
      end

      # Check LPD against expected LPD
      space_name.each do |key, value|
        value_si = OpenStudio.convert(value, 'W/ft^2', 'W/m^2').get
        assert(((lpd_baseline[key] - value_si).abs < 0.001), "Baseline U-value for the #{building_type}, #{template}, #{climate_zone} model is incorrect. The U-value of the #{key} is #{lpd_baseline[key]} but should be #{value_si}.")
      end
    end
  end

  # Check baseline infiltration calculations
  #
  # @param prototypes_base [Hash] Baseline prototypes
  def check_infiltration(prototypes_base)
    std = Standard.build('90.1-PRM-2019')
    space_env_areas = JSON.parse(File.read("#{@@json_dir}/space_envelope_areas.json"))

    # Check that the model_get_infiltration_method and
    # model_get_infiltration_coefficients method retrieve
    # the correct information
    model_blank = OpenStudio::Model::Model.new
    infil_object = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model_blank)
    infil_object.setFlowperExteriorWallArea(0.001)
    infil_object.setConstantTermCoefficient(0.002)
    infil_object.setTemperatureTermCoefficient(0.003)
    infil_object.setVelocityTermCoefficient(0.004)
    infil_object.setVelocitySquaredTermCoefficient(0.005)
    new_space = OpenStudio::Model::Space.new(model_blank)
    infil_object.setSpace(new_space)
    assert(infil_object.designFlowRateCalculationMethod.to_s == std.model_get_infiltration_method(model_blank), 'Error in infiltration method retrieval.')
    assert(std.model_get_infiltration_coefficients(model_blank) == [infil_object.constantTermCoefficient,
                                                                    infil_object.temperatureTermCoefficient,
                                                                    infil_object.velocityTermCoefficient,
                                                                    infil_object.velocitySquaredTermCoefficient], 'Error in infiltration coeffcient retrieval.')

    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, mod = prototype
      
      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join("_")

      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod_str}"

      # Check if the space envelope area calculations
      spc_env_area = 0
      model.getSpaces.sort.each do |spc|
        spc_env_area += std.space_envelope_area(spc, climate_zone)
      end
      assert((space_env_areas[run_id].to_f - spc_env_area.round(2)).abs < 0.001, "Space envelope calculation is incorrect for the #{building_type}, #{template}, #{climate_zone} model: #{spc_env_area} (model) vs. #{space_env_areas[run_id]} (expected).")

      # Check that infiltrations are not assigned at
      # the space type level
      model.getSpaceTypes.sort.each do |spc|
        assert(false, "The baseline for the #{building_type}, #{template}, #{climate_zone} model has infiltration specified at the space type level.") unless spc.spaceInfiltrationDesignFlowRates.empty?
      end

      # Back calculate the I_75 (cfm/ft2), expected value is 1 cfm/ft2 in 90.1-PRM-2019
      conv_fact = OpenStudio.convert(1, 'm^3/s', 'ft^3/min').to_f / OpenStudio.convert(1, 'm^2', 'ft^2').to_f
      assert((std.model_current_building_envelope_infiltration_at_75pa(model, spc_env_area) * conv_fact).round(2) == 1.0, 'The baseline air leakage rate of the building envelope at a fixed building pressure of 75 Pa is different that the requirement (1 cfm/ft2).')
    end
  end

  # Check hvac baseline system type selections
  # Expected outcome depends on prototype name and 'mod' variation defined with 
  #
  # @param prototypes_base [Hash] Baseline prototypes

  #DEM: questions:
  # what does "mod = prototype" do?

  def check_hvac_type(prototypes_base)

    prototypes_base.each do |prototype, model|
      building_type, template, climate_zone, mod = prototype
      
      # Concatenate modifier functions and arguments
      mod_str = mod.flatten.join("_")

      run_id = "#{building_type}_#{template}_#{climate_zone}_#{mod_str}"
      
    if building_type == 'MidriseApartment' && mod_str == ''
      # Residential model should be ptac or pthp, depending on climate
      check_if_pkg_terminal(model, climate_zone, "MidriseApartment")
    elsif @bldg_type_alt_now == 'Assembly' && building_type == 'MediumOffice'
      # This is a public assembly < 120 ksf, should be PSZ
      check_if_psz(model, "Assembly < 120,000 sq ft.")
    elsif @bldg_type_alt_now == 'Assembly' && building_type == 'HotelLarge'
      # This is a public assembly > 120 ksf, should be SZ-CV
      check_if_psz(model, "Assembly < 120,000 sq ft.")
    elsif building_type == 'Warehouse' && mod_str == ''
      # System type should be heating and ventilating
      # check_if_ht_vent(model, "Warehouse")
    elsif building_type == 'RetailStripmall' && mod_str == ''
      # System type should be PSZ
      check_if_psz(model, "RetailStripmall, one story, any area")
    elsif @bldg_type_alt_now == 'retail' && building_type == 'SchoolPrimary'
      # Single story retail is PSZ, regardless of floor area
      check_if_psz(model, "retail, one story, floor area > 25 ksf.")
    elsif building_type == 'RetailStripmall' && mod_str == 'set_zone_multiplier_3'
      # System type should be PVAV with 10 zones
      check_if_pvav(model, "retail > 25,000 sq ft, 3 stories")
    elsif building_type == 'OfficeSmall' && mod_str == ''
      # System type should be PSZ
      check_if_psz(model, "non-res, one story, < 25 ksf")
      check_heat_type(model, "nonres", "HP")
    elsif building_type == 'SchoolPrimary' && mod_str == ''
      # System type should be PVAV, some zones may be on PSZ systems
      check_if_pvav(model, "nonres > 25,000 sq ft, < 150 ksf , 1 story")
      check_heat_type(model, "nonres", "ER")
    elsif building_type == 'SchoolSecondary' && mod_str == ''
      # System type should be VAV/chiller
      check_if_pvav(model, "nonres > 150 ksf , 1 to 3 stories")
      check_heat_type(model, "nonres", "HP")
    elsif building_type == 'SmallOffice' && mod_str == 'set_zone_multiplier_4'
      # nonresidential, 4 to 5 stories, <= 25 ksf --> PVAV
      # System type should be PVAV with 10 zones, area is 22,012 sf
      check_if_pvav(model, "other nonres > 4 to 5 stories, <= 25 ksf")
    elsif building_type == 'SmallOffice' && mod_str == 'set_zone_multiplier_5'
      # nonresidential, 4 to 5 stories, <= 150 ksf --> PVAV
      # System type should be PVAV with 10 zones, area is 27,515 sf
      check_if_pvav(model, "other nonres > 4 to 5 stories, <= 150 ksf")
    elsif building_type == 'SchoolPrimary' && mod_str == 'set_zone_multiplier_4'
      # nonresidential, 4 to 5 stories, > 150 ksf --> VAV/chiller
      # System type should be PVAV with 10 zones, area is 22,012 sf
      check_if_vav_chiller(model, "other nonres > 4 to 5 stories, > 150 ksf")
    elsif building_type == 'SmallOffice' && mod_str == 'set_zone_multiplier_6'
      # 6+ stories, any floor area --> VAV/chiller
      # This test has floor area 33,018 sf 
      check_if_vav_chiller(model, " other nonres > 6 stories")
    elsif @bldg_type_alt_now == 'hospital' && building_type == 'OfficeSmall'
      # Hospital < 25 ksf is PVAV; different rule than non-res
      check_if_pvav(model, "hospital, floor area < 25 ksf.")
    elsif building_type == 'Hospital' && mod_str == ''
      # System type should be VAV/chiller, area is 241 ksf
      check_if_vav_chiller(model, "hospital > 4 to 5 stories, > 150 ksf")
    elsif mod[0] == 'MakeLabHighDistribZoneExh' || mod[0] == 'MakeLabHighSystemExh'
      # All labs on a given floor of the building should be on a separate MZ system
      model.getAirLoopHVACs.each do |air_loop|
          # identify hours of operation
          has_lab = false
          has_nonlab = false
          air_loop.thermalZones.each do |thermal_zone|
            thermal_zone.spaces.each do |space|
              space_type = space.spaceType.get.standardsSpaceType.get
              if space_type == 'laboratory'
                has_lab = true
              else
                has_nonlab = true
              end
            end
          end
          assert(!(has_lab == true and has_nonlab == true), "System #{air_loop.name} has lab and nonlab spaces and lab exhaust > 15,000 cfm.")
        end    
    elsif mod[0] == 'MakeLabLowDistribZoneExh'
      # Labs on a given floor of the building should be mixed with other space types on the main MZ system
      model.getAirLoopHVACs.each do |air_loop|
        # identify hours of operation
        has_lab = false
        has_nonlab = false
        air_loop.thermalZones.each do |thermal_zone|
          thermal_zone.spaces.each do |space|
            space_type = space.spaceType.get.standardsSpaceType.get
            if space_type == 'laboratory'
              has_lab = true
            else
              has_nonlab = true
            end
          end
        end
        assert(!(has_lab == true and has_nonlab == false), "System #{air_loop.name} has only lab spaces and lab exhaust < 15,000 cfm.")

      end
    end

    end

  end

  # Check whether heat type meets expectations
  # 
  def check_heat_type(model, climate_zone, sys_flag, expected_heat_type)
    if sys_flag == "MZ"
      # Check air loops that have more than one zone  
      model.getAirLoopHVACs.each do |air_loop|
        num_zones = air_loop.thermalZones.size
        if num_zones > 1

  end

  # Get list of fuels for a given air loop
  def airloop_heating_fuels(air_loop)

    air_loop.supplyComponents.each do |component|
      # Get the object type
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_AirLoopHVAC_UnitaryHeatCool_VAVChangeoverBypass'
        component = component.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get
        fuels += self.coil_heating_fuels(component.heatingCoil)
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        fuels += self.coil_heating_fuels(component.heatingCoil)
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir_MultiSpeed'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get
        fuels += self.coil_heating_fuels(component.heatingCoil)
      when 'OS_AirLoopHVAC_UnitarySystem'
        component = component.to_AirLoopHVACUnitarySystem.get
        if component.heatingCoil.is_initialized
          fuels += self.coil_heating_fuels(component.heatingCoil.get)
        end
      when 'OS_Coil_Heating_DX_MultiSpeed'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_DX_SingleSpeed'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_DX_VariableSpeed'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Desuperheater'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Electric'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Gas'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Gas_MultiStage'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_Water'
        fuels += self.coil_heating_fuels(component)  
      when 'OS_Coil_Heating_WaterToAirHeatPump_EquationFit'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_Heating_WaterToAirHeatPump_VariableSpeed_EquationFit'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_WaterHeating_AirToWaterHeatPump'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Coil_WaterHeating_Desuperheater'
        fuels += self.coil_heating_fuels(component)
      when 'OS_Node', 'OS_Fan_ConstantVolume', 'OS_Fan_VariableVolume', 'OS_AirLoopHVAC_OutdoorAirSystem'
        # To avoid extraneous debug messages  
      else
        #OpenStudio::logFree(OpenStudio::Debug, 'openstudio.sizing.Model', "No heating fuel types found for #{obj_type}")
      end
    end    

    return fuels.uniq.sort
  

  end


  # Check if all baseline system types are PSZ
  def check_if_psz(model, sub_text)
    num_zones = 0
    num_dx_coils = 0
    num_dx_coils += model.getCoilCoolingDXSingleSpeeds.size
    num_dx_coils += model.getCoilCoolingDXTwoSpeeds.size
    num_dx_coils += model.getCoilCoolingDXMultiSpeeds.size
    has_chiller = model.getPlantLoopByName('Chilled Water Loop').is_initialized
    model.getAirLoopHVACs.each do |air_loop|
      num_zones = air_loop.thermalZones.size
      # if num zones is greater than 1 for any system, then set as multizone
      assert(num_zones = 1 && num_dx_coils > 0 && has_chiller == false, "Baseline system selection failed for #{air_loop.name}; should be PSZ for " + sub_text)
    end
  end

  # Check if any baseline system type is PVAV
  def check_if_pvav(model, sub_text)
    num_zones = 0
    num_dx_coils = 0
    num_dx_coils += model.getCoilCoolingDXSingleSpeeds.size
    num_dx_coils += model.getCoilCoolingDXTwoSpeeds.size
    num_dx_coils += model.getCoilCoolingDXMultiSpeeds.size
    has_chiller = model.getPlantLoopByName('Chilled Water Loop').is_initialized
    has_multizone = false
    model.getAirLoopHVACs.each do |air_loop|
      num_zones = air_loop.thermalZones.size
      # if num zones is greater than 1 for any system, then set as multizone
      if numzones > 1
        has_multizone = true
      end
    end
    assert(has_multizone && num_dx_coils > 0 && has_chiller == false, "Baseline system selection failed; should be PVAV for " + sub_text)
  end

  # Check if building has baseline VAV/chiller for at least one air loop
  def check_if_vav_chiller(model, sub_text)
    num_zones = 0
    num_dx_coils = 0
    has_chiller = model.getPlantLoopByName('Chilled Water Loop').is_initialized
    has_multizone = false
    model.getAirLoopHVACs.each do |air_loop|
      num_zones = air_loop.thermalZones.size
      # if num zones is greater than 1 for any system, then set as multizone
      if numzones > 1
        has_multizone = true
      end
    end
    assert(has_multizone && has_chiller, "Baseline system selection failed for #{air_loop.name}; should be VAV/chiller for " + sub_text)
  end

  # Check if baseline system type is PTAC or PTHP
  def check_if_pkg_terminal(model, climate_zone, sub_text)
    pass_test = true
    # building fails if any zone is not packaged terminal unit
    # or if heat type is incorrect
    model.getThermalZones.sort.each do |thermal_zone|
      has_ptac = false
      has_pthp = false
      has_unitheater = false
      thermal_zone.equipment.each do |equip|
        # Skip HVAC components
        next unless equip.to_HVACComponent.is_initialized
        equip = equip.to_HVACComponent.get
        if equip.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          has_ptac = true
        elsif equip.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          has_pthp = true
        elsif equip.to_ZoneHVACUnitHeater.is_initialized
          has_unitheater = true
        end
      end
      # Test for hvac type by climate
      if climate_zone =~ /0A|0B|1A|1B|2A|2B|3A/
        if has_pthp == false
          pass_test = false
        end
      else
        if has_ptac == false
          pass_test = false
        end
      end
    end
    if climate_zone =~ /0A|0B|1A|1B|2A|2B|3A/
      assert(pass_test , "Baseline system selection failed for climate #{climate_zone}: should be PTHP for " + subtext)
    else
      assert(pass_test , "Baseline system selection failed for climate #{climate_zone}: should be PTAC for " + subtext)
    end

  end

  # Set ZoneMultiplier
  def set_zone_multiplier(model, arguments)
    mult = arguments[0]
    model.getAirLoopHVACs.each do |air_loop|
      air_loop.thermalZones.each do |thermal_zone|
        thermal_zone.setMultiplier(mult)
      end
    end
    return model
  end

  # Change classroom space types to laboratory
  # Resulting in > 15,000 cfm lab exhaust
  # Add an exhaust fan to each zone
  def MakeLabHighDistribZoneExh(model, arguments)
    # Convert all classrooms to laboratory
    convert_spaces_to_laboratory(model, 'PrimarySchoolClassroom')

    # add exhaust fans to lab zones
    add_exhaust_fan_per_zone(model)

    return model
  end

  # Change computer classroom space types to laboratory
  # Resulting in < 15,000 cfm lab exhaust
  # Add an exhaust fan to each zone
  def MakeLabLowDistribZoneExh(model, arguments)
    convert_spaces_to_laboratory(model, 'PrimarySchoolComputerRoom')
    # Populate hash to allow this space type to persist when protoype space types are replaced later
 
    # add exhaust fans to lab zones
    add_exhaust_fan_per_zone(model)

    return model
  end

  # Change classroom space types to laboratory
  # Resulting in > 15,000 cfm lab exhaust
  # Add an exhaust fan to each zone
  def MakeLabHighSystemExh(model, arguments)
    # Convert all classrooms to laboratory
    convert_spaces_to_laboratory(model, 'PrimarySchoolClassroom')

    # reset OA make lab space OA exceed 17,000 cfm
    oa_name = 'PrimarySchool Classroom Ventilation'
    model.getDesignSpecificationOutdoorAirs.sort.each do |oa_def|
      if oa_def.name.to_s == oa_name
        oa_area = oa_def.outdoorAirFlowperFloorArea
        oa_def.setOutdoorAirFlowperFloorArea(0.0029)
      end
    end  
    return model
  end

  def convert_spaces_to_laboratory(model, bldg_space_to_convert)
    # Convert all spaces of type to convert to laboratory
    model.getSpaceTypes.sort.each do |space_type|
      next if space_type.floorArea == 0

      standards_space_type = if space_type.standardsSpaceType.is_initialized
                               space_type.standardsSpaceType.get
                             end
      std_bldg_type = space_type.standardsBuildingType.get
      bldg_type_space_type = std_bldg_type + space_type.standardsSpaceType.get
      # DEM: puts "std_bldg_type_sptyp = #{bldg_type_space_type}"
      if bldg_type_space_type == bldg_space_to_convert
        space_type.setStandardsSpaceType('laboratory')
        # Populate hash to allow this space type to persist when protoype space types are replaced later
        @lpd_space_types_alt[std_bldg_type + 'laboratory'] = 'laboratory'
      end
    end
  end

  def add_exhaust_fan_per_zone(model)
    model.getThermalZones.sort.each do |thermal_zone|
      lab_is_found = false
      zone_area = 0
      thermal_zone.spaces.each do |space|
        space_type = space.spaceType.get.standardsSpaceType.get
        if space_type == 'laboratory'
          lab_is_found = true
          zone_area += space.floorArea
        end
      end
      if lab_is_found == true      
        # add an exhaust fan
        zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(model)
        zone_exhaust_fan.setName(thermal_zone.name.to_s + ' Exhaust Fan')
        zone_exhaust_fan.setFanEfficiency(0.6)
        zone_exhaust_fan.setPressureRise(200)

        # set air flow above threshold for isolation of lab spaces on separate hvac system
        # A rate of 0.5 cfm/sf gives 17,730 cfm total exhaust
        exhaust_cfm = 0.5 * zone_area
        maximum_flow_rate = OpenStudio.convert(exhaust_cfm, 'cfm', 'm^3/s').get
        zone_exhaust_fan.setMaximumFlowRate(maximum_flow_rate)
        zone_exhaust_fan.setEndUseSubcategory('Zone Exhaust Fans')
        zone_exhaust_fan.addToThermalZone(thermal_zone)
      end
    end

  end

  def change_bldg_type(model, arguments)
    bldg_type_new = arguments[0]
    @bldg_type_alt_now = bldg_type_new
    return model
    end


  # Run test suite for the ASHRAE 90.1 appendix G Performance
  # Rating Method (PRM) baseline automation implementation
  # in openstudio-standards.
  def test_create_prototype_baseline_building
    # Select test to run
    tests = [
      # 'wwr',
      # 'envelope',
      # 'lpd',
      # 'isresidential',
      # 'daylighting_control',
      # 'infiltration',
      'hvac_baseline'
    ]

    # Get list of unique prototypes
    prototypes_to_generate = get_prototype_to_generate(tests, @@prototype_list)
    puts "DEM: ---------after prototypes_to_generate"
    # Generate all unique prototypes
    prototypes_generated = generate_prototypes(prototypes_to_generate)
    puts "DEM: ---------after prototypes_generated"
    # Create all unique baseline
    prototypes_baseline_generated = generate_baseline(prototypes_generated, prototypes_to_generate)
    puts "DEM: ---------after baseline_generated"
    # Assign prototypes and baseline to each test
    prototypes = assign_prototypes(prototypes_generated, tests, prototypes_to_generate)
    puts "DEM: ---------after assign_prototypes_1"
    prototypes_base = assign_prototypes(prototypes_baseline_generated, tests, prototypes_to_generate)
    puts "DEM: ---------after assign_prototypes_2"
    # Run tests
    check_wwr(prototypes_base['wwr']) unless !(tests.include? 'wwr')
    check_daylighting_control(prototypes_base['daylighting_control']) unless !(tests.include? 'daylighting_control')
    check_residential_flag(prototypes_base['isresidential']) unless !(tests.include? 'isresidential')
    check_envelope(prototypes_base['envelope']) unless !(tests.include? 'envelope')
    check_lpd(prototypes_base['lpd']) unless !(tests.include? 'lpd')
    check_infiltration(prototypes_base['infiltration']) unless !(tests.include? 'infiltration')
    check_hvac_type(prototypes_base['hvac_baseline']) unless !(tests.include? 'hvac_baseline')
  end
end
