require 'fedex/request/base'

module Fedex
  module Request
    class Subscribe < Base

      def initialize(credentials, options={})
        requires!(options, :child_account_number, :subscriber, :account_shipping_address)
        @credentials = credentials
        @child_account_number, @subscriber, @account_shipping_address = options[:child_account_number], options[:subscriber], options[:account_shipping_address]
        @debug = ENV['DEBUG'] == 'true'
        # Expects hash with addr and port
        if options[:http_proxy]
          self.class.http_proxy options[:http_proxy][:host], options[:http_proxy][:port]
        end
      end

      def process_request
        api_response = self.class.post api_url, :body => build_xml
        puts api_response if @debug
        response = parse_response(api_response.parsed_response)
        if success?(response)
          response[:subscription_reply][:meter_detail]
        else
          error_message = if response[:subscription_reply]
            [response[:subscription_reply][:notifications]].flatten.first[:message]
          else
            "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n--#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
          end rescue $1
          raise RateError, error_message
        end
      end

      private

      def add_web_authentication_detail(xml)
        xml.WebAuthenticationDetail{
          xml.ParentCredential{
            xml.Key @credentials.key
            xml.Password @credentials.password
          }
          xml.UserCredential{
            xml.Key @credentials.child_key
            xml.Password @credentials.child_password
          }
        }
      end

      def add_client_detail(xml)
        xml.ClientDetail{
          xml.AccountNumber @child_account_number
        }
      end

      def add_transaction_detail(xml)
        xml.TransactionDetail{
          xml.CustomerTransactionId Time.now.utc.iso8601(2)
        }
      end

      def add_csp_type(xml)
        xml.CspType 'TRADITIONAL_API'
      end

      def add_subscriber(xml)
        xml.Subscriber{
          xml.AccountNumber @child_account_number
          xml.Contact{
            xml.PersonName  @subscriber[:name]
            xml.CompanyName @subscriber[:company_name]
            xml.PhoneNumber @subscriber[:phone_number]
          }
          xml.Address{
						Array(@subscriber[:address]).take(2).each do |address_line|
							xml.StreetLines address_line
						end
            xml.City                @subscriber[:city]
            xml.StateOrProvinceCode @subscriber[:state]
            xml.PostalCode          @subscriber[:postal_code]
            xml.CountryCode         @subscriber[:country]
          }
        }
      end

      def add_account_shipping_address(xml)
        xml.AccountShippingAddress{
          Array(@account_shipping_address[:address]).take(2).each do |address_line|
            xml.StreetLines address_line
          end

          xml.City                @account_shipping_address[:city]
          xml.StateOrProvinceCode @account_shipping_address[:state]
          xml.PostalCode          @account_shipping_address[:postal_code]
          xml.CountryCode         @account_shipping_address[:country]
        }
      end

      # Build xml Fedex Web Service request
      def build_xml
        namespaces = {
          "xmlns" => "http://fedex.com/ws/registration/v#{service[:version]}",
        }
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.SubscriptionRequest(namespaces){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_transaction_detail(xml)
            add_version(xml)
            add_csp_type(xml)
            add_subscriber(xml)
            add_account_shipping_address(xml)
          }
        end
        builder.doc.root.to_xml
      end

      def service
        {:id => 'fcas', :version => 7}
      end

      # Successful request
      def success?(response)
        response[:subscription_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:subscription_reply][:highest_severity])
      end

    end
  end
end
 
