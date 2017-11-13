require_relative '../helpers/minitest_helper'

class TestFindTargetEuiByEndUse < Minitest::Test

  def test_eui_by_end_use_check_large_hotel_2007_2a

    # for now this just runs for single building type and climate zone, but could sweep across larger selection
    building_types = ['LargeHotel']
    templates = ['90.1-2007']
    climate_zones = ['2A'] # short version of climate zone is what is used in GUI

    # make an empty model
    model = OpenStudio::Model::Model.new

    # set climate zone and building type
    model.getBuilding.setStandardsBuildingType(building_types.first)
    model.getClimateZones.setClimateZone("ASHRAE",climate_zones.first)

    standard = StandardsModel.get_standard_model(templates.first)
    
    # todo - create space and zone
    # this is needed to break office into small, medium, or large

    # use find_target_eui method to lookup and calculate the target EUI by end use
    # this will also test process_results_for_datapoint and find_prototype_floor_area method
    target_eui_by_end_use = standard.model_find_target_eui_by_end_use(model)
    target_eui_int_equip = target_eui_by_end_use['Interior Equipment']

    puts "target eui for Interior Equipment #{target_eui_int_equip} (GJ/m^2)"

    # below is data from results json for LargeHotel 2007 2A
    electricity = {}
    electricity["Heating"] = 0.0
    electricity["Cooling"] = 4582.51
    electricity["Interior Lighting"] = 1452.45
    electricity["Exterior Lighting"] = 306.36
    electricity["Interior Equipment"] = 1751.31
    electricity["Exterior Equipment"] = 978.17
    electricity["Fans"] = 941.23
    electricity["Pumps"] = 300.56
    electricity["Heat Rejection"] = 0.0
    electricity["Humidification"] = 0.0
    electricity["Heat Recovery"] = 0.0
    electricity["Water Systems"] = 93.11
    electricity["Refrigeration"] = 72.87
    electricity["Generators"] = 0.0

    natural_gas = {}
    natural_gas["Heating"] = 1868.89
    natural_gas["Cooling"] = 0.0
    natural_gas["Interior Lighting"] = 0.0
    natural_gas["Exterior Lighting"] = 0.0
    natural_gas["Interior Equipment"] = 1788.85
    natural_gas["Exterior Equipment"] = 0.0
    natural_gas["Fans"] = 0.0
    natural_gas["Pumps"] = 0.0
    natural_gas["Heat Rejection"] = 0.0
    natural_gas["Humidification"] = 0.0
    natural_gas["Heat Recovery"] = 0.0
    natural_gas["Water Systems"] = 1917.8
    natural_gas["Refrigeration"] = 0.0
    natural_gas["Generators"] = 0.0

    # area for LargeHotel
    large_hotel_area = 11345

    # calculate Interior Equipent EUI
    consumption = 0.0
    consumption += electricity['Interior Equipment']
    consumption += natural_gas['Interior Equipment']
    calc_eui_int_equip = consumption/large_hotel_area
    puts "target eui for Interior Equipment is #{calc_eui_int_equip} (GJ/m^2)"

    assert(target_eui_int_equip == calc_eui_int_equip) # todo - if needed add in tolerance for test, but as is, it passes exact match

  end

  # todo - add test for Office. I need to add in geometry. Make large enough to triger medium or large office.

  # todo - when I support results by end use vs. just total add a test test that.

end
