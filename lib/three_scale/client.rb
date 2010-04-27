require 'cgi'
require 'nokogiri'

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
  #   response = client.report(:user_key => "your user's key", :usage => {"hits" => 1})
  #
  #   if response.success?
  #     # all fine.
  #   else
  #     # something's wrong.
  #   end
  #
  class Client
    class Response
      def initialize(options)
        @success = options[:success]
        @errors  = options[:errors] || []
      end

      def success?
        @success
      end
      
      attr_reader :errors
    
      Error = Struct.new(:code, :message)
    end

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
      payload['provider_key'] = provider_key

      uri = URI.parse("http://#{host}/transactions.xml")
      http_response = Net::HTTP.post_form(uri, payload)

      case http_response
      when Net::HTTPSuccess
        Response.new(:success => true)
      when Net::HTTPClientError
        build_error_response(http_response.body)
      else
        raise ServerError.new(http_response)
      end
    end

    private

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

    def build_error_response(body)
      errors = []

      doc = Nokogiri::XML(body)
      doc.search('error').each do |node|
        errors[node['index'].to_i] = Response::Error.new(node['code'], node.content.to_s.strip)
      end

      Response.new(:success => false, :errors => errors)
    end
  end
end
