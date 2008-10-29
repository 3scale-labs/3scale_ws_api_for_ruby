require 'rubygems'
require 'activesupport'
require 'fake_web'
require 'mocha'
require 'test/unit'

require "#{File.dirname(__FILE__)}/../lib/3scale/interface"

class InterfaceTest < Test::Unit::TestCase
  def setup
    @interface = ThreeScale::Interface.new('http://3scale.net', 'some_key')
  end

  def test_start_should_raise_exception_on_invalid_user_key
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['403', 'Forbidden'],
      :string => stub_error('user.invalid_key'))

    assert_raise ThreeScale::UserKeyInvalid do
      @interface.start('invalid_key')
    end
  end

  def test_start_should_raise_exception_on_invalid_provider_key
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['400', 'Bad Request'],
      :string => stub_error('provider.invalid_key'))

    assert_raise ThreeScale::ProviderKeyInvalid do
      @interface.start('valid_key')
    end
  end

  def test_start_should_send_usage_data
    Net::HTTP.expects(:post_form).
      with(anything, has_entries('usage[hits]' => '1')).
      returns(stub_response)

    @interface.start('valid_key', 'hits' => 1)
  end

  def test_start_should_return_transaction_data_on_success
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['201', 'Created'],
      :string => {:id => '42', :provider_verification_key => 'some_key',
        :contract_name => 'ultimate'}.to_xml(:root => 'transaction',
        :dasherize => false))

    result = @interface.start('valid_key', {'clicks' => 1})

    assert_equal '42', result[:id]
    assert_equal 'some_key', result[:provider_verification_key]
    assert_equal 'ultimate', result[:contract_name]
  end

  def test_start_should_raise_exception_on_inactive_cinstance
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['403', 'Forbidden'],
      :string => stub_error('user.inactive_contract'))

    assert_raise ThreeScale::ContractNotActive do
      @interface.start('valid_key', 'clicks' => 1)
    end
  end

  def test_start_should_raise_exception_on_exceeded_limits
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['403', 'Forbidden'],
      :string => stub_error('user.exceeded_limits'))

    assert_raise ThreeScale::LimitsExceeded do
      @interface.start('valid_key', 'clicks' => 1)
    end
  end

  def test_start_should_raise_exception_on_unexpected_error
    FakeWeb.register_uri('http://3scale.net/transactions.xml',
      :status => ['500', 'Internal Server Error'])

    assert_raise ThreeScale::UnknownError do
      @interface.start('valid_key', 'clicks' => 1)
    end
  end

  def test_confirm_should_raise_exception_on_invalid_transaction
    FakeWeb.register_uri('http://3scale.net/transactions/42/confirm.xml',
      :status => ['404', 'Not Found'],
      :string => stub_error('provider.invalid_transaction_id'))

    assert_raise ThreeScale::TransactionNotFound do
      @interface.confirm(42)
    end
  end
  
  def test_confirm_should_raise_exception_on_invalid_provider_key
    FakeWeb.register_uri('http://3scale.net/transactions/42/confirm.xml',
      :status => ['403', 'Forbidden'],
      :string => stub_error('provider.invalid_key'))

    assert_raise ThreeScale::ProviderKeyInvalid do
      @interface.confirm(42)
    end
  end

  def test_confirm_should_raise_exception_on_invalid_metric
    FakeWeb.register_uri('http://3scale.net/transactions/42/confirm.xml',
      :status => ['400', 'Bad Request'],
      :string => stub_error('provider.invalid_metric'))

    assert_raise ThreeScale::MetricInvalid do
      @interface.confirm(42, 'clicks' => 1)
    end
  end

  def test_confirm_should_return_true_on_success
    FakeWeb.register_uri('http://3scale.net/transactions/42/confirm.xml',
      :status => ['200', 'OK'])

    result = @interface.confirm(42, 'clicks' => 1)
    assert_equal true, result
  end

  def test_confirm_should_send_usage_data
    Net::HTTP.expects(:post_form).
      with(anything, has_entries('usage[hits]' => '1')).
      returns(stub_response)

    @interface.confirm(42, 'hits' => 1)
  end

  def test_cancel_should_raise_exception_on_invalid_transaction
    FakeWeb.register_uri('http://3scale.net/transactions/42.xml?provider_key=some_key',
      :status => ['404', 'Not Found'],
      :string => stub_error('provider.invalid_transaction_id'))

    assert_raise ThreeScale::TransactionNotFound do
      @interface.cancel(42)
    end
  end

  def test_cancel_should_raise_exception_on_invalid_provider_key
    FakeWeb.register_uri('http://3scale.net/transactions/42.xml?provider_key=some_key',
      :status => ['403', 'Forbidden'],
      :string => stub_error('provider.invalid_key'))

    assert_raise ThreeScale::ProviderKeyInvalid do
      @interface.cancel(42)
    end
  end

  def test_cancel_should_return_true_on_success
    FakeWeb.register_uri('http://3scale.net/transactions/42.xml?provider_key=some_key',
      :status => ['200', 'OK'])

    result = @interface.cancel(42)
    assert_equal true, result
  end

  def test_cancel_should_raise_exception_on_unexpected_error
    FakeWeb.register_uri('http://3scale.net/transactions/42.xml?provider_key=some_key',
      :status => ['500', 'Internal Server Error'])

    assert_raise ThreeScale::UnknownError do
      @interface.cancel(42)
    end
  end

  def test_should_identify_3scale_keys
    assert  @interface.system_key?('3scale-foo')
    assert !@interface.system_key?('foo')
  end

  def test_start_should_strip_3scale_prefix_from_user_key_before_sending
    Net::HTTP.expects(:post_form).with(anything,
      has_entries('user_key' => 'foo')).returns(stub_response)
    
    @interface.start('3scale-foo')
  end

  def test_start_should_leave_user_key_unchanges_if_it_does_not_contain_3scale_prefix
    Net::HTTP.expects(:post_form).with(anything,
      has_entries('user_key' => 'foo')).returns(stub_response)

    @interface.start('foo')
  end

  private

  def stub_error(id)
    "<error id=\"#{id}\">blah blah</error>"
  end

  def stub_response
    response = stub
    response.stubs(:is_a?).with(Net::HTTPSuccess).returns(true)
    response.stubs(:body).returns('<transaction></transaction>')
    response
  end
end