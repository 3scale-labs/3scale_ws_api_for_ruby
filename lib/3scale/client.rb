require 'cgi'
require 'uri'
require 'net/http'
require 'nokogiri'

require '3scale/response'
require '3scale/authorize_response'

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
  #   response = client.authorize(:app_id => "an app id", :app_key => "a secret key")
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
  class Client
    DEFAULT_HOST = 'su1.3scale.net'

    def initialize(options)
      if options[:provider_key].nil? || options[:provider_key] =~ /^\s*$/
        raise ArgumentError, 'missing :provider_key'
      end

      @provider_key = options[:provider_key]
      @host = options[:host] || DEFAULT_HOST
    end

    attr_reader :provider_key
    attr_reader :host

    # Authorize and report an application.
    # TODO (in the mean time read authorize comments or head over to https://support.3scale.net/reference/activedocs#operation/66 for details
    #
    def authrep(options)
      path = "/transactions/authrep.xml?provider_key=#{CGI.escape(provider_key)}"

      options_usage = options.delete :usage
      options_log   = options.delete :log

      options.each_pair do |param, value|
        path += "&#{param}=#{CGI.escape(value.to_s)}"
      end

      options_usage ||= {:hits => 1}
      usage = []
      options_usage.each_pair do |metric, value|
        escaped_metric = CGI.escape "[usage][#{metric}]"
        usage << "#{escaped_metric}=#{CGI.escape(value.to_s)}"
      end
      path += "&#{usage.join('&')}"

      if options_log
        log = []
        options_log.each_pair do |key, value|
          escaped_key = CGI.escape "[log][#{key}]"
          log << "#{escaped_key}=#{CGI.escape(value)}"
        end
        path += "&#{log.join('&')}"
      end

      uri = URI.parse("http://#{host}#{path}")
      http_response = Net::HTTP.get_response(uri)

      case http_response
      when Net::HTTPSuccess,Net::HTTPConflict
        build_authorize_response(http_response.body)
      when Net::HTTPClientError
        build_error_response(http_response.body)
      else
        raise ServerError.new(http_response)
      end
    end

    # Report transaction(s).
    #
    # == Parameters
    #
    # The parameters the transactions to report. Each transaction is a hash with
    # these elements:
    #
    #   app_id::    ID of the application to report the transaction for. This parameter is
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
    #   # Report two transactions of two applications.
    #   client.report({:app_id => 'foo', :usage => {'hits' => 1}},
    #                 {:app_id => 'bar', :usage => {'hits' => 1}})
    #
    #   # Report one transaction with timestamp.
    #   client.report({:app_id    => 'foo',
    #                  :timestamp => Time.local(2010, 4, 27, 15, 14),
    #                  :usage     => {'hits' => 1})
    #
    def report(*transactions)
      raise ArgumentError, 'no transactions to report' if transactions.empty?

      payload = encode_transactions(transactions)
      payload['provider_key'] = CGI.escape(provider_key)

      uri = URI.parse("http://#{host}/transactions.xml")
      http_response = Net::HTTP.post_form(uri, payload)

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
    #   app_id::  id of the application to authorize. This is required.
    #   app_key:: secret key assigned to the application. Required only if application has
    #             a key defined.
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
      path = "/transactions/authorize.xml" +
        "?provider_key=#{CGI.escape(provider_key)}" +
        "&app_id=#{CGI.escape(options[:app_id].to_s)}"
      path += "&app_key=#{CGI.escape(options[:app_key])}" if options[:app_key]

      uri = URI.parse("http://#{host}#{path}")
      http_response = Net::HTTP.get_response(uri)

      case http_response
      when Net::HTTPSuccess,Net::HTTPConflict
        build_authorize_response(http_response.body)
      when Net::HTTPClientError
        build_error_response(http_response.body)
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
    #   app_id::  id of the application to authorize. This is required.
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
      path = "/transactions/oauth_authorize.xml" +
        "?provider_key=#{CGI.escape(provider_key)}" +
        "&app_id=#{CGI.escape(options[:app_id].to_s)}"
      path += "&app_key=#{CGI.escape(options[:app_key])}" if options[:app_key]
      path += "&redirect_url=#{CGI.escape(options[:redirect_url])}" if options[:redirect_url]

      uri = URI.parse("http://#{host}#{path}")
      http_response = Net::HTTP.get_response(uri)

      case http_response
      when Net::HTTPSuccess,Net::HTTPConflict
        build_authorize_response(http_response.body)
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
        append_encoded_value(result, index, [:app_id],    transaction[:app_id])
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
        response.add_usage_report(:metric        => node['metric'].to_s.strip,
                                  :period        => node['period'].to_s.strip.to_sym,
                                  :period_start  => node.at('period_start').content,
                                  :period_end    => node.at('period_end').content,
                                  :current_value => node.at('current_value').content.to_i,
                                  :max_value     => node.at('max_value').content.to_i)
      end

      response
    end

    def build_error_response(body)
      doc = Nokogiri::XML(body)
      node = doc.at_css('error')

      response = Response.new
      response.error!(node.content.to_s.strip, node['code'].to_s.strip)
      response
    end
  end
end
