# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree_reviews/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_reviews'
  s.version     = SpreeReviews::VERSION
  s.summary     = "Spree Commerce Reviews Extension"
  s.required_ruby_version = '>= 3.2'

  s.author    = 'laaichiu'
  s.email     = 'laaichiu@gmail.com'
  s.homepage  = 'https://github.com/laaichiu/spree_reviews'
  s.license   = 'MIT'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree', '>= 6.0', '< 7.0'

  s.add_development_dependency 'spree_dev_tools', '= 1.0.0.beta2'
end
