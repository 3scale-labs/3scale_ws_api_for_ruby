require 'forwardable'
require '3scale/client/version'

module ThreeScale
  class Client
    class HTTPClient
      extend Forwardable
      def_delegators :@http, :get, :post, :use_ssl?, :active?
      USER_CLIENT_HEADER = ['X-3scale-User-Agent', "plugin-ruby-v#{VERSION}"]

      class PersistenceNotAvailable < LoadError
        def initialize(*)
          super 'persistence is available only on Ruby 2.0 or with net-http-persistent gem'.freeze
        end
      end

      def initialize(options)
        @secure = !!options[:secure]
        @host = options.fetch(:host)
        @persistent = options[:persistent]

        backend_class = @persistent ? self.class.persistent_backend : NetHttp or raise PersistenceNotAvailable
        backend_class.prepare

        @http = backend_class.new(@host)
        @http.ssl! if @secure
      end

      class BaseClient
        def self.available?
        end

        def self.prepare
        end

        def initialize(host)
          @host = host
        end

        def get_request(path)
          get = Net::HTTP::Get.new(path)
          get.add_field(*USER_CLIENT_HEADER)
          get.add_field('Host', @host)
          get
        end

        def post_request(path, payload)
          post = Net::HTTP::Post.new(path)
          post.add_field(*USER_CLIENT_HEADER)
          post.add_field('Host', @host)
          post.set_form_data(payload)
          post
        end
      end

      class NetHttpPersistent < BaseClient
        def self.available?
          prepare
          true
        rescue LoadError
          false
        end

        def self.prepare
          require 'net/http/persistent'
        end

        def initialize(host)
          super
          @http = ::Net::HTTP::Persistent.new
          @protocol = 'http'
        end

        def ssl!
          @protocol = 'https'
        end

        def get(path)
          uri = full_uri(path)
          @http.request(uri, get_request(path))
        end


        def post(path, payload)
          uri = full_uri(path)
          @http.request(uri, post_request(path, payload))
        end

        def full_uri(path)
          URI.join "#{@protocol}://#{@host}", path
        end
      end

      class NetHttp < BaseClient
        extend Forwardable
        def_delegators :@http, :use_ssl?, :active?

        def initialize(host)
          super
          @http = Net::HTTP.new(@host, 80)
        end

        def ssl!
          @http = Net::HTTP.new(@host, 443)
          @http.use_ssl = true
        end

        def get(path)
          @http.request get_request(path)
        end

        def post(path, payload)
          @http.request post_request(path, payload)
        end
      end

      class NetHttpKeepAlive < NetHttp
        HTTP_CONNECTION = 'connection'.freeze
        HTTP_KEEPALIVE = 'keep-alive'.freeze

        MARK_KEEPALIVE = ->(req) { req[HTTP_CONNECTION] ||= HTTP_KEEPALIVE }

        private_constant :MARK_KEEPALIVE
        private_constant :HTTP_CONNECTION
        private_constant :HTTP_KEEPALIVE

        def self.available?
          Net::HTTP.instance_method(:keep_alive_timeout)
        rescue NameError
          false
        end

        def initialize(*)
          super
          @http.start
        end

        def ssl!
          super
          @http.start
        end

        def get_request(*)
          super.tap(&MARK_KEEPALIVE)
        end

        def post_request(*)
          super.tap(&MARK_KEEPALIVE)
        end
      end

      class << self
        attr_accessor :persistent_backend
      end

      self.persistent_backend = [NetHttpKeepAlive, NetHttpPersistent].find(&:available?)
    end
  end
end
