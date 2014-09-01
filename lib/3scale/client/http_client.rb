require 'forwardable'
require '3scale/client/version'

module ThreeScale
  class Client
    class HTTPClient
      extend Forwardable
      def_delegators :@http, :get, :post, :use_ssl?, :active?
      USER_CLIENT_HEADER = ['X-3scale-User-Agent', "plugin-ruby-v#{VERSION}"]

      def initialize(options)

        @secure = !!options[:secure]
        @host = options.fetch(:host)
        @persistent = options[:persistent]

        backend_class = @persistent ? Persistent : NetHttp

        @http = backend_class.new(@host)
        @http.ssl! if @secure
      end

      class BaseClient
        def initialize(host)
          @host = host
        end

        def get(path)
          get = Net::HTTP::Get.new(path)
          get.add_field(*USER_CLIENT_HEADER)
          get.add_field('Host', @host)
          get
        end

        def post(path, payload)
          post = Net::HTTP::Post.new(path)
          post.add_field(*USER_CLIENT_HEADER)
          post.add_field('Host', @host)
          post.set_form_data(payload)
          post
        end
      end

      class Persistent < BaseClient
        def initialize(host)
          super
          require 'net/http/persistent'
          @http = ::Net::HTTP::Persistent.new
          @protocol = 'http'
        end

        def ssl!
          @protocol = 'https'
        end

        def get(path)
          uri = full_uri(path)
          @http.request(uri, super)
        end


        def post(path, payload)
          uri = full_uri(path)
          @http.request(uri, super)
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
          @http.request(super)
        end

        def post(path, payload)
          @http.request(super)
        end
      end
    end
  end
end
