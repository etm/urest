require 'rake'
require 'rubygems/package_task'

spec = eval(File.read('urest.gemspec'))

task :default => [:gem]

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
  FileUtils.mkdir 'pkg' rescue nil
  FileUtils.rm_rf Dir.glob('pkg/*')
  FileUtils.ln_sf "#{pkg.name}.gem", "pkg/#{spec.name}.gem"
end

task :push => :gem do |r|
  `gem push pkg/urest.gem`
end

task :install => :gem do |r|
  `gem install pkg/urest.gem`
end
