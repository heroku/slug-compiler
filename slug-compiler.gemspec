# -*- ruby -*-

Gem::Specification.new do |gem|
  gem.authors       = ["Noah Zoschke", "Phil Hagelberg"]
  gem.email         = ["phil.hagelberg@heroku.com"]
  gem.description   = %q{Turn application source into deployable slugs}
  gem.summary       = %q{Turn application source into deployable slugs}
  gem.homepage      = "https://github.com/heroku/slug-compiler"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "slug-compiler"
  gem.require_paths = ["lib"]
  gem.version       = "2.0.0-pre1"

  gem.add_development_dependency "rake"
end
