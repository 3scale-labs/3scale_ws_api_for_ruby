require 'test/unit'
require '3scale/client'

if ENV['TEST_3SCALE_PROVIDER_KEY'] &&
   ENV['TEST_3SCALE_APP_IDS']      &&
   ENV['TEST_3SCALE_APP_KEYS']
  class ThreeScale::RemoteTest < Test::Unit::TestCase
    def setup
      @provider_key = ENV['TEST_3SCALE_PROVIDER_KEY']

      stripper = lambda { |string| string.strip }

      @app_ids  = ENV['TEST_3SCALE_APP_IDS'].split(',').map(&stripper)
      @app_keys = ENV['TEST_3SCALE_APP_KEYS'].split(',').map(&stripper)

      @client = ThreeScale::Client.new(:provider_key => @provider_key)

      if defined?(FakeWeb)
        FakeWeb.clean_registry
        FakeWeb.allow_net_connect = true
      end
    end

    def test_successful_authrep
      @app_keys.each do |app_key|
        response = @client.authrep(:app_id => @app_ids[0], :app_key => app_key,
                                   :usage => {:hits => 2},
                                   :log => {:request => "a/a", :response => "b/b", :code => "c/c"})
        assert response.success?, "AuthRep should succeed for app_id=#{@app_ids[0]} and app_key=#{app_key}, but it failed with: '#{response.error_message}'"
      end
    end


    def test_failed_authrep
      response = @client.authrep(:app_id => 'invalid-id')
      assert !response.success?
      assert_equal 'application_not_found',                          response.error_code
      assert_equal 'application with id="invalid-id" was not found', response.error_message
    end

    def test_successful_authorize
      @app_keys.each do |app_key|
        response = @client.authorize(:app_id => @app_ids[0], :app_key => app_key)
        assert response.success?, "Authorize should succeed for app_id=#{@app_ids[0]} and app_key=#{app_key}, but it failed with: '#{response.error_message}'"
      end
    end

    def test_failed_authorize
      response = @client.authorize(:app_id => 'invalid-id')
      assert !response.success?
      assert_equal 'application_not_found',                          response.error_code
      assert_equal 'application with id="invalid-id" was not found', response.error_message
    end

    def test_successful_oauth_authorize
      @app_keys.each do |app_key|
        response = @client.oauth_authorize(:app_id => @app_ids[0])
        assert response.success?, "Authorize should succeed for app_id=#{@app_ids[0]} and app_key=#{app_key}, but it failed with: '#{response.error_message}'"
        assert_equal app_key, response.app_key
      end
    end

    def test_failed_oauth_authorize
      response = @client.oauth_authorize(:app_id => 'invalid-id')
      assert !response.success?
      assert_equal 'application_not_found',                          response.error_code
      assert_equal 'application with id="invalid-id" was not found', response.error_message
    end

    def test_successful_report
      transactions = @app_ids.map do |app_id|
        {:app_id => app_id, :usage => {'hits' => 1}}
      end

      response = @client.report(*transactions)
      assert response.success?
    end

    def test_failed_report
      transactions = @app_ids.map do |app_id|
        {:app_id => app_id, :usage => {'hits' => 1}}
      end

      client   = ThreeScale::Client.new(:provider_key => 'invalid-key')
      response = client.report(*transactions)
      assert !response.success?
      assert_equal 'provider_key_invalid',                  response.error_code
      assert_equal 'provider key "invalid-key" is invalid', response.error_message
    end
  end

else
  puts "This test executes real requests against 3scale backend server. It needs to know provider key, application ids and application keys to use in the requests. You have to set these environment variables:"
  puts " * TEST_3SCALE_PROVIDER_KEY - a provider key."
  puts " * TEST_3SCALE_APP_IDS      - list of application ids, separated by commas."
  puts " * TEST_3SCALE_APP_KEYS     - list of application keys corresponding to the FIRST id in the TEST_3SCALE_APP_IDS list. Also separated by commas."
end
