require '3scale/client'
require 'test/unit'

if ENV['TEST_3SCALE_PROVIDER_KEY'] && ENV['TEST_3SCALE_APP_IDS'] && ENV['TEST_3SCALE_APP_KEYS']
  class ThreeScale::PersistenceTest < Test::Unit::TestCase
    def setup
      provider_key = ENV['TEST_3SCALE_PROVIDER_KEY']

      @app_id = ENV['TEST_3SCALE_APP_IDS']
      @app_key = ENV['TEST_3SCALE_APP_KEYS']

      @client = ThreeScale::Client.new(:provider_key => provider_key, :persistence => true)

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
end

