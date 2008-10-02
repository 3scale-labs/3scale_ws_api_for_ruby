require 'rubygems'
require 'activesupport'
require 'fake_web'
require 'test/unit'

require "#{File.dirname(__FILE__)}/../lib/interface"

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

  private

  def assert_raise_with_message(expected_class, expected_message, &block)
    exception = assert_raise expected_class, &block
    assert_equal expected_message, exception.to_s
  end

  #  def setup
  #    @host = 'http://backend.3scale.net'
  #    @interface = ThreeScale::Interface.new(@host)
  #  end
  #
  #  def test_validate_should_return_provider_public_key_if_successful
  #    mock_get(
  #      '/transactions/validate?user_key=foo&provider_key=bar',
  #      Net::HTTPOK
  #    )
  #
  #    assert_not_nil @interface.validate('foo', 'bar')
  #  end
  #
  #  def test_validate_should_raise_exception_on_missing_arguments
  #    assert_raise ArgumentError do
  #      @interface.validate(nil, '')
  #    end
  #  end
  #
  #  def test_validate_should_raise_exception_on_nonexisting_cinstance
  #    mock_get(
  #      '/transactions/validate?user_key=foo&provider_key=bar',
  #      Net::HTTPNotFound
  #    )
  #
  #    assert_raise ThreeScale::ContractInstanceNotFound do
  #      @interface.validate('foo', 'bar')
  #    end
  #  end
  #
  #  def test_validate_should_raise_exception_on_failed_authorization
  #    mock_get(
  #      '/transactions/validate?user_key=foo&provider_key=bar',
  #      Net::HTTPForbidden
  #    )
  #
  #    assert_raise ThreeScale::AuthorizationFailed do
  #      @interface.validate('foo', 'bar')
  #    end
  #  end
  #
  #  def test_validate_should_raise_exception_on_exceeded_limit
  #    mock_get(
  #      '/transactions/validate?user_key=foo&provider_key=bar',
  #      Net::HTTPPreconditionFailed
  #    )
  #
  #    assert_raise ThreeScale::LimitExceeded do
  #      @interface.validate('foo', 'bar')
  #    end
  #  end
  #
  #  def test_successful_report
  #    mock_post(
  #      '/transactions',
  #      {'user_key' => 'foo', 'provider_key' => 'bar',
  #       'metrics[storage]' => '10', 'metrics[cpu]' => '2'},
  #      Net::HTTPOK
  #    )
  #
  #    assert @interface.report('foo', 'bar', 'storage' => 10, 'cpu' => 2)
  #  end
  #
  #  def test_report_should_raise_exception_on_missing_arguments
  #    assert_raise ArgumentError do
  #      @interface.report(@host, nil, nil, nil)
  #    end
  #  end
  #
  #  def test_report_should_raise_exception_on_failed_authorization
  #    mock_post(
  #      '/transactions',
  #      {'user_key' => 'foo', 'provider_key' => 'bar',
  #       'metrics[storage]' => '10', 'metrics[cpu]' => '2'},
  #      Net::HTTPForbidden
  #    )
  #
  #    assert_raise ThreeScale::AuthorizationFailed do
  #      @interface.report('foo', 'bar', 'storage' => 10, 'cpu' => 2)
  #    end
  #  end
  #
  #  private
  #
  #  def mock_get(path, response_class)
  #    uri = URI.parse("#{@host}#{path}")
  #    Net::HTTP.expects(:get_response).with(equals(uri)).returns(
  #      stub(:class => response_class, :body => '3243657635324536457')
  #    )
  #  end
  #
  #  def mock_post(path, params, response_class)
  #    uri = URI.parse("#{@host}#{path}")
  #    Net::HTTP.expects(:post_form).with(equals(uri), params).returns(
  #      stub(:class => response_class, :body => 'OK')
  #    )
  #  end
end