require 'test/unit'
require 'fakeweb'
require 'mocha'

require 'three_scale/client'

class ThreeScale::ClientTest < Test::Unit::TestCase
  def setup
    FakeWeb.clean_registry
    FakeWeb.allow_net_connect = false

    @client = ThreeScale::Client.new(:provider_key => '1234abcd')
    @host   = ThreeScale::Client::DEFAULT_HOST
  end

  def test_raises_exception_if_provider_key_is_missing
    assert_raise ArgumentError do
      ThreeScale::Client.new({})
    end
  end

  def test_default_host
    client = ThreeScale::Client.new(:provider_key => '1234abcd')

    assert_equal 'su1.3scale.net', client.host
  end

  def test_successful_authorize
    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
             
              <usage_reports>
                <usage_report metric="hits" period="day">
                  <period_start>2010-04-26 00:00:00 +0000</period_start>
                  <period_end>2010-04-27 00:00:00 +0000</period_end>
                  <current_value>10023</current_value>
                  <max_value>50000</max_value>
                </usage_report>

                <usage_report metric="hits" period="month">
                  <period_start>2010-04-01 00:00:00 +0000</period_start>
                  <period_end>2010-05-01 00:00:00 +0000</period_end>
                  <current_value>999872</current_value>
                  <max_value>150000</max_value>
                </usage_report>
              </usage_reports>
            </status>'

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&user_key=foo", :status => ['200', 'OK'], :body => body)

    response = @client.authorize(:user_key => 'foo')

    assert response.success?
    assert_equal 'Ultimate', response.plan
    assert_equal 2, response.usage_reports.size
    
    assert_equal :day, response.usage_reports[0].period
    assert_equal Time.utc(2010, 4, 26), response.usage_reports[0].period_start
    assert_equal Time.utc(2010, 4, 27), response.usage_reports[0].period_end
    assert_equal 10023, response.usage_reports[0].current_value
    assert_equal 50000, response.usage_reports[0].max_value

    assert_equal :month, response.usage_reports[1].period
    assert_equal Time.utc(2010, 4, 1), response.usage_reports[1].period_start
    assert_equal Time.utc(2010, 5, 1), response.usage_reports[1].period_end
    assert_equal 999872, response.usage_reports[1].current_value
    assert_equal 150000, response.usage_reports[1].max_value
  end

  def test_authorize_with_exceeded_usage_limits
    body = '<status>
              <authorized>false</authorized>
              <reason>usage limits are exceeded</reason>

              <plan>Ultimate</plan>
             
              <usage_reports>
                <usage_report metric="hits" period="day" exceeded="true">
                  <period_start>2010-04-26 00:00:00 +0000</period_start>
                  <period_end>2010-04-27 00:00:00 +0000</period_end>
                  <current_value>50002</current_value>
                  <max_value>50000</max_value>
                </usage_report>

                <usage_report metric="hits" period="month">
                  <period_start>2010-04-01 00:00:00 +0000</period_start>
                  <period_end>2010-05-01 00:00:00 +0000</period_end>
                  <current_value>999872</current_value>
                  <max_value>150000</max_value>
                </usage_report>
              </usage_reports>
            </status>'
    
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&user_key=foo", :status => ['200', 'OK'], :body => body)
    
    response = @client.authorize(:user_key => 'foo')

    assert !response.success?
    assert_equal 'usage limits are exceeded', response.error_message
    assert response.usage_reports[0].exceeded?
  end

  def test_authorize_with_invalid_user_key
    body = '<error code="user_key_invalid">user key "foo" is invalid</error>'
    
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&user_key=foo", :status => ['403', 'Forbidden'], :body => body)

    response = @client.authorize(:user_key => 'foo')

    assert !response.success?
    assert_equal 'user_key_invalid',          response.error_code
    assert_equal 'user key "foo" is invalid', response.error_message
  end
  
  def test_authorize_with_server_error
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&user_key=foo", :status => ['500', 'Internal Server Error'], :body => 'OMG! WTF!')

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
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
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
    error_body = '<error code="provider_key_invalid">provider key "foo" is invalid</error>'

    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['403', 'Forbidden'],
                         :body   => error_body)
   
    client   = ThreeScale::Client.new(:provider_key => 'foo')                         
    response = client.report({:user_key => 'abc', :usage => {'hits' => 1}})

    assert !response.success?
    assert_equal 'provider_key_invalid',          response.error_code
    assert_equal 'provider key "foo" is invalid', response.error_message
  end

  def test_report_with_server_error
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['500', 'Internal Server Error'],
                         :body   => 'OMG! WTF!')

    assert_raise ThreeScale::ServerError do
      @client.report({:user_key => 'foo', :usage => {'hits' => 1}})
    end
  end
end
