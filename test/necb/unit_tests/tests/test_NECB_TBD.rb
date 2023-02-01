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
    # @templates = [
    #   'NECB2011',
    #   'NECB2015',
    #   'NECB2017'
    # ]

    @templates = ['NECB2011']

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

    # Optional PSI factor sets (e.g. optional for pre-NECB2017 templates). If
    # :none, neither TBD 'uprating' nor 'derating' calculations (and subsequent
    # modifications to generated OpenStudio models) are carried out. If instead
    # set to :uprate, psi factor sets are determined iteratively, see:
    #
    #   lib/openstudio-standards/btap/bridging.rb
    #
    # Otherwise, :bad vs :good PSI factor sets refer to costed BTAP details.
    @options = ['none', 'bad', 'good', 'uprate']
    # @options = ['none']

    fdback = []
    fdback << ""
    fdback << "BTAP/TBD Unit Tests"
    fdback << "~~~~ ~~~~ ~~~~ ~~~~"

    @templates.sort.each       do |template|
      @epws.sort.each          do |epw     |
        @buildings.sort.each   do |building|
          @fuels.sort.each     do |fuel    |
            @options.sort.each do |option  |
              fdback << ""
              fdback << "CASE #{option} | #{building} (#{template})"

              st = Standard.build(template)
              model = st.model_create_prototype_model(template:template,
                                           epw_file: epw,
                                           building_type: building,
                                           primary_heating_fuel: fuel,
                                           tbd_option: option,
                                           sizing_run_dir: @sizing_run_dir)

              # Parallel TBD run on a model clone: compare deratable surfaces
              # that have TBD-assigned heat loss from MAJOR thermal bridging.
              mdl      = OpenStudio::Model::Model.new
              mdl.addObjects(model.toIdfFile.objects)
              TBD.clean!
              args     = { option: "poor (BETBG)" }
              res      = TBD.process(mdl, args)
              surfaces = res[:surfaces]

              model.getSurfaces.each do |surface|
                id = surface.nameString
                err_msg = "BTAP/TBD: Mismatch between surfaces"
                assert(surfaces.key?(id), err_msg)

                next unless surfaces[id].key?(:deratable)
                next unless surfaces[id].key?(:heatloss )
                next unless surfaces[id][:deratable]
                next unless surfaces[id][:heatloss ].abs > TBD::TOL

                lc      = surface.construction
                err_msg = "BTAP/TBD: Empty #{id} construction"
                assert(lc.is_initialized, err_msg)

                lc      = lc.get.to_LayeredConstruction
                err_msg = "BTAP/TBD: Empty #{id} layered construction"
                assert(lc.is_initialized, err_msg)

                nom     = lc.get.nameString.downcase
                derated = nom.include?(" c tbd")
                err_msg = "Failed TBD processes for #{template}: #{building}"
                assert(derated == false, err_msg)     if option == 'none'
                assert(derated == true,  err_msg) unless option == 'none'

                ut  = 1 / TBD.rsi(lc.get, surface.filmResistance)
                ut  = format("%.3f", ut)
                msg = "- '#{id}' derated '#{nom}' Ut #{ut}"        if derated
                msg = "- '#{id}' un-derated '#{nom}' Ut #{ut}" unless derated
                fdback << msg

                # Additional assertions could include:
                #   - which uprated buildings fail to uprate
                #   - 'assert_in_delta' checks of heat loss from thermal
                #     bridging for some key, pre-selected surfaces
              end

            end # @options.each        do |option |
          end   # @fuels.sort.each     do |fuel    |
        end     # @buildings.sort.each do |building|
      end       # @epws.sort.each      do |epw     |
    end         # @templates.sort.each do |template|

    # Temporary.
    fdback.each { |msg| puts msg }

    # Save test results to file.
    # File.open(@test_results_file, 'w') do |f|
    #   f.write(JSON.pretty_generate(@test_results_array))
    # end
  end

end
