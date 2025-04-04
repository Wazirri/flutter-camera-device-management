# Flutter podhelper - customized to avoid POD_CONFIGURATION_DEBUG macro redefinition warnings

require 'json'
require 'open3'

# Custom install method to fix macro redefinition issues
def flutter_fix_pod_macro_redefinition(installer)
  installer.pod_targets.each do |pod|
    pod.target_definitions.each do |target_definition|
      next unless target_definition.name.end_with?('Debug')
      
      # Get all xcconfig files for the debug configuration
      debug_xcconfigs = pod.xcconfig_paths.select { |path| path.downcase.include?('debug') }
      
      debug_xcconfigs.each do |config_path|
        file_content = File.read(config_path)
        
        # If POD_CONFIGURATION_DEBUG is defined without a guard, add a guard
        if file_content.include?('POD_CONFIGURATION_DEBUG') && !file_content.include?('#ifndef POD_CONFIGURATION_DEBUG')
          new_content = file_content.gsub(/#define\s+POD_CONFIGURATION_DEBUG\s+1/, 
            '#ifndef POD_CONFIGURATION_DEBUG' + "\n" + 
            '#define POD_CONFIGURATION_DEBUG 1' + "\n" + 
            '#endif')
          
          File.write(config_path, new_content)
        end
      end
    end
  end
end

# Hook to run at the end of pod installation
def flutter_post_install(installer)
  # Fix the macro redefinition warnings by adding guards
  flutter_fix_pod_macro_redefinition(installer)
end