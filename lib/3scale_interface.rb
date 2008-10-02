require 'net/http'
require 'cgi'

# TODO: write very good documentation for this.

module ThreeScale
  class Error < StandardError; end

  # Contract instance was not found.
  class ContractInstanceNotFound < Error; end

  # Authorization failed: user_key or provider_key or both are invalid.
  class AuthorizationFailed < Error; end

  # Limit specified by contract was exceeded.
  class LimitExceeded < Error; end

  # Some unpredicted error occured.
  class UnknownError < Error; end

  # This class provides interface to 3scale backend server.
  class Interface
    STATUSES_TO_ERRORS = Hash.new(UnknownError).merge(
      Net::HTTPNotFound => ContractInstanceNotFound,
      Net::HTTPForbidden => AuthorizationFailed,
      Net::HTTPPreconditionFailed => LimitExceeded
    )

    # Hostname of 3scale server.
    attr_accessor :host
    
    def initialize(host)
      @host = host
    end

    # This method checks if transaction the user requested should be allowed.
    # That means if it is authorized and various constrains specified by the
    # contract are still met.
    #
    # == Arguments
    #
    # * user_key - unique key indentifiing a user of the service. This should
    #              be part of user's request.
    # * provider_key - unique key identifiing a provider
    def validate(user_key, provider_key)
      check_arguments(user_key, provider_key)

      params = {
        'user_key' => user_key,
        'provider_key' => provider_key
      }
  
      uri = "#{@host}/transactions/validate#{self.class.to_query_string(params)}"
      handle_response(Net::HTTP.get_response(URI.parse(uri)))
    end

    # Report 3scale about executed transaction.
    #
    def report(user_key, provider_key, metrics)
      check_arguments(user_key, provider_key)
      raise ArgumentError, 'metrics missing' unless metrics
      
      params = {'user_key' => user_key, 'provider_key' => provider_key}
      params.merge!(self.class.flatten_hash(metrics, 'metrics'))
    
      uri = "#{@host}/transactions"
      handle_response(Net::HTTP.post_form(URI.parse(uri), params))
    end

    private

    def check_arguments(user_key, provider_key)
      raise ArgumentError, 'user_key missing' if user_key.to_s.strip.empty?
      raise ArgumentError, 'provider_key missing' if provider_key.to_s.strip.empty?
    end
    
    # Handle HTTP response
    def handle_response(response)
      raise STATUSES_TO_ERRORS[response.class], response.body unless response.class == Net::HTTPOK
      response.body
    end
  
    # Convert hash to query string.
    def self.to_query_string(params)
      '?' + params.map do |(key, value)|
        "#{CGI.escape(key)}=#{CGI.escape(value)}"
      end.join('&')
    end

    def self.flatten_hash(params, prefix)
      params.inject({}) do |memo, (key, value)|
        memo["#{prefix}[#{CGI.escape(key)}]"] = CGI.escape(value.to_s)
        memo
      end
    end
  end
end