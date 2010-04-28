require 'cgi'
require 'uri'
require 'net/http'
require 'nokogiri'

require 'three_scale/response'
require 'three_scale/authorize_response'

module ThreeScale
  Error = Class.new(RuntimeError)
    
  class ServerError < Error
    def initialize(response)
      super('server error')
      @response = response
    end

    attr_reader :response
  end

  # Wrapper for 3scale Web Service Management API.
  #
  # == Example
  #
  #   client = ThreeScale::Client.new(:provider_key => "your provider key")
  #
  #   response = client.authorize(:user_key => "yout user's key")
  #
  #   if response.success?
  #     response = client.report(:user_key => "your user's key", :usage => {"hits" => 1})
  #
  #     if response.success?
  #       # all fine.
  #     else
  #       # something's wrong.
  #     end
  #   end
  #
  class Client
    DEFAULT_HOST = 'server.3scale.net'

    def initialize(options)
      if options[:provider_key].nil? || options[:provider_key] =~ /^\s*$/
        raise ArgumentError, 'missing :provider_key'
      end

      @provider_key = options[:provider_key]
      @host = options[:host] || DEFAULT_HOST
    end

    attr_reader :provider_key
    attr_reader :host

    # Report transaction(s).
    #
    # == Parameters
    #
    # The parameters the transactions to report. Each transaction is a hash with
    # these elements:
    #
    #   user_key::  API key of the user to report the transaction for. This parameter is
    #               required.
    #   usage::     Hash of usage values. The keys are metric names and values are
    #               correspoding numeric values. Example: {'hits' => 1, 'transfer' => 1024}. 
    #               This parameter is required.
    #   timestamp:: Timestamp of the transaction. This can be either a object of the
    #               ruby's Time class, or a string in the "YYYY-MM-DD HH:MM:SS" format
    #               (if the time is in the UTC), or a string in 
    #               the "YYYY-MM-DD HH:MM:SS ZZZZZ" format, where the ZZZZZ is the time offset
    #               from the UTC. For example, "US Pacific Time" has offset -0800, "Tokyo"
    #               has offset +0900. This parameter is optional, and if not provided, equals
    #               to the current time.
    #
    # == Return
    #
    # A Response object with method +success?+ that returns true if the report was successful,
    # or false if there was an error. See ThreeScale::Response class for more information.
    #
    # In case of unexpected internal server error, this method raises a ThreeScale::ServerError
    # exception.
    #
    # == Examples
    #
    #   # Report two transactions of two users.
    #   client.report({:user_key => 'foo', :usage => {'hits' => 1}},
    #                 {:user_key => 'bar', :usage => {'hits' => 1}})
    #
    #   # Report one transaction with timestamp.
    #   client.report({:user_key  => 'foo',
    #                  :timestamp => Time.local(2010, 4, 27, 15, 14),
    #                  :usage     => {'hits' => 1})
    #
    def report(*transactions)
      raise ArgumentError, 'no transactions to report' if transactions.empty?

      payload = encode_transactions(transactions)
      payload['provider_key'] = CGI.escape(provider_key)

      uri = URI.parse("http://#{host}/transactions.xml")

      process_response(Net::HTTP.post_form(uri, payload)) do |http_response|
        Response.new(:success => true)
      end
    end

    # Authorize a user.
    #
    # == Parameters
    # 
    # Hash with options:
    #
    #   user_key:: API key of the user to authorize. This is required.
    #
    # == Return
    #
    # An ThreeScale::AuthorizeResponse object. It's +success?+ method returns true if
    # the authorization is successful. In that case, it contains additional information
    # about the status of the use. See the ThreeScale::AuthorizeResponse for more information.
    # In case of error, the +success?+ method returns false and the +errors+ contains list
    # of errors with more details.
    #
    # In case of unexpected internal server error, this method raises a ThreeScale::ServerError
    # exception.
    #
    # == Examples
    #
    #   response = client.authorize(:user_key => 'foo')
    #
    #   if response.success?
    #     # All good. Proceed...
    #   end
    #
    def authorize(options)
      path = "/transactions/authorize.xml" +
        "?provider_key=#{CGI.escape(provider_key)}" +
        "&user_key=#{CGI.escape(options[:user_key].to_s)}"

      uri = URI.parse("http://#{host}#{path}")

      process_response(Net::HTTP.get_response(uri)) do |http_response|
        build_authorize_response(http_response.body)
      end
    end

    private

    def process_response(http_response)
      case http_response
      when Net::HTTPSuccess
        yield(http_response)
      when Net::HTTPClientError
        build_error_response(http_response.body)
      else
        raise ServerError.new(http_response)
      end
    end

    def encode_transactions(transactions)
      result = {}
      
      transactions.each_with_index do |transaction, index|
        append_encoded_value(result, index, [:user_key],  transaction[:user_key])
        append_encoded_value(result, index, [:timestamp], transaction[:timestamp])
        append_encoded_value(result, index, [:client_ip], transaction[:client_ip])

        transaction[:usage].each do |name, value|
          append_encoded_value(result, index, [:usage, name], value)
        end
      end

      result
    end

    def append_encoded_value(result, index, names, value)
      result["transactions[#{index}][#{names.join('][')}]"] = CGI.escape(value.to_s) if value
    end

    def build_authorize_response(body)
      response = AuthorizeResponse.new
      doc = Nokogiri::XML(body)

      response.plan = doc.at_css('plan').content.to_s.strip

      doc.css('usage').each do |node|
        response.add_usage(:metric        => node['metric'].to_s.strip,
                           :period        => node['period'].to_s.strip.to_sym,
                           :period_start  => node.at('period_start').content,
                           :period_end    => node.at('period_end').content,
                           :current_value => node.at('current_value').content.to_i,
                           :max_value     => node.at('max_value').content.to_i)
      end

      response
    end

    def build_error_response(body)
      response = Response.new(:success => false)
      doc = Nokogiri::XML(body)

      doc.css('error').each do |node|
        response.add_error(node['index'].to_i, 
                           
                           # Backwards compatibility: error code is sometimes in
                           # the "id" attribute.
                           node['code'] || node['id'],

                           node.content.to_s.strip)
      end

      response
    end
  end
end
