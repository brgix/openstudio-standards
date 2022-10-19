class ASHRAE9012016 < ASHRAE901
  # @!group AirLoopHVAC

  # Minimum zone ventilation efficiency for multizone system outdoor
  # air calculations
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @return [Float] minimum zone ventilation efficiency
  def air_loop_hvac_minimum_zone_ventilation_efficiency(air_loop_hvac)
    return 0.6
  end
  end
