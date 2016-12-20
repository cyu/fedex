require 'fedex/request/base'

module Fedex
  module Request
    class Registration < Base
      
      def initialize(credentials, options={})
        requires!(options, :child_account_number, :shipper, :user_contact)
        @credentials = credentials
        @child_account_number, @shipper, @user_contact, @secondary_email = options[:child_account_number], options[:shipper], options[:user_contact], options[:secondary_email]
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
          response[:register_web_user_reply][:user_credential]
        else
          error_message = if response[:register_web_user_reply]
            [response[:register_web_user_reply][:notifications]].flatten.first[:message]
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

      def add_categories(xml)
        xml.Categories 'SHIPPING'
      end

      def add_shipping_address(xml)
        xml.ShippingAddress{
          Array(@shipper[:address]).take(2).each do |address_line|
            xml.StreetLines address_line
          end
          xml.City                @shipper[:city]
          xml.StateOrProvinceCode @shipper[:state]
          xml.PostalCode          @shipper[:postal_code]
          xml.CountryCode         @shipper[:country]
        }
      end 

      def add_user_contact_and_address(xml)
				xml.UserContactAndAddress{
        	xml.Contact{
          	xml.PersonName{
							xml.FirstName @user_contact[:first_name]
							xml.LastName 	@user_contact[:last_name]
						}
          	xml.CompanyName 					 	@user_contact[:company_name]
						xml.PhoneNumberCountryCode 	@user_contact[:phone_number_country_code]
						xml.PhoneNumberAreaCode 		@user_contact[:phone_number_area_code]
						xml.PhoneNumber							@user_contact[:phone_number]
						xml.EMailAddress						@user_contact[:email]
					}
        	xml.Address{
						Array(@user_contact[:address]).take(2).each do |address_line|
							xml.StreetLines address_line
						end
						xml.City 								@user_contact[:city]
						xml.StateOrProvinceCode	@user_contact[:state]
						xml.PostalCode					@user_contact[:postal_code]
						xml.CountryCode					@user_contact[:country]
					}
				}
      end

      def add_secondary_email(xml)
        xml.SecondaryEmail @secondary_email
      end
      
      # Build xml Fedex Web Service request
      def build_xml
        namespaces = {
          "xmlns" => "http://fedex.com/ws/registration/v#{service[:version]}",
        }
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.RegisterWebUserRequest(namespaces){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_transaction_detail(xml)
            add_version(xml)
            add_categories(xml)
            add_shipping_address(xml)
            add_user_contact_and_address(xml)
            add_secondary_email(xml)	
          }
        end
        builder.doc.root.to_xml
      end

      def service
        {:id => 'fcas', :version => 7}
      end

      # Successful request
      def success?(response)
        response[:register_web_user_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:register_web_user_reply][:highest_severity])
      end

    end
  end
end
