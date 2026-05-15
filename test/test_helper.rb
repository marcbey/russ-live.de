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
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, threshold: 200)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include AuthenticationTestHelper
  end
end
