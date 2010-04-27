require 'test/unit'
require 'fakeweb'
require 'mocha'

require 'three_scale/client'

class ThreeScale::ClientTest < Test::Unit::TestCase
  def setup
    FakeWeb.clean_registry
    FakeWeb.allow_net_connect = false

    @client = ThreeScale::Client.new(:provider_key => '1234abcd')
  end

  def test_raises_exception_if_provider_key_is_missing
    assert_raise ArgumentError do
      ThreeScale::Client.new({})
    end
  end

  def test_default_host
    client = ThreeScale::Client.new(:provider_key => '1234abcd')

    assert_equal 'server.3scale.net', client.host
  end

  def test_successful_authorize
    body = '<status>
              <plan>Ultimate</plan>
              
              <usage metric="hits" period="day">
                <period_start>2010-04-26 00:00:00</period_start>
                <period_end>2010-04-26 23:59:59</period_end>
                <current_value>10023</current_value>
                <max_value>50000</max_value>
              </usage>

              <usage metric="hits" period="month">
                <period_start>2010-04-01 00:00:00</period_start>
                <period_end>2010-04-30 23:59:59</period_end>
                <current_value>999872</current_value>
                <max_value>150000</max_value>
              </usage>
            </status>'

    FakeWeb.register_uri(:get, 'http://server.3scale.net/transactions/authorize.xml?provider_key=1234abcd&user_key=foo', :status => ['200', 'OK'], :body => body)

    response = @client.authorize(:user_key => 'foo')

    assert response.success?
    assert_equal 'Ultimate', response.plan
    assert_equal 2, response.usages.size
    
    assert_equal :day, response.usages[0].period
    assert_equal Time.local(2010, 4, 26), response.usages[0].period_start
    assert_equal Time.local(2010, 4, 26, 23, 59, 59), response.usages[0].period_end
    assert_equal 10023, response.usages[0].current_value
    assert_equal 50000, response.usages[0].max_value

    assert_equal :month, response.usages[1].period
    assert_equal Time.local(2010, 4, 1), response.usages[1].period_start
    assert_equal Time.local(2010, 4, 30, 23, 59, 59), response.usages[1].period_end
    assert_equal 999872, response.usages[1].current_value
    assert_equal 150000, response.usages[1].max_value
  end

  def test_failed_authorize
    error_body = '<error code="user.exceeded_limits">
                    usage limits are exceeded
                  </error>'
    
    FakeWeb.register_uri(:get, 'http://server.3scale.net/transactions/authorize.xml?provider_key=1234abcd&user_key=foo', :status => ['403', 'Forbidden'], :body => error_body)
    
    response = @client.authorize(:user_key => 'foo')

    assert !response.success?
    assert_equal 1, response.errors.size
    assert_equal 'user.exceeded_limits',      response.errors[0].code
    assert_equal 'usage limits are exceeded', response.errors[0].message
  end
  
  def test_authorize_with_server_error
    FakeWeb.register_uri(:get, 'http://server.3scale.net/transactions/authorize.xml?provider_key=1234abcd&user_key=foo', :status => ['500', 'Internal Server Error'], :body => 'OMG! WTF!')

    assert_raise ThreeScale::ServerError do
      @client.authorize(:user_key => 'foo')
    end
  end

  def test_report_raises_an_exception_if_no_transactions_given
    assert_raise ArgumentError do
      @client.report
    end
  end

  def test_successful_report
    FakeWeb.register_uri(:post, 'http://server.3scale.net/transactions.xml',
                         :status => ['200', 'OK'])

    response = @client.report({:user_key  => 'foo',
                               :timestamp => Time.local(2010, 4, 27, 15, 00),
                               :usage     => {'hits' => 1}})

    assert response.success?
  end

  def test_report_encodes_transactions
    http_response = stub
    Net::HTTPSuccess.stubs(:===).with(http_response).returns(true)

    Net::HTTP.expects(:post_form).
      with(anything,
           'provider_key'                 => '1234abcd',
           'transactions[0][user_key]'    => 'foo',
           'transactions[0][usage][hits]' => '1',
           'transactions[0][timestamp]'   => CGI.escape('2010-04-27 15:42:17 0200'),
           'transactions[1][user_key]'    => 'bar',
           'transactions[1][usage][hits]' => '1',
           'transactions[1][timestamp]'   => CGI.escape('2010-04-27 15:55:12 0200')).
      returns(http_response)

    @client.report({:user_key  => 'foo',
                    :usage     => {'hits' => 1},
                    :timestamp => '2010-04-27 15:42:17 0200'},

                   {:user_key  => 'bar',
                    :usage     => {'hits' => 1},
                    :timestamp => '2010-04-27 15:55:12 0200'})
  end

  def test_failed_report
    error_body = '<errors>
                    <error code="user.invalid_key" index="0">
                      user key is invalid
                    </error>
                    <error code="provider.invalid_metric" index="1">
                      metric does not exist
                    </error>
                  </errors>'

    FakeWeb.register_uri(:post, 'http://server.3scale.net/transactions.xml',
                         :status => ['403', 'Forbidden'],
                         :body   => error_body)
   
    response = @client.report({:user_key => 'bogus', :usage => {'hits' => 1}},
                              {:user_key => 'bar',   :usage => {'monkeys' => 1000000000}})

    assert !response.success?
    assert_equal 2, response.errors.size

    assert_equal 'user.invalid_key',        response.errors[0].code
    assert_equal 'user key is invalid',     response.errors[0].message
    
    assert_equal 'provider.invalid_metric', response.errors[1].code
    assert_equal 'metric does not exist',   response.errors[1].message
  end

  def test_report_with_server_error
    FakeWeb.register_uri(:post, 'http://server.3scale.net/transactions.xml',
                         :status => ['500', 'Internal Server Error'],
                         :body   => 'OMG! WTF!')

    assert_raise ThreeScale::ServerError do
      @client.report({:user_key => 'foo', :usage => {'hits' => 1}})
    end
  end
end
