require 'rubygems'
require 'activesupport'
require 'fake_web'
require 'mocha'
require 'test/unit'

require "#{File.dirname(__FILE__)}/../lib/interface"

class InterfaceTest < Test::Unit::TestCase
  def setup
    @interface = ThreeScale::Interface.new('http://3scale.net', 'some_key')
  end

  def test_start_with_invalid_user_key_should_raise_an_exception
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['403', 'Forbidden'])

    assert_raise ThreeScale::InvalidRequest do
      @interface.start('invalid')
    end
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