require 'minitest/autorun'

require '3scale/client'
require 'mocha/setup'

if ENV['TEST_3SCALE_PROVIDER_KEY'] && ENV['TEST_3SCALE_APP_IDS'] && ENV['TEST_3SCALE_APP_KEYS']
  class ThreeScale::NetHttpPersistenceTest < MiniTest::Test
    WARN_DEPRECATED = ENV['WARN_DEPRECATED'] == '1'

    def setup
      ThreeScale::Client::HTTPClient.persistent_backend = ThreeScale::Client::HTTPClient::NetHttpPersistent

      provider_key = ENV['TEST_3SCALE_PROVIDER_KEY']

      @app_id = ENV['TEST_3SCALE_APP_IDS']
      @app_key = ENV['TEST_3SCALE_APP_KEYS']

      @client = ThreeScale::Client.new(provider_key: provider_key,
				       warn_deprecated: WARN_DEPRECATED,
                                       persistence: true)

      if defined?(FakeWeb)
        FakeWeb.allow_net_connect = true
      end
    end

    def test_authorize
      assert @client.authorize(:app_id => @app_id, :app_key => @app_key).success?
    end

    def test_keepalive_disconnect
      assert @client.authorize(:app_id => @app_id, :app_key => @app_key).success?
      sleep 70
      assert @client.authorize(:app_id => @app_id, :app_key => @app_key).success?
    end
  end


  class ThreeScale::NetHttpKeepaliveTest < ThreeScale::NetHttpPersistenceTest
    def setup
      ThreeScale::Client::HTTPClient.persistent_backend = ThreeScale::Client::HTTPClient::NetHttpKeepAlive
      super
    end
  end
end

