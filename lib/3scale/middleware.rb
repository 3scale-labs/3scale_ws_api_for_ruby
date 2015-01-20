require '3scale_client'

require 'rack/utils'
require 'rack/auth/basic'

module ThreeScale
  class Middleware < Rack::Auth::Basic
    attr_reader :client, :authenticator

    DEFAULT_OPTIONS = { secure: true, persistent: true }

    def initialize(app, provider_key, mode, options = {})
      options = DEFAULT_OPTIONS.merge(options).merge(provider_key: provider_key)
      @client = ThreeScale::Client.new(options)

      super(app, '3scale Authentication', &authenticator_for(mode))
    end

    private

    def authenticator_for(mode)
      klass = case mode
                when :user_key then UserKeyAuthenticator
                when :app_id then AppIdAuthenticator
                when nil then NilAuthenticator
                else raise "Unknown auth mode #{mode}"
              end

      klass.new(@client)
    end

    class BaseAuthenticator
      attr_accessor :client

      def initialize(client)
        @client = client
      end

      def provided?(username, password)
        username && !username.empty? && password && !password.empty?
      end

      def credentials(*)
        nil
      end

      def to_proc
        lambda { |username, password|
          return false unless provided?(username, password)

          auth = credentials(username, password)
          # Do not do authrep for now, as rate limitin requires more work:
          # we would need to send headers with remaining limits & proper codes
          response = @client.authorize(auth)
          response.success?
        }
      end
    end

    private_constant :BaseAuthenticator

    class UserKeyAuthenticator < BaseAuthenticator
      def provided?(username, *)
        username && !username.empty?
      end

      def credentials(username, *)
        { user_key: username }
      end
    end

    class AppIdAuthenticator < BaseAuthenticator
      def credentials(username, password)
        { app_id: username, app_key: password }
      end
    end

    class NilAuthenticator < BaseAuthenticator
      def provided?(*)
        true
      end

      def to_proc
        proc { true }
      end
    end
  end
end
