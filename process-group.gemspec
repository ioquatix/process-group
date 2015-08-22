# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'process/group/version'

Gem::Specification.new do |spec|
	spec.name          = "process-group"
	spec.version       = Process::Group::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	spec.description   = <<-EOF
	Manages a unix process group for running multiple processes, keeps track of multiple processes and leverages fibers to provide predictable behaviour in complicated process-based scripts.
	EOF
	spec.summary       = %q{Run processes concurrently in separate fibers with predictable behaviour.}
	spec.homepage      = "https://github.com/ioquatix/process-group"
	spec.license       = "MIT"

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]

	spec.required_ruby_version = '>= 2.0'

	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rspec", "~> 3.3.0"
	spec.add_development_dependency "rake"
end
