require 'cgi'
require 'hpricot'
require 'net/http'

module ThreeScale # :nodoc:
  class Error < StandardError; end

  # Base class for exceptions caused by user.
  class UserError < Error; end

  # Exception raised when contract between user and provider is not active.
  # Contract can be inactive when it is pending (requires confirmation from
  # provider), suspended or canceled.
  class ContractNotActive < UserError; end

  # Exception raised when usage limits configured for contract are already
  # exceeded.
  class LimitsExceeded < UserError; end

  # Exception raised when +user_key+ is not valid. This can mean that contract
  # between provider and user does not exists, or the passed +user_key+ does
  # not correspond to the key associated with this contract.
  class UserKeyInvalid < UserError; end

  
  # Base class for exceptions caused by provider.
  class ProviderError < Error; end

  # Exception raised when some metric name in provider +usage+ hash does not
  # correspond to metric configured for the service.
  class MetricInvalid < ProviderError; end

  # Exception raised when provider authentication key is not valid. The provider
  # needs to make sure that the key used is the same as the one that was
  # generated for him/her when he/she published a service on 3scale.
  class ProviderKeyInvalid < ProviderError; end

  # Exception raised when transaction corresponding to given +transaction_id+
  # does not exists. Methods +confirm+ and +cancel+ need valid transaction id
  # that is obtained by preceding call to +start+.
  class TransactionNotFound < ProviderError; end


  # Base class for exceptions caused by 3scale backend system.
  class SystemError < Error; end

  # Other error.
  class UnknownError < SystemError; end


  
  # This class provides interface to 3scale monitoring system.
  #
  # Objects of this class are stateless and can be shared through multiple
  # transactions and by multiple clients.
  class Interface

    # Hostname of 3scale server.
    attr_accessor :host

    # Key that uniquely identifies the provider. This key is known only to the
    # provider and to 3scale.
    attr_accessor :provider_authentication_key

    # Create a 3scale interface object.
    #
    # == Arguments
    # +host+:: Hostname of 3scale backend server.
    # +provider_authentication_key+:: Unique key that identifies this provider.
    def initialize(host = nil, provider_authentication_key = nil)
      @host = host
      @provider_authentication_key = provider_authentication_key
    end


    # Starts a transaction. This can be used also to report estimated resource
    # usage of the request.
    #
    # == Arguments
    # +user_key+:: Key that uniquely identifies an user of the service.
    # +usage+::
    #   A hash of metric names/values pairs that contains predicted resource
    #   usage of this request.
    #   
    #   For example, if this request is going to take 10MB of storage space,
    #   then this parameter could contain {'storage' => 10}. The values may be
    #   only approximate or they can be missing altogether. In these cases, the
    #   real values must be reported using method +confirm+.
    #
    # == Return values
    # A hash containing there keys:
    # <tt>:id</tt>::
    #   Transaction id. This is required for confirmation/cancellation of the
    #   transaction later.
    # <tt>:provider_verification_key</tt>::
    #   This key should be sent back to the user so he/she can use it to verify
    #   the authenticity of the provider.
    # <tt>:contract_name</tt>::
    #   This is name of the contract the user is singed for. This information
    #   can be used to serve different responses according to contract types,
    #   if that is desirable.
    #
    # == Exceptions
    #
    # ThreeScale::UserKeyInvalid:: +user_key+ is not valid
    # ThreeScale::ProviderKeyInvalid:: +provider_authentication_key+ is not valid
    # ThreeScale::MetricInvalid:: +usage+ contains invalid metrics
    # ThreeScale::ContractNotActive:: contract is not active
    # ThreeScale::LimitsExceeded:: usage limits are exceeded
    # ThreeScale::UnknownError:: some other unexpected error
    #
    def start(user_key, usage = {})
      uri = URI.parse("#{host}/transactions.xml")
      params = {
        'user_key' => user_key,
        'provider_key' => provider_authentication_key
      }
      params.merge!(encode_params(usage, 'usage'))
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

    # Confirms a transaction.
    #
    # == Arguments
    #
    # +transaction_id+::
    #   A transaction id obtained from previous call to +start+.
    # +usage+::
    #   A hash of metric names/values pairs containing actual resource usage
    #   of this request. This parameter is required only if no usage information
    #   was passed to method +start+ for this transaction, or if it was only
    #   approximate.
    #
    # == Return values
    #
    # If there were no exceptions raised, returns true.
    #
    # == Exceptions
    #
    # ThreeScale::TransactionNotFound:: transactions does not exits
    # ThreeScale::ProviderKeyInvalid:: +provider_authentication_key+ is not valid
    # ThreeScale::MetricInvalid:: +usage+ contains invalid metrics
    # ThreeScale::UnknownError:: some other unexpected error
    #
    def confirm(transaction_id, usage = {})
      uri = URI.parse("#{host}/transactions/#{CGI.escape(transaction_id.to_s)}/confirm.xml")
      params = {
        'provider_key' => provider_authentication_key
      }
      params.merge!(encode_params(usage, 'usage'))

      response = Net::HTTP.post_form(uri, params)
      response.is_a?(Net::HTTPSuccess) ? true : handle_error(response.body)
    end

    # Cancels a transaction.
    #
    # Use this if request processing failed. Any estimated resource usage
    # reported by preceding call to +start+ will be deleted. You don't have to
    # call this if call to +start+ itself failed.
    #
    # == Arguments
    #
    # +transaction_id+::
    #   A transaction id obtained from previous call to +start+.
    #
    # == Return values
    #
    # If there were no exceptions raised, returns true.
    #
    # == Exceptions
    #
    # ThreeScale::TransactionNotFound:: transactions does not exits
    # ThreeScale::ProviderKeyInvalid:: +provider_authentication_key+ is not valid
    # ThreeScale::UnknownError:: some other unexpected error
    #
    def cancel(transaction_id)
      uri = URI.parse("#{host}/transactions/#{CGI.escape(transaction_id.to_s)}.xml" +
          "?provider_key=#{CGI.escape(provider_authentication_key)}")

      response = Net::HTTP.start(uri.host, uri.port) do |http|
        http.delete("#{uri.path}?#{uri.query}")
      end

      response.is_a?(Net::HTTPSuccess) ? true : handle_error(response.body)
    end

    KEY_PREFIX = '3scale-' # :nodoc:

    # This can be used to quickly distinguish between keys used with 3scale
    # system and any other keys the provider might use. Returns true if the key
    # is for 3scale system.
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

    CODES_TO_EXCEPTIONS = {
      'user.exceeded_limits' => LimitsExceeded,
      'user.invalid_key' => UserKeyInvalid,
      'user.inactive_contract' => ContractNotActive,
      'provider.invalid_key' => ProviderKeyInvalid,
      'provider.invalid_metric' => MetricInvalid,
      'provider.invalid_transaction_id' => TransactionNotFound} # :nodoc:

    def handle_error(response)
      element = Hpricot::XML(response).at('error')
      raise UnknownError unless element
      raise CODES_TO_EXCEPTIONS[element[:id]] || UnknownError, element.inner_text
    end
  end
end
