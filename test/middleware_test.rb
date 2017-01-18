require 'minitest/autorun'
require '3scale/middleware'
require 'mocha/setup'

class ThreeScale::MiddlewareTest < MiniTest::Test

  def setup
    @app = ->(_env) {  [ 200, {}, ['']] }
    @provider_key = 'fake-provider-key'
  end

  def client(credentials, response = success)
    mock('client') do
      expects(:authorize).with(credentials).returns(response)
    end
  end

  def success
    mock('response', success?: true)
  end

  def test_user_key_authenticator
    credentials = { user_key: 'user' }
    authenticator = ThreeScale::Middleware::UserKeyAuthenticator.new(client(credentials))
    assert authenticator.provided?('user', nil)
    assert_equal credentials, authenticator.credentials('user')
    assert authenticator.to_proc.call('user', nil)
  end

  def test_app_id_authenticator
    credentials = { app_id: 'app', app_key: 'key' }
    authenticator = ThreeScale::Middleware::AppIdAuthenticator.new(client(credentials))

    assert authenticator.provided?('app', 'key')
    assert_equal credentials, authenticator.credentials('app', 'key')
    assert authenticator.to_proc.call('app', 'key')
  end

  def test_nil_authenticator
    authenticator = ThreeScale::Middleware::NilAuthenticator.new(mock)
    assert authenticator.provided?
    assert_nil authenticator.credentials
    assert authenticator.to_proc.call(nil, nil)
  end
end
