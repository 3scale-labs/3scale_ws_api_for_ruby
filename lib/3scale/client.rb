require 'cgi'
require 'uri'
require 'net/http'
require 'nokogiri'
require '3scale/client/http_client'
require '3scale/client/version'

require '3scale/response'
require '3scale/authorize_response'
require '3scale/client/rack_query'

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
  #   client = ThreeScale::Client.new(service_tokens: true)
  #
  #   response = client.authorize(service_token: 'token', service_id: '123', app_id: 'an app id', app_key: 'a secret key')
  #
  #   if response.success?
  #     response = client.report(:app_id => "some app id", :usage => {"hits" => 1})
  #
  #     if response.success?
  #       # all fine.
  #     else
  #       # something's wrong.
  #     end
  #   end
  #
  #   Note: Provider Keys are deprecated in favor of Service Tokens with Service IDs
  #         The next major release of this client will default to use Service Tokens.
  #
  class Client
    DEFAULT_HOST = 'su1.3scale.net'

    DEPRECATION_MSG_PROVIDER_KEY = 'provider keys are deprecated - ' \
      'please switch at your earliest convenience to use service tokens'.freeze
    private_constant :DEPRECATION_MSG_PROVIDER_KEY
    DEPRECATION_MSG_OLD_REPORT = 'warning: def report(*transactions) is '\
      'deprecated. In next versions, the signature of the report method is '\
      'going to be: '\
      'def report(transactions: [], service_id: nil).'.freeze
    private_constant :DEPRECATION_MSG_OLD_REPORT

    EXTENSIONS_HEADER = '3scale-options'.freeze
    private_constant :EXTENSIONS_HEADER

    def initialize(options)
      @provider_key = options[:provider_key]
      @service_tokens = options[:service_tokens]
      @warn_deprecated = options.fetch(:warn_deprecated, true)

      generate_creds_params

      @host = options[:host] ||= DEFAULT_HOST

      @http = ThreeScale::Client::HTTPClient.new(options)
    end

    attr_reader :provider_key, :service_tokens, :host, :http

    # Authorize and report an application.
    # TODO (in the mean time read authorize comments or head over to https://support.3scale.net/reference/activedocs#operation/66 for details
    #
    def authrep(options)
      path = "/transactions/authrep.xml?#{creds_params(options)}"

      options_usage = options.delete :usage
      options_log   = options.delete :log
      extensions    = options.delete :extensions

      options.each_pair do |param, value|
        path += "&#{param}=#{CGI.escape(value.to_s)}"
      end

      options_usage ||= {:hits => 1}
      path += "&#{usage_query_params(options_usage)}"

      if options_log
        log = []
        options_log.each_pair do |key, value|
          escaped_key = CGI.escape "[log][#{key}]"
          log << "#{escaped_key}=#{CGI.escape(value)}"
        end
        path += "&#{log.join('&')}"
      end

      headers = extensions_to_header extensions if extensions
      http_response = @http.get(path, headers: headers)

      case http_response
      when Net::HTTPSuccess,Net::HTTPConflict
        build_authorize_response(http_response.body)
      when Net::HTTPClientError
        build_error_response(http_response.body, AuthorizeResponse)
      else
        raise ServerError.new(http_response)
      end
    end

    # Report transaction(s).
    #
    # == Parameters
    #
    # Hash with up to three fields:
    #
    #   transactions::   Required. Enumerable. Each element is a hash with the fields:
    #         app_id:    ID of the application to report the transaction for. This parameter is
    #                    required.
    #         usage:     Hash of usage values. The keys are metric names and values are
    #                    corresponding numeric values. Example: {'hits' => 1, 'transfer' => 1024}.
    #                    This parameter is required.
    #         timestamp: Timestamp of the transaction. This can be either a object of the
    #                    ruby's Time class, or a string in the "YYYY-MM-DD HH:MM:SS" format
    #                    (if the time is in the UTC), or a string in
    #                    the "YYYY-MM-DD HH:MM:SS ZZZZZ" format, where the ZZZZZ is the time offset
    #                    from the UTC. For example, "US Pacific Time" has offset -0800, "Tokyo"
    #                    has offset +0900. This parameter is optional, and if not provided, equals
    #                    to the current time.
    #   service_id::     ID of the service. It is optional. When not specified, the transactions
    #                    are reported to the default service.
    #   service_token::  Token granting access to the specified service ID.
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
    #    Report two transactions of two applications. Using the default service.
    #    client.report(transactions: [{:app_id => 'foo', :usage => {'hits' => 1}},
    #                                 {:app_id => 'bar', :usage => {'hits' => 1}}])
    #
    #    Report one transaction with timestamp. Using the default service.
    #    client.report(transactions: [{:app_id    => 'foo',
    #                                  :timestamp => Time.local(2010, 4, 27, 15, 14),
    #                                  :usage     => {'hits' => 1}])
    #
    #    Report a transaction specifying the service.
    #    client.report(transactions: [{:app_id => 'foo', :usage => {'hits' => 1}}],
    #                  service_id: 'a_service_id')
    #
    # == Note
    #
    # The signature of this method is a bit complicated because we decided to
    # keep backwards compatibility with a previous version of the method:
    # def report(*transactions)
    def report(*reports, transactions: [], service_id: nil, extensions: nil, service_token: nil, **rest)
      if (!transactions || transactions.empty?) && rest.empty?
        raise ArgumentError, 'no transactions to report'
      end

      transactions = transactions.concat(reports)

      unless rest.empty?
        warn DEPRECATION_MSG_OLD_REPORT if @warn_deprecated
        transactions.concat([rest])
      end

      payload = encode_transactions(transactions)
      if @service_tokens
        raise ArgumentError, "service_token or service_id not specified" unless service_token && service_id
        payload['service_token'] = CGI.escape(service_token)
      else
        payload['provider_key'] = CGI.escape(@provider_key)
      end
      payload['service_id'] = CGI.escape(service_id.to_s) if service_id

      headers = extensions_to_header extensions if extensions
      http_response = @http.post('/transactions.xml', payload, headers: headers)

      case http_response
      when Net::HTTPSuccess
        build_report_response
      when Net::HTTPClientError
        build_error_response(http_response.body)
      else
        raise ServerError.new(http_response)
      end
    end

    # Authorize an application.
    #
    # == Parameters
    #
    # Hash with options:
    #
    #   service_token:: token granting access to the specified service_id.
    #   app_id::        id of the application to authorize. This is required.
    #   app_key::       secret key assigned to the application. Required only if application has
    #                   a key defined.
    #   service_id::    id of the service (required if you have more than one service)
    #   usage::         predicted usage. It is optional. It is a hash where the keys are metrics
    #                   and the values their predicted usage.
    #                   Example: {'hits' => 1, 'my_metric' => 100}
    #   extensions::    Optional. Hash of extension keys and values.
    #
    # == Return
    #
    # An ThreeScale::AuthorizeResponse object. It's +success?+ method returns true if
    # the authorization is successful, false otherwise. It contains additional information
    # about the status of the usage. See the ThreeScale::AuthorizeResponse for more information.
    # In case of error, the +error_code+ returns code of the error and +error_message+
    # human readable error description.
    #
    # In case of unexpected internal server error, this method raises a ThreeScale::ServerError
    # exception.
    #
    # == Examples
    #
    #   response = client.authorize(:app_id => '1234')
    #
    #   if response.success?
    #     # All good. Proceed...
    #   end
    #
    def authorize(options)
      extensions = options.delete :extensions
      creds = creds_params(options)
      path = "/transactions/authorize.xml" + options_to_params(options, ALL_PARAMS) + '&' + creds

      headers = extensions_to_header extensions if extensions
      http_response = @http.get(path, headers: headers)

      case http_response
      when Net::HTTPSuccess,Net::HTTPConflict
        build_authorize_response(http_response.body)
      when Net::HTTPClientError
        build_error_response(http_response.body, AuthorizeResponse)
      else
        raise ServerError.new(http_response)
      end
    end

    # Authorize an application with OAuth.
    #
    # == Parameters
    #
    # Hash with options:
    #
    #   service_token:: token granting access to the specified service_id.
    #   app_id::        id of the application to authorize. This is required.
    #   service_id::    id of the service (required if you have more than one service)
    #   usage::         predicted usage. It is optional. It is a hash where the keys are metrics
    #                   and the values their predicted usage.
    #                   Example: {'hits' => 1, 'my_metric' => 100}
    #
    # == Return
    #
    # A ThreeScale::AuthorizeResponse object. It's +success?+ method returns true if
    # the authorization is successful, false otherwise. It contains additional information
    # about the status of the usage. See the ThreeScale::AuthorizeResponse for more information.
    #
    # It also returns the app_key that corresponds to the given app_id
    #
    # In case of error, the +error_code+ returns code of the error and +error_message+
    # human readable error description.
    #
    # In case of unexpected internal server error, this method raises a ThreeScale::ServerError
    # exception.
    #
    # == Examples
    #
    #   response = client.authorize(:app_id => '1234')
    #
    #   if response.success?
    #     # All good. Proceed...
    #   end
    #
    def oauth_authorize(options)
      extensions = options.delete :extensions
      creds = creds_params(options)
      path = "/transactions/oauth_authorize.xml" + options_to_params(options, OAUTH_PARAMS) + '&' + creds

      headers = extensions_to_header extensions if extensions
      http_response = @http.get(path, headers: headers)

      case http_response
      when Net::HTTPSuccess,Net::HTTPConflict
        build_authorize_response(http_response.body)
      when Net::HTTPClientError
        build_error_response(http_response.body, AuthorizeResponse)
      else
        raise ServerError.new(http_response)
      end
    end

    private

    OAUTH_PARAMS = [:app_id, :app_key, :service_id, :redirect_url, :usage]
    ALL_PARAMS = [:user_key, :app_id, :app_key, :service_id, :redirect_url, :usage]
    REPORT_PARAMS = [:user_key, :app_id, :service_id, :timestamp]

    def options_to_params(options, allowed_keys)
      params = {}

      (allowed_keys - [:usage]).each do |key|
        params[key] = options[key] if options.has_key?(key)
      end

      tuples = params.map do |key, value|
        "#{key}=#{CGI.escape(value.to_s)}"
      end

      res = '?' + tuples.join('&')

      # Usage is a hash. The format is a bit different
      if allowed_keys.include?(:usage) && options.has_key?(:usage)
        res << "&#{usage_query_params(options[:usage])}"
      end

      res
    end

    def encode_transactions(transactions)
      result = {}

      transactions.each_with_index do |transaction, index|
        REPORT_PARAMS.each do |param|
          append_value(result, index, [param],  transaction[param])
        end

        transaction[:usage].each do |name, value|
          append_value(result, index, [:usage, name], value)
        end

        transaction.fetch(:log, {}).each do |name, value|
          append_value(result, index, [:log, name], value)
        end
      end

      result
    end

    def usage_query_params(usage)
      URI.encode_www_form(usage.map { |metric, value| ["[usage][#{metric}]", value ] })
    end

    def append_value(result, index, names, value)
      result["transactions[#{index}][#{names.join('][')}]"] = value if value
    end

    def build_report_response
      response = Response.new
      response.success!
      response
    end

    def build_authorize_response(body)
      response = AuthorizeResponse.new
      doc = Nokogiri::XML(body)

      if doc.at_css('authorized').content == 'true'
        response.success!
      else
        response.error!(doc.at_css('reason').content)
      end

      if doc.at_css('application')
        response.app_key      = doc.at_css('application key').content.to_s.strip
        response.redirect_url = doc.at_css('application redirect_url').content.to_s.strip
      end

      response.plan = doc.at_css('plan').content.to_s.strip

      doc.css('usage_reports usage_report').each do |node|
        period_start = node.at('period_start')
        period_end = node.at('period_end')

        response.add_usage_report(:metric        => node['metric'].to_s.strip,
                                  :period        => node['period'].to_s.strip.to_sym,
                                  :period_start  => period_start ? period_start.content : '',
                                  :period_end    => period_end ? period_end.content : '',
                                  :current_value => node.at('current_value').content.to_i,
                                  :max_value     => node.at('max_value').content.to_i)
      end

      doc.css('hierarchy metric').each do |node|
        metric_name = node['name'].to_s.strip
        children = node['children'].to_s.strip.split(' ')
        response.add_metric_to_hierarchy(metric_name, children)
      end

      response
    end

    def build_error_response(body, klass = Response)
      doc = Nokogiri::XML(body)
      node = doc.at_css('error')

      response = klass.new
      response.error!(node.content.to_s.strip, node['code'].to_s.strip)
      response
    end

    # Encode extensions header
    def extensions_to_header(extensions)
      { EXTENSIONS_HEADER => RackQuery.encode(extensions) }
    end

    # helper to generate the creds_params method
    def generate_creds_params
      define_singleton_method :creds_params,
        if @service_tokens
          lambda do |options|
            token = options.delete(:service_token)
            service_id = options[:service_id]
            raise ArgumentError, "need to specify a service_token and a service_id" unless token && service_id
            'service_token='.freeze + CGI.escape(token)
          end
        elsif @provider_key
          warn DEPRECATION_MSG_PROVIDER_KEY if @warn_deprecated
          lambda do |_|
            "provider_key=#{CGI.escape @provider_key}".freeze
          end
        else
          raise ArgumentError, 'missing credentials - either use "service_tokens: true" or specify a provider_key value'
        end
    end
  end
end
