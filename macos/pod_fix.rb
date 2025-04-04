# Run this script to fix the CocoaPods macro redefinition warnings
# Usage: ruby pod_fix.rb

require 'xcodeproj'

# Path to the project
project_path = File.join(File.dirname(__FILE__), 'Pods/Pods.xcodeproj')

if File.exist?(project_path)
  project = Xcodeproj::Project.open(project_path)
  
  # Iterate through all build configurations
  project.build_configurations.each do |config|
    # Check if this is a debug configuration
    if config.name.downcase.include?('debug')
      # Update the GCC_PREPROCESSOR_DEFINITIONS to avoid redefining POD_CONFIGURATION_DEBUG
      # Use the #ifndef guard for the macro
      if config.build_settings['GCC_PREPROCESSOR_DEFINITIONS']
        # Check if the setting already has our fix
        unless config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].any? { |s| s.include?('POD_CONFIGURATION_DEBUG=1') }
          # Add the correctly guarded definition
          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].push('ifndef POD_CONFIGURATION_DEBUG')
          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].push('POD_CONFIGURATION_DEBUG=1')
          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'].push('endif')
        end
      else
        # Create the setting if it doesn't exist
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = ['ifndef POD_CONFIGURATION_DEBUG', 'POD_CONFIGURATION_DEBUG=1', 'endif']
      end
    end
  end
  
  # Save the project
  project.save
  
  puts "Fixed POD_CONFIGURATION_DEBUG macro redefinition warnings in #{project_path}"
else
  puts "Pods project not found at #{project_path}. Have you run 'pod install'?"
end