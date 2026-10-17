ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/stuttgart_live_schema"
require_relative "support/russ_live_schema"
require_relative "support/authentication_test_helper"

StuttgartLiveSchema.ensure!
RussLiveSchema.ensure!

module ActiveSupport
  class TestCase
    # macOS libpq can abort in Objective-C initialization after fork on TCP connect.
    # Linux CI keeps parallel workers; macOS follows Stuttgart's serial default.
    parallelize(workers: RUBY_PLATFORM.include?("darwin") ? 1 : :number_of_processors, threshold: 200)

    # Rails reconstructs each worker from the versioned (empty primary) schema.
    # Build shared-source fixtures before transactional tests open separate pools.
    parallelize_setup do
      StuttgartLiveSchema.ensure!
      RussLiveSchema.ensure!
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include AuthenticationTestHelper
  end
end
