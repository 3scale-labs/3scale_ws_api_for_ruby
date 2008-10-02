require 'cgi'
require 'hpricot'
require 'net/http'

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

      # Accept also 200 OK, although 201 Created should be returned.
      if response.is_a?(Net::HTTPCreated) || response.is_a?(Net::HTTPOK)
        element = Hpricot.parse(response.body).at('transaction')
        [:id, :provider_public_key, :contract_name].inject({}) do |memo, key|
          memo[key] = element.at(key).inner_text if element.at(key)
          memo
        end
      else
        handle_response(response)
      end
    end

    # Confirm previously started transaction.
    #
    #
    def confirm(transaction_id, reports = {})
      uri = URI.parse("#{host}/transactions/#{CGI.escape(transaction_id.to_s)}/confirm.xml")
      params = {
        'provider_key' => provider_private_key
      }
      params.merge!(encode_params(reports, 'values'))

      handle_response(Net::HTTP.post_form(uri, params))
    end

    # Cancel previously started transaction.
    #
    #
    def cancel(transaction_id)
      uri = URI.parse("#{host}/transactions/#{CGI.escape(transaction_id.to_s)}.xml" +
          "?provider_key=#{CGI.escape(provider_private_key)}")

      response = Net::HTTP.start(uri.host, uri.port) do |http|
        http.delete("#{uri.path}?#{uri.query}")
      end

      handle_response(response)
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

    def handle_response(response)
      case response
      when Net::HTTPOK
        true
      when Net::HTTPForbidden, Net::HTTPBadRequest
        raise InvalidRequest, decode_error(response.body)
      when Net::HTTPNotFound
        raise TransactionNotFound, decode_error(response.body)
      else
        raise UnknownError, response.body
      end
    end
  end
end