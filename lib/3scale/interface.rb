require 'cgi'
require 'hpricot'
require 'net/http'

module ThreeScale
  class Error < StandardError; end

  # Base class for errors caused by user.
  class UserError < Error; end

  # Error raised when user's contract instance is not active.
  class ContractNotActive < UserError; end

  # Error raised when usage limits specified by user's contract are exceeded.
  class LimitsExceeded < UserError; end

  # Error raised when user_id is invalid.
  class UserKeyInvalid < UserError; end

  
  # Base class for errors caused by provider.
  class ProviderError < Error; end

  # Error raised when some metric names are invalid.
  class MetricInvalid < ProviderError; end

  # Error raised when provider authentication key is invalid.
  class ProviderKeyInvalid < ProviderError; end

  # Error raised when transaction id does not correspond to existing transaction.
  class TransactionNotFound < ProviderError; end


  # Base class for errors caused by 3scale backend system.
  class SystemError < Error; end
  class UnknownError < SystemError; end


  
  # This class provides interface to 3scale backend server.
  #
  # == Basic usage instructions
  #
  # First, create new interface object with 3scale backed hostname and Your
  # private provider key:
  #
  #    interface = ThreeScale::Interface.new("http://3scale.net", "a3b034...")
  #
  # Then for each request to Your service:
  #
  # 1. Start the transaction with user key and (optionaly) predicted resource
  # usage (in this example it is: 1 hit and 42000 kilobytes of storage space),
  #
  #     transaction = interface.start(user_key, 'hits' => 1, 'storage' => 42000)
  #
  # This will return transaction data (if succesful). It is a hash containing
  # these fields:
  #
  #  +:id+: transaction id necessary for confirmation of cancelation of
  #  transaction (see following steps).
  #
  #  +:provider_verification_key+: key You should send back to user so he/she
  #  can verify the authenticity of the response.
  #
  #  +:contract_name+: name of contract the user is signed for. This can be used
  #  to send different response according to contract type, if that is desired.
  #
  # 2. Process the request.
  #
  # 3a. If the processing was succesful:
  # Call +confirm+:
  #
  #     interface.confirm(transaction[:id])
  #
  # Or call it with actual resource usage, if it differs from predicted one:
  #
  #     interface.confirm(transaction[:id], 'hits' => 1, 'storage' => 40500)
  #
  # 3b. If there was some error, call +cancel+:
  #
  #     interface.cancel(transaction_id)
  #
  # 4. Send response back to the user with transaction[:provider_public_key]
  # embeded.
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
    def initialize(host = nil, provider_private_key = nil)
      @host = host
      @provider_private_key = provider_private_key
    end


    # Start a transaction (service request). This can be used also to send
    # prediction of how much resouces will be spend by this request to 3scale
    # backend server.
    #
    # == Arguments
    # * +user_key+:: Key that uniquely identifies an user of the service.
    # * +usage+::    A hash of that contains metric names and to them
    #                associated amounts of resources used. For example, if this
    #                request is going to take 10MB of storage space, then this
    #                parameter could contain {'storage' => 10}. The values may
    #                be only approximate or they can be missing altogether. In
    #                these cases, the real values should be reported using
    #                method +confirm+.
    #
    # == Return values
    # A hash containing there keys:
    # * +id+:: Transaction id. This is required for confirmation/cancellation
    #          of the transaction later.
    # * +provider_verification_key+:: This key should be sent back to the user
    #                                 so he/she can use it to verify the
    #                                 authenticity of the provider.
    # * +contract_name+:: This is name of the contract the user is singed for.
    #                     This information can be used to serve different
    #                     responses according to contract types,
    #                     if that is desirable.
    #
    # == Exceptions
    #
    #
    def start(user_key, usage = {})
      uri = URI.parse("#{host}/transactions.xml")
      params = {
        'user_key' => prepare_key(user_key),
        'provider_key' => provider_private_key
      }
      params.merge!(encode_params(usage, 'values'))
      response = Net::HTTP.post_form(uri, params)

      if response.is_a?(Net::HTTPSuccess)
        element = Hpricot::XML(response.body).at('transaction')
        [:id, :provider_verification_key, :contract_name].inject({}) do |memo, key|
          memo[key] = element.at(key).inner_text if element.at(key)
          memo
        end
      else
        handle_error(response.body)
      end
    end

    # Confirm previously started transaction.
    #
    # TODO: documentation.
    def confirm(transaction_id, usage = {})
      uri = URI.parse("#{host}/transactions/#{CGI.escape(transaction_id.to_s)}/confirm.xml")
      params = {
        'provider_key' => provider_private_key
      }
      params.merge!(encode_params(usage, 'usage'))

      response = Net::HTTP.post_form(uri, params)
      response.is_a?(Net::HTTPSuccess) ? true : handle_error(response.body)
    end

    # Cancel previously started transaction.
    #
    # # TODO: documentation.
    def cancel(transaction_id)
      uri = URI.parse("#{host}/transactions/#{CGI.escape(transaction_id.to_s)}.xml" +
          "?provider_key=#{CGI.escape(provider_private_key)}")

      response = Net::HTTP.start(uri.host, uri.port) do |http|
        http.delete("#{uri.path}?#{uri.query}")
      end

      response.is_a?(Net::HTTPSuccess) ? true : handle_error(response.body)
    end

    KEY_PREFIX = '3scale-'

    # Check if key is for 3scale backend system.
    def system_key?(key)
      # Key should start with prefix
      key.index(KEY_PREFIX) == 0
    end

    private

    # Encode hash into form suitable for sending it as params of HTTP request.
    def encode_params(params, prefix)
      params.inject({}) do |memo, (key, value)|
        memo["#{prefix}[#{CGI.escape(key)}]"] = CGI.escape(value.to_s)
        memo
      end
    end

    def prepare_key(key)
      system_key?(key) ? key[KEY_PREFIX.length..-1] : key
    end

    CODES_TO_EXCEPTIONS = {
      'user.exceeded_limits' => LimitsExceeded,
      'user.invalid_key' => UserKeyInvalid,
      'user.inactive_contract' => ContractNotActive,
      'provider.invalid_key' => ProviderKeyInvalid,
      'provider.invalid_metric' => MetricInvalid,
      'provider.invalid_transaction_id' => TransactionNotFound
    }

    def handle_error(response)
      element = Hpricot::XML(response).at('error')
      raise UnknownError unless element
      raise CODES_TO_EXCEPTIONS[element[:id]] || UnknownError, element.inner_text
    end
  end
end