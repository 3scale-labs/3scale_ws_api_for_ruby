require 'rubygems'
require 'activesupport'
require 'fake_web'
require 'test/unit'

require "#{File.dirname(__FILE__)}/../lib/3scale/interface"

class InterfaceTest < Test::Unit::TestCase
  def setup
    @interface = ThreeScale::Interface.new('http://3scale.net', 'some_key')
  end

  def test_start_should_raise_exception_on_403_forbidden
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['403', 'Forbidden'],
      :string => {:error => 'user key is invalid'}.to_xml(:root => 'errors'))

    assert_raise_with_message ThreeScale::InvalidRequest, 'user key is invalid' do
      @interface.start('invalid_key')
    end
  end

  def test_start_should_raise_exception_on_400_bad_request
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['400', 'Bad Request'],
      :string => {:error => 'metric clicks does not exist'}.to_xml(:root => 'errors'))

    assert_raise_with_message ThreeScale::InvalidRequest,
      'metric clicks does not exist' do
      @interface.start('valid_key')
    end
  end

  def test_start_should_return_transaction_data_on_201_created
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['201', 'Created'],
      :string => {:id => '42', :provider_public_key => 'some_key',
        :contract_name => 'ultimate'}.to_xml(:root => 'transaction',
        :dasherize => false))

    result = @interface.start('valid_key', {'clicks' => 1})

    assert_equal '42', result[:id]
    assert_equal 'some_key', result[:provider_public_key]
    assert_equal 'ultimate', result[:contract_name]
  end

  def test_start_should_raise_exception_on_unexpected_response
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['500', 'Internal Server Error'])

    assert_raise ThreeScale::UnknownError do
      @interface.start('valid_key', 'clicks' => 1)
    end
  end

  def test_confirm_should_raise_exception_on_404_not_found
    FakeWeb.register_uri('http://3scale.net/transactions/42/confirm.xml',
      :status => ['404', 'Not Found'],
      :string => {:error => 'transaction does not exists'}.to_xml(:root => 'errors'))

    assert_raise ThreeScale::TransactionNotFound do
      @interface.confirm(42)
    end
  end
  
  def test_confirm_should_raise_exception_on_403_forbidden
    FakeWeb.register_uri('http://3scale.net/transactions/42/confirm.xml',
      :status => ['403', 'Forbidden'],
      :string => {:error => 'provider key is invalid'}.to_xml(:root => 'errors'))
  
    assert_raise_with_message ThreeScale::InvalidRequest, 'provider key is invalid' do
      @interface.confirm(42)
    end
  end

  def test_confirm_should_raise_exception_on_400_bad_request
    FakeWeb.register_uri('http://3scale.net/transactions/42/confirm.xml',
      :status => ['400', 'Bad Request'],
      :string => {:error => 'metric clicks does not exist'}.to_xml(:root => 'errors'))

    assert_raise_with_message ThreeScale::InvalidRequest,
      'metric clicks does not exist' do
      @interface.confirm(42, 'clicks' => 1)
    end
  end

  def test_confirm_should_return_true_on_200_ok
    FakeWeb.register_uri('http://3scale.net/transactions/42/confirm.xml',
      :status => ['200', 'OK'])

    result = @interface.confirm(42, 'clicks' => 1)
    assert_equal true, result
  end

  def test_cancel_should_raise_exception_on_404_not_found
    FakeWeb.register_uri('http://3scale.net/transactions/42.xml?provider_key=some_key',
      :status => ['404', 'Not Found'])

    assert_raise ThreeScale::TransactionNotFound do
      @interface.cancel(42)
    end
  end

  def test_cancel_should_raise_exception_on_403_forbidden
    FakeWeb.register_uri('http://3scale.net/transactions/42.xml?provider_key=some_key',
      :status => ['403', 'Forbidden'],
      :string => {:error => 'provider key is invalid'}.to_xml(:root => 'errors'))

    assert_raise_with_message ThreeScale::InvalidRequest,
      'provider key is invalid' do
      @interface.cancel(42)
    end
  end

  def test_cancel_should_return_true_on_200_ok
    FakeWeb.register_uri('http://3scale.net/transactions/42.xml?provider_key=some_key',
      :status => ['200', 'OK'])

    result = @interface.cancel(42)
    assert_equal true, result
  end

  def test_cancel_should_raise_exception_on_unexpected_response
    FakeWeb.register_uri('http://3scale.net/transactions/42.xml?provider_key=some_key',
      :status => ['500', 'Internal Server Error'])

    assert_raise ThreeScale::UnknownError do
      @interface.cancel(42)
    end
  end

  private

  def assert_raise_with_message(expected_class, expected_message, &block)
    exception = assert_raise expected_class, &block
    assert_equal expected_message, exception.to_s
  end
end