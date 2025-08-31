#!/usr/bin/env ruby

# Script to add Swift files to Xcode project
# This requires xcodeproj gem: gem install xcodeproj

begin
  require 'xcodeproj'
rescue LoadError
  puts "Installing xcodeproj gem..."
  system("gem install xcodeproj")
  require 'xcodeproj'
end

project_path = '/Users/danhart/Developer/AsNeeded/AsNeeded.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Files to add
files_to_add = [
  'AsNeeded/Services/MedicationSearchService.swift',
  'AsNeeded/Views/Components/EnhancedMedicationSearchField.swift'
]

# Find the main target
main_target = project.targets.find { |t| t.name == 'AsNeeded' }

if main_target.nil?
  puts "Could not find AsNeeded target"
  exit 1
end

# Find or create groups
main_group = project.main_group['AsNeeded']
services_group = main_group['Services'] || main_group.new_group('Services')
views_group = main_group['Views'] || main_group.new_group('Views')
components_group = views_group['Components'] || views_group.new_group('Components')

# Add files
files_to_add.each do |file_path|
  full_path = "/Users/danhart/Developer/AsNeeded/#{file_path}"
  
  if File.exist?(full_path)
    file_name = File.basename(file_path)
    
    # Determine which group to add to
    if file_path.include?('Services')
      group = services_group
    elsif file_path.include?('Components')
      group = components_group
    else
      group = main_group
    end
    
    # Check if file already exists in project
    existing_file = group.files.find { |f| f.display_name == file_name }
    
    if existing_file
      puts "File #{file_name} already exists in project"
    else
      # Add file reference
      file_ref = group.new_file(full_path)
      
      # Add to build phase
      main_target.source_build_phase.add_file_reference(file_ref)
      
      puts "Added #{file_name} to project"
    end
  else
    puts "File not found: #{full_path}"
  end
end

# Save project
project.save

puts "Project updated successfully!"