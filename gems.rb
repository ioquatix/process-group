source 'https://rubygems.org'

gemspec

group :maintenance, optional: true do
	gem "bake-modernize"
	gem "bake-gem"
	
	gem "bake-github-pages"
	gem "utopia-project"
end
