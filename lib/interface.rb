require 'cgi'
require 'hpricot'
require 'net/http'

# TODO: write very good documentation for this.

module ThreeScale
  class Error < StandardError; end
  class InvalidRequest < Error; end
  class TransactionNotFound < Error; end
  class UnknownError < Error; end

  # This class provides interface to 3scale backend server.
  #
  # 
  class Interface

    # Hostname of 3scale server.
    attr_accessor :host

    # Key that uniquely identifies the provider. This key is known only to the
    # provider and to 3scale.
    attr_accessor :provider_private_key

    # Create a 3scale interface instance.
    #
    # == Arguments
    # * +host+::                 Hostname of 3scale backend server.
    # * +provider_private_key+:: Unique key that identifies this provider.
    def initialize(host, provider_private_key)
      @host = host
      @provider_private_key = provider_private_key
    end


    # Start a transaction (service request). This can be used also to send
    # prediction of how much resouces will be spend by this request to 3scale
    # backend server.
    #
    # == Arguments
    # * +user_key+:: Key that uniquely identifies an user of the service.
    # * +reports+::  A hash of that contains metric names and to them
    #                associated amounts of resources spend. For example, if this
    #                request is going to take 10MB of storage space, then this
    #                parameter could contain {'storage' => 10}. The values can
    #                be only approximate or they can be missing altogether. In
    #                these cases, the real values should be reported using
    #                method +confirm+.
    #
    # == Return values
    # A hash containing there keys:
    # * +id+::                  Transaction id. This is required for
    #                           confirmation/cancellation of the transaction
    #                           later.
    # * +provider_public_key+:: This key should be sent back to the user so
    #                           he/she can use it to authenticate the service.
    # * +contract_name+::       This is name of the contract the user is singed
    #                           for. This information can be used to serve
    #                           different responses according to contract types,
    #                           if that is desirable.
    #
    # == Exceptions
    def start(user_key, reports = {})
      uri = URI.parse("#{host}/transactions.xml")
      params = {
        'user_key' => user_key,
        'provider_key' => provider_private_key
      }
      params.merge!(encode_params(reports, 'values'))

      response = Net::HTTP.post_form(uri, params)

      case response
      when Net::HTTPCreated
        element = Hpricot.parse(response.body).at('transaction')
        [:id, :provider_public_key, :contract_name].inject({}) do |memo, key|
          memo[key] = element.at(key).inner_text if element.at(key)
          memo
        end
      when Net::HTTPForbidden, Net::HTTPBadRequest
        raise InvalidRequest, decode_error(response.body)
      else
        raise UnknownError, response.body
      end
    end

    # Confirm previously started transaction.
    def confirm(transaction_id, reports = {})
      uri = URI.parse("#{host}/transactions/#{transaction_id}/confirm.xml")
      params = {
        'provider_key' => provider_private_key
      }
      params.merge!(encode_params(reports, 'values'))

      response = Net::HTTP.post_form(uri, params)

      case response
      when Net::HTTPOK
        true
      when Net::HTTPBadRequest, Net::HTTPForbidden
        raise InvalidRequest, decode_error(response.body)
      when Net::HTTPNotFound
        raise TransactionNotFound, decode_error(response.body)
      else
        raise UnknownError
      end
    end

    # Cancel previously started transaction.
    def cancel(transaction_id)

    end

    private

    # Encode hash into form suitable for sending it as params of HTTP request.
    def encode_params(params, prefix)
      params.inject({}) do |memo, (key, value)|
        memo["#{prefix}[#{CGI.escape(key)}]"] = CGI.escape(value.to_s)
        memo
      end
    end

    def decode_error(string)
      element = Hpricot.parse(string).at('errors error')
      element && element.inner_text
    end


    #    # This method checks if transaction the user requested should be allowed.
    #    # That means if it is authorized and various constrains specified by the
    #    # contract are still met.
    #    #
    #    # == Arguments
    #    #
    #    # * user_key - unique key indentifiing a user of the service. This should
    #    #              be part of user's request.
    #    # * provider_key - unique key identifiing a provider
    #    def validate(user_key, provider_key)
    #      check_arguments(user_key, provider_key)
    #
    #      params = {
    #        'user_key' => user_key,
    #        'provider_key' => provider_key
    #      }
    #
    #      uri = "#{@host}/transactions/validate#{self.class.to_query_string(params)}"
    #      handle_response(Net::HTTP.get_response(URI.parse(uri)))
    #    end
    #
    #    # Report 3scale about executed transaction.
    #    #
    #    def report(user_key, provider_key, metrics)
    #      check_arguments(user_key, provider_key)
    #      raise ArgumentError, 'metrics missing' unless metrics
    #
    #      params = {'user_key' => user_key, 'provider_key' => provider_key}
    #      params.merge!(self.class.flatten_hash(metrics, 'metrics'))
    #
    #      uri = "#{@host}/transactions"
    #      handle_response(Net::HTTP.post_form(URI.parse(uri), params))
    #    end
    #
    #    private
    #
    #    def check_arguments(user_key, provider_key)
    #      raise ArgumentError, 'user_key missing' if user_key.to_s.strip.empty?
    #      raise ArgumentError, 'provider_key missing' if provider_key.to_s.strip.empty?
    #    end
    #
    #    # Handle HTTP response
    #    def handle_response(response)
    #      raise STATUSES_TO_ERRORS[response.class], response.body unless response.class == Net::HTTPOK
    #      response.body
    #    end
    #
    #    # Convert hash to query string.
    #    def self.to_query_string(params)
    #      '?' + params.map do |(key, value)|
    #        "#{CGI.escape(key)}=#{CGI.escape(value)}"
    #      end.join('&')
    #    end
    #
    #    def self.flatten_hash(params, prefix)
    #      params.inject({}) do |memo, (key, value)|
    #        memo["#{prefix}[#{CGI.escape(key)}]"] = CGI.escape(value.to_s)
    #        memo
    #      end
    #    end
  end
end