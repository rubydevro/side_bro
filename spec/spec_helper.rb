# frozen_string_literal: true

require "rack/test"
require "side_bro"
require "sidekiq/testing"

Sidekiq::Testing.fake!

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Rack::Test::Methods

  config.before(:each) do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
    SideBro::Web.reset!
  end

  def app
    SideBro::Web
  end
end
