# frozen_string_literal: true

require_relative "lib/process/group/version"

Gem::Specification.new do |spec|
	spec.name = "process-group"
	spec.version = Process::Group::VERSION
	
	spec.summary = "Run and manage multiple processes in separate fibers with predictable behaviour."
	spec.authors = ["Samuel Williams", "Dustin Zeisler", "Olle Jonsson"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/ioquatix/process-group"
	
	spec.metadata = {
		"funding_uri" => "https://github.com/sponsors/ioquatix/",
	}
	
	spec.files = Dir.glob('{lib}/**/*', File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 2.0"
	
	spec.add_dependency "process-terminal", "~> 0.2.0"
	
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered"
	spec.add_development_dependency "rspec", "~> 3.9.0"
end
