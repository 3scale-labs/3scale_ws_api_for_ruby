require 'test/unit'
require 'three_scale/client'

if ENV['TEST_3SCALE_PROVIDER_KEY'] && ENV['TEST_3SCALE_USER_KEYS']
  class ThreeScale::RemoteTest < Test::Unit::TestCase
    def setup
      @provider_key = ENV['TEST_3SCALE_PROVIDER_KEY']
      @user_keys    = ENV['TEST_3SCALE_USER_KEYS'].split(',').map { |key| key.strip }

      @client = ThreeScale::Client.new(:provider_key => @provider_key)

      if defined?(FakeWeb)
        FakeWeb.clean_registry
        FakeWeb.allow_net_connect = true
      end
    end

    def test_successful_authorize
      response = @client.authorize(:user_key => @user_keys[0])
      assert response.success?
    end

    def test_failed_authorize
      response = @client.authorize(:user_key => 'invalid-user-key')
      assert !response.success?
      assert_equal 'user.invalid_key', response.errors[0].code
    end

    def test_successful_report
      transactions = @user_keys.map do |user_key|
        {:user_key => user_key, :usage => {'hits' => 1}}
      end

      response = @client.report(*transactions)
      assert response.success?
    end
  end

else
  puts "You need to set enviroment variables TEST_3SCALE_PROVIDER_KEY and TEST_3SCALE_USER_KEYS to run this remote test."
end
