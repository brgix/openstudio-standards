require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'


#This test will check that TBD is correctly deployed within BTAP.
class NECB_TBD_Tests < Minitest::Test
  def test_necb_tbd()

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_necb_tbd')
    @expected_results_file = File.join(__dir__, '../expected_results/necb_tbd_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/necb_tbd_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')
    @test_results_array = [] # test results storage array

    # Intial test condition.
    @test_passed = true

    #Range of test options.
    @templates = [
      'NECB2011',
      'NECB2015',
      'NECB2017'
    ]

    @epws = ['CAN_AB_Banff.CS.711220_CWEC2016.epw']

    @buildings = [
        'FullServiceRestaurant',
        # 'HighriseApartment',
        # 'Hospital',
        # 'LargeHotel',
        # 'LargeOffice',
        # 'MediumOffice',
        # 'MidriseApartment',
        # 'Outpatient',
        # 'PrimarySchool',
        # 'QuickServiceRestaurant',
        # 'RetailStandalone',
        # 'SecondarySchool',
        # 'SmallHotel',
        # 'Warehouse'
    ]

    @fuels = ['Electricity']

    # Optional PSI factor sets (e.g. optional for pre-NECB2017 templates. If
    # :none, neither TBD 'uprating' nor 'derating' calculations (and subsequent
    # modifications to generated OpenStudio models) are carried out. If instead
    # set to :uprate, psi factor sets are determined iteratively, see:
    #
    #   lib/openstudio-standards/btap/bridging.rb
    #
    # Otherwise, :bad vs :good PSI factor sets refer to costed BTAP details.
    @qualities = [:none, :bad, :good, :uprate]

    @templates.sort.each         do |template|
      @epws.sort.each            do |epw     |
        @buildings.sort.each     do |building|
          @fuels.sort.each       do |fuel    |
            @qualities.sort.each do |quality |

              st = Standard.build(template)
              model = st.model_create_prototype_model(template:template,
                                           epw_file: epw,
                                           building_type: building,
                                           primary_heating_fuel: fuel,
                                           tbd_option: quality,
                                           sizing_run_dir: @sizing_run_dir)

              model.getSurfaces.each do |surface|
                id = surface.nameString
                conditions = surface.outsideBoundaryCondition.downcase
                next unless conditions == "outdoors"

                lc = surface.construction
                assert(lc.is_initialized, "Empty #{id} construction")
                next unless lc.is_initialized

                lc = lc.get.to_LayeredConstruction
                assert(lc.is_initialized, "Empty #{id} layered construction")
                next unless lc.is_initialized

                derated = lc.get.nameString.downcase.include?(" c tbd")
                err_msg = "Failed TBD processes for #{template}: #{building}"

                assert(derated == false, err_msg)     if quality == :none
                assert(derated == true,  err_msg) unless quality == :none

                # Additional assertions could include:
                #   - which uprated buildings fail to uprate
                #   - 'assert_in_delta' checks of heat loss from thermal
                #     bridging for some key, pre-selected surfaces
              end

            end   # @qualities.each      do |quality |
          end     # @fuels.sort.each     do |fuel    |
        end       # @buildings.sort.each do |building|
      end         # @epws.sort.each      do |epw     |
    end           # @templates.sort.each do |template|


    # Save test results to file.
    # File.open(@test_results_file, 'w') do |f|
    #   f.write(JSON.pretty_generate(@test_results_array))
    # end
  end

end
