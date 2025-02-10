Gem::Specification.new do |s|
  s.name             = "urest"
  s.version          = "0.99.2"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3.0-or-later"
  s.summary          = "REST Server for Universal Robots"

  s.description      = "REST Server for Universal Robots. See https://github.com/etm/urest"

  s.files            = Dir['{lib/**/*.rb,lib/**/*.xml,lib/**/*.conf,tools/**/*.rb,server/**/*}'] + %w(LICENSE Rakefile README.md AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.bindir           = 'tools'
  s.executables      = ['urest']

  s.required_ruby_version = '>=2.4.0'

  s.authors          = ['Juergen eTM Mangler']

  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'https://github.com/etm/urest'

  s.add_runtime_dependency 'riddl', '~>0', '>=0.120'
  s.add_runtime_dependency 'ur-sock', '~>1.0'
  s.add_runtime_dependency 'daemonite', '~>0.5', '>=0.5.9'
  s.add_runtime_dependency 'net-ssh', '~>7.0'
  s.add_runtime_dependency 'net-scp', '~>4.0'
end
