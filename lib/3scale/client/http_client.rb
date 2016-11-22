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
        @port = options[:port] || (@secure ? 443 : 80)

        backend_class = @persistent ? self.class.persistent_backend : NetHttp or raise PersistenceNotAvailable
        backend_class.prepare

        @http = backend_class.new(@host, @port)
        @http.ssl! if @secure
      end

      class BaseClient
        def self.available?
        end

        def self.prepare
        end

        def initialize(host, port)
          @host = host
          @port = port
        end

        def get_request(path, headers: nil)
          get = Net::HTTP::Get.new(path)
          get.add_field(*USER_CLIENT_HEADER)
          get.add_field('Host', @host)
          add_request_headers(get, headers) if headers
          get
        end

        def post_request(path, payload, headers: nil)
          post = Net::HTTP::Post.new(path)
          post.add_field(*USER_CLIENT_HEADER)
          post.add_field('Host', @host)
          add_request_headers(post, headers) if headers
          post.set_form_data(payload)
          post
        end

        private

        def add_request_headers(req, headers)
          if headers
            headers.each do |hk, hv|
              req.add_field(hk, hv)
            end
          end
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

        def initialize(host, port)
          super
          @http = ::Net::HTTP::Persistent.new
          @protocol = 'http'
        end

        def ssl!
          @protocol = 'https'
        end

        def get(path, headers: nil)
          uri = full_uri(path)
          @http.request(uri, get_request(path, headers: headers))
        end


        def post(path, payload, headers: nil)
          uri = full_uri(path)
          @http.request(uri, post_request(path, payload, headers: headers))
        end

        def full_uri(path)
          URI.join "#{@protocol}://#{@host}:#{@port}", path
        end
      end

      class NetHttp < BaseClient
        extend Forwardable
        def_delegators :@http, :use_ssl?, :active?

        def initialize(host, port)
          super
          @http = Net::HTTP.new(@host, port)
        end

        def ssl!
          @http = Net::HTTP.new(@host, @port)
          @http.use_ssl = true
        end

        def get(path, headers: nil)
          @http.request get_request(path, headers: headers)
        end

        def post(path, payload, headers: nil)
          @http.request post_request(path, payload, headers: headers)
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
