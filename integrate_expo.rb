#!/usr/bin/env ruby
# Wire the KeePassiumExpoArtifacts local Swift Package into KeePassium.xcodeproj
# for the KeePassium iOS app target. Idempotent.

require 'xcodeproj'

PROJ_PATH = '/Users/briones/Developer/KeePassium/KeePassium.xcodeproj'
PKG_REL_PATH = 'expo-app/artifacts/KeePassiumExpoArtifacts'
PKG_PRODUCTS = %w[KeePassiumExpo hermesvm React ReactNativeDependencies ExpoModulesJSI]
TARGET_NAME = 'KeePassium'

project = Xcodeproj::Project.open(PROJ_PATH)
target = project.targets.find { |t| t.name == TARGET_NAME }
raise "Target #{TARGET_NAME} not found" unless target

# Expo SDK 56 needs IPHONEOS_DEPLOYMENT_TARGET >= 16.4. KeePassium's internal
# KeePassiumLib is on 17.0, so leave the host target at whatever it already
# was (>=17 satisfies the brownfield minimum). If it's blank, force 17.0.
target.build_configurations.each do |c|
  current = c.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
  if current.nil? || current.to_s.strip.empty?
    c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    puts "✓ Set IPHONEOS_DEPLOYMENT_TARGET = 17.0 on #{TARGET_NAME} [#{c.name}] (was empty)"
  else
    puts "⊙ IPHONEOS_DEPLOYMENT_TARGET = #{current} on #{TARGET_NAME} [#{c.name}] (kept)"
  end
end

# KeePassium uses Xcode's synchronized-folder group (PBXFileSystemSynchronizedRootGroup),
# so any new .swift file dropped into the synced folder is auto-included in the target.
# `KeePassium/ExpoIntegration.swift` is picked up automatically — no project edit needed.
puts "⊙ ExpoIntegration.swift picked up via synchronized folder group"

# Add local Swift Package reference at project level.
package_ref = project.root_object.package_references.find do |r|
  r.is_a?(Xcodeproj::Project::Object::XCLocalSwiftPackageReference) &&
    r.relative_path == PKG_REL_PATH
end
unless package_ref
  package_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  package_ref.relative_path = PKG_REL_PATH
  project.root_object.package_references << package_ref
  puts "✓ Added local Swift Package reference -> #{PKG_REL_PATH}"
else
  puts "⊙ Local Swift Package reference already present"
end

# Attach each product as a target dependency + framework link.
PKG_PRODUCTS.each do |product_name|
  existing = target.package_product_dependencies.find { |d| d.product_name == product_name }
  if existing
    puts "⊙ #{product_name} already linked"
    next
  end
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = package_ref
  dep.product_name = product_name
  target.package_product_dependencies << dep

  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  target.frameworks_build_phase.files << build_file
  puts "✓ Linked #{product_name}"
end

project.save
puts "DONE"
