# frozen_string_literal: true

require_relative "lib/side_bro/version"

Gem::Specification.new do |spec|
  spec.name = "side_bro"
  spec.version = SideBro::VERSION
  spec.authors = ["Ruby Dev SRL"]
  spec.email = ["office@rubydev.ro"]

  spec.summary = "A Rack-mountable Sidekiq Web UI alternative"
  spec.description = "SideBro is a Rack-mountable alternative to Sidekiq's built-in Web UI, providing the same features with a customizable design."
  spec.homepage = "https://www.rubydev.ro"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rubydevro/side_bro"
  spec.metadata["changelog_uri"] = "https://github.com/rubydevro/side_bro/blob/master/CHANGELOG.md"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 2.2"
  spec.add_dependency "rack-session", ">= 1.0"
  spec.add_dependency "sidekiq", ">= 6.5"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
