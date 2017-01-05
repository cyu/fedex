require 'fedex/request/base'

module Fedex
  module Request
    class Delete < Base

      attr_reader :tracking_number

      def initialize(credentials, options={})
        requires!(options, :tracking_number)

        @tracking_number, @child_detail, @debug = options[:tracking_number], options[:child_detail], options[:debug]
        @deletion_control = options[:deletion_control] || 'DELETE_ALL_PACKAGES'
        @credentials  = credentials

        @debug = ENV['DEBUG'] == 'true'
      end

      def process_request
        api_response = self.class.post(api_url, :body => build_xml).parsed_response
        puts api_response if @debug
        response = parse_response(api_response)
        unless success?(response)
          error_message = if response[:shipment_reply]
            [response[:shipment_reply][:notifications]].flatten.first[:message]
          else
            "#{api_response["Fault"]["detail"]["fault"]["reason"]}\n
            --#{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join("\n--")}"
          end rescue $1
          raise RateError, error_message
        end
      end

      private

      # Build xml Fedex Web Service request
      def build_xml
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.DeleteShipmentRequest(:xmlns => "http://fedex.com/ws/ship/v#{service[:version]}"){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_version(xml)
            xml.TrackingId {
              xml.TrackingIdType 'FEDEX'
              xml.TrackingNumber @tracking_number
            }
            xml.DeletionControl @deletion_control
          }
        end
        builder.doc.root.to_xml
      end

      def service
        { :id => 'ship', :version => Fedex::API_VERSION }
      end

      # Successful request
      def success?(response)
        response[:shipment_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:shipment_reply][:highest_severity])
      end
    end
  end
end
