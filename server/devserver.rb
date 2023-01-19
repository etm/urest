#!/usr/bin/ruby
$dev = true
require_relative '../lib/urest'
### add stuff if necessary

Riddl::Server.new(UREST::SERVER, :host => 'localhost', :port => 8198) do |opts|
  accessible_description true
  cross_site_xhr true
  process_out false

  use UREST::implementation(opts)
end.loop!
