require 'fileutils'
require 'find'

output_dir = "#{Dir.pwd}/output"
# list the building types, vintages and climate zones that will be archived.
building_types = ['RetailStandalone', 'RetailStripmall']
vintages = ['DOE Ref 1980-2004', '90.1-2010']
# climate_zones = ['ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A','ASHRAE 169-2006-2B',
                 # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A',
                 # 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B',
                 # 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-8A'] 
climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
# create archive folder
archive_dir = "#{Dir.pwd}/Archive"
Dir.mkdir(archive_dir) unless Dir.exist?(archive_dir)
# copy the key results to the Archive folder
building_types.each do |building_type|
  vintages.each do |vintage|
    climate_zones.each do |climate_zone|
      puts "Archiving #{building_type}-#{vintage}-#{climate_zone}"
      archive_files = Array.new
      archive_file_dir = "#{Dir.pwd}/Archive/#{building_type}-#{vintage}-#{climate_zone}"
      Dir.mkdir(archive_file_dir) unless Dir.exist?(archive_file_dir)
      Find.find(output_dir) do |path|
        # # narrow down to the building_type-climate-vintage, and create a folder for archived files
        if path =~ /#{building_type}/i && path =~ /#{vintage}/i && path =~ /#{climate_zone}/i
          # find the OSM model
          if path.include? "final.osm"
            archive_files << path
          # find the idf model
          elsif path.scan(/#{building_type}/).length == 2
            archive_files << path
          # find the EnergyPlus result html file
          elsif path =~ /AnnualRun/i && path =~ /EnergyPlus/i && path =~ /eplustbl.htm/i
            archive_files << path
          end
        end
      end
      FileUtils.cp(archive_files,archive_file_dir)
    end
  end
end
