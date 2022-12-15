require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/regression_helper'

class Test_EdgeCaseGeometry_NECB2011_Electricity < NECBRegressionHelper

  def setup
    super()
  end

  test_single_iteration = false
  single_iteration = NIL

  ## There are 15 [0 to 14] iterations in the NECB2011 test set

  (3..5).each do |iteration|
    if test_single_iteration
      unless iteration == single_iteration
        next
      end
    end

    define_method("test_#{iteration}_lsaav") do
      # begin
      result, diff = create_iterative_model_and_regression_test(building_type: 'EdgeCaseGeometry',
                                                                primary_heating_fuel: 'Electricity',
                                                                epw_file:  'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw',
                                                                template: 'NECB2011',
                                                                run_simulation: true,
                                                                iteration: iteration
      )
      if result == false
        puts "JSON terse listing of diff-errors."
        puts diff
        puts "Pretty listing of diff-errors for readability."
        puts JSON.pretty_generate( diff )
        puts "You can find the saved json diff file here test/necb/regression_models/FullServiceRestaurant-BTAP1980TO2010-Electricity_CAN_AB_Calgary.Intl.AP.718770_CWEC2016_diffs.json"
        puts "outputing errors here. "
        puts diff["diffs-errors"] if result == false
      end
      assert(result, diff)
    end
  end

end


