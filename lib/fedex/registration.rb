require 'fedex'
require 'fedex/credentials'
require 'fedex/request/registration'
require 'fedex/request/subscribe'

module Fedex
  class Registration

    # In order to use Fedex registration API you must first apply for a developer(and later production keys),
    # Visit {http://www.fedex.com/us/developer/ Fedex Developer Center} for more information about how to obtain your keys.
    # @param [String] key - Fedex web service key
    # @param [String] password - Fedex password
    # @param [String] account_number - Fedex account_number
    # @param [String] meter - Fedex meter number
    # @param [String] mode - [development/production]
    #
    # return a Fedex::Registration object
    def initialize(options={}) 
      @credentials = Credentials.new(options)
    end

    # @param [String] child_account_number, A valid fedex account number to register
    # @param [Hash] shipper, A hash containing the shipper information
    # @param [Hash] user_contact, A hash containing user contact and address
    # @param [String] secondary_email, A secondary email address
    def register(options = {})
      Request::Registration.new(@credentials, options).process_request
    end

    def subscribe(options = {})
      Request::Subscribe.new(@credentials, options).process_request
    end

  end
end
