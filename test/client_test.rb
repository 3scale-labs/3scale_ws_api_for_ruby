require 'minitest/autorun'

require 'fakeweb'
require 'mocha/setup'

require '3scale/client'

class ThreeScale::ClientTest < MiniTest::Test

  WARN_DEPRECATED = ENV['WARN_DEPRECATED'] == '1'

  def client(options = {})
    ThreeScale::Client.new({ provider_key: '1234abcd',
                             warn_deprecated: WARN_DEPRECATED }.merge(options))
  end

  def setup
    FakeWeb.clean_registry
    FakeWeb.allow_net_connect = false

    @client = client
    @host   = ThreeScale::Client::DEFAULT_HOST
  end

  def test_raises_exception_if_no_credentials_are_specified
    assert_raises ArgumentError do
      ThreeScale::Client.new({})
    end
    assert_raises ArgumentError do
      ThreeScale::Client.new(service_tokens: false)
    end
  end

  def test_does_not_raise_if_some_credentials_are_specified
    assert ThreeScale::Client.new(provider_key: 'some_key',
                                  warn_deprecated: WARN_DEPRECATED)
    assert ThreeScale::Client.new(service_tokens: true)
  end

  def test_default_host
    client = ThreeScale::Client.new(provider_key: '1234abcd',
                                    warn_deprecated: WARN_DEPRECATED)

    assert_equal 'su1.3scale.net', client.host
  end

  def test_custom_host
    client = ThreeScale::Client.new(provider_key: '1234abcd',
                                    warn_deprecated: WARN_DEPRECATED,
                                    host: "example.com")

    assert_equal 'example.com', client.host
  end

  def test_default_protocol
    client = ThreeScale::Client.new(provider_key: 'test',
                                    warn_deprecated: WARN_DEPRECATED)
    assert_equal false, client.http.use_ssl?
  end

  def test_insecure_protocol
    client = ThreeScale::Client.new(provider_key: 'test',
                                    warn_deprecated: WARN_DEPRECATED,
                                    secure: false)
    assert_equal false, client.http.use_ssl?
  end

  def test_secure_protocol
    client = ThreeScale::Client.new(provider_key: 'test',
                                    warn_deprecated: WARN_DEPRECATED,
                                    secure: true)
    assert_equal true, client.http.use_ssl?
  end

  def test_authrep_usage_is_encoded
    assert_authrep_url_with_params "&%5Busage%5D%5Bmethod%5D=666"

    @client.authrep({:usage => {:method=> 666}})
  end

  def test_secure_authrep
    assert_secure_authrep_url_with_params
    client(:secure => true).authrep({})
  end

  def test_authrep_usage_values_are_encoded
    assert_authrep_url_with_params "&%5Busage%5D%5Bhits%5D=%230"

    @client.authrep({:usage => {:hits => "#0"}})
  end

  def test_authrep_usage_defaults_to_hits_1
    assert_authrep_url_with_params "&%5Busage%5D%5Bhits%5D=1"

    @client.authrep({})
  end

  def test_authrep_supports_app_id_app_key_auth_mode
    assert_authrep_url_with_params "&app_id=appid&app_key=appkey&%5Busage%5D%5Bhits%5D=1"

    @client.authrep(:app_id => "appid", :app_key => "appkey")
  end

  def test_authrep_supports_service_id
    assert_authrep_url_with_params "&%5Busage%5D%5Bhits%5D=1&service_id=serviceid"

    @client.authrep(:service_id => "serviceid")
  end

  #TODO these authrep tests
  # def test_authrep_supports_api_key_auth_mode; end
  # def test_authrep_log_is_encoded;end
  # def test_authrep_passes_all_params_to_backend;end

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

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&app_id=foo", :status => ['200', 'OK'], :body => body)

    response = @client.authorize(:app_id => 'foo')

    assert response.success?
    assert !response.limits_exceeded?
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

  def test_successful_authorize_with_app_keys
    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
            </status>'

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&app_id=foo&app_key=toosecret", :status => ['200', 'OK'], :body => body)

    response = @client.authorize(:app_id => 'foo', :app_key => 'toosecret')
    assert response.success?
  end

  def test_successful_authorize_with_user_key
    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
            </status>'

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&user_key=foo", :status => ['200', 'OK'], :body => body)

    response = @client.authorize(:user_key => 'foo')
    assert response.success?
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

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&app_id=foo", :status => ['409'], :body => body)

    response = @client.authorize(:app_id => 'foo')

    assert !response.success?
    assert response.limits_exceeded?
    assert_equal 'usage limits are exceeded', response.error_message
    assert response.usage_reports.any? { |report| report.exceeded? }
  end

  def test_authorize_with_invalid_app_id
    body = '<error code="application_not_found">application with id="foo" was not found</error>'

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&app_id=foo", :status => ['403', 'Forbidden'], :body => body)

    response = @client.authorize(:app_id => 'foo')

    assert !response.success?
    assert !response.limits_exceeded?
    assert_equal 'application_not_found',                   response.error_code
    assert_equal 'application with id="foo" was not found', response.error_message
  end

  def test_authorize_with_server_error
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&app_id=foo", :status => ['500', 'Internal Server Error'], :body => 'OMG! WTF!')

    assert_raises ThreeScale::ServerError do
      @client.authorize(:app_id => 'foo')
    end
  end

  def test_authorize_with_usage_within_limits
    url = "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd"\
          "&app_id=foo&%5Busage%5D%5Bmetric1%5D=1&%5Busage%5D%5Bmetric2%5D=2"

    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
            </status>'

    FakeWeb.register_uri(:get, url, :status => ['200', 'OK'], :body => body)

    response = @client.authorize(:app_id => 'foo',
                                 :usage => { 'metric1' => 1, 'metric2' => 2 })

    assert response.success?
    assert !response.limits_exceeded?
  end

  def test_authorize_with_usage_and_limits_exceeded
    url = "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd"\
          "&app_id=foo&%5Busage%5D%5Bhits%5D=1"

    body = '<status>
              <authorized>false</authorized>
              <reason>usage limits are exceeded</reason>

              <plan>Ultimate</plan>

              <usage_reports>
                <usage_report metric="hits" period="day" exceeded="true">
                  <period_start>2010-04-26 00:00:00 +0000</period_start>
                  <period_end>2010-04-27 00:00:00 +0000</period_end>
                  <current_value>10</current_value>
                  <max_value>5</max_value>
                </usage_report>
              </usage_reports>
            </status>'

    FakeWeb.register_uri(:get, url, :status => ['409'], :body => body)

    response = @client.authorize(:app_id => 'foo', :usage => { 'hits' => 1 })

    assert !response.success?
    assert response.limits_exceeded?
    assert_equal 'usage limits are exceeded', response.error_message
  end

  def test_hierarchy
    # Hierarchies can be retrieved in authorize, authrep, and oauth_authorize
    # calls.
    urls = [:authorize, :authrep, :oauth_authorize].inject({}) do |acc, method|
      acc[method] = "http://#{@host}/transactions/#{method}.xml?"\
                    "provider_key=1234abcd&app_id=foo"
      acc[method] << "&%5Busage%5D%5Bhits%5D=1" if method == :authrep
      acc
    end

    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>

              <usage_reports>
                <usage_report metric="parent1" period="day">
                  <period_start>2016-01-01 00:00:00 +0000</period_start>
                  <period_end>2016-01-02 00:00:00 +0000</period_end>
                  <max_value>1000</max_value>
                  <current_value>10</current_value>
                </usage_report>
                <usage_report metric="parent2" period="day">
                  <period_start>2016-01-01 00:00:00 +0000</period_start>
                  <period_end>2016-01-02 00:00:00 +0000</period_end>
                  <max_value>100</max_value>
                  <current_value>1</current_value>
                </usage_report>
                <usage_report metric="child1" period="day">
                  <period_start>2016-01-01 00:00:00 +0000</period_start>
                  <period_end>2016-01-02 00:00:00 +0000</period_end>
                  <max_value>1000</max_value>
                  <current_value>5</current_value>
                </usage_report>
                <usage_report metric="child2" period="day">
                  <period_start>2016-01-01 00:00:00 +0000</period_start>
                  <period_end>2016-01-02 00:00:00 +0000</period_end>
                  <max_value>1000</max_value>
                  <current_value>5</current_value>
                </usage_report>
                <usage_report metric="child3" period="day">
                  <period_start>2016-01-01 00:00:00 +0000</period_start>
                  <period_end>2016-01-02 00:00:00 +0000</period_end>
                  <max_value>100</max_value>
                  <current_value>5</current_value>
                </usage_report>
              </usage_reports>

              <hierarchy>
                <metric name="parent1" children="child1 child2" />
                <metric name="parent2" children="child3" />
              </hierarchy>
            </status>'

    urls.each do |method, url|
      FakeWeb.register_uri(:get, url, :status => ['200', 'OK'], :body => body)
      response = @client.send(method, :app_id => 'foo', extensions: { :hierarchy => 1 })
      assert_equal response.hierarchy, { 'parent1' => ['child1', 'child2'],
                                         'parent2' => ['child3'] }
    end
  end

  def test_successful_oauth_authorize
    body = '<status>
              <authorized>true</authorized>
              <application>
                <id>94bd2de3</id>
                <key>883bdb8dbc3b6b77dbcf26845560fdbb</key>
                <redirect_url>http://localhost:8080/oauth/oauth_redirect</redirect_url>
              </application>
              <plan>Ultimate</plan>
              <usage_reports>
                <usage_report metric="hits" period="week">
                  <period_start>2012-01-30 00:00:00 +0000</period_start>
                  <period_end>2012-02-06 00:00:00 +0000</period_end>
                  <max_value>5000</max_value>
                  <current_value>1</current_value>
                </usage_report>
                <usage_report metric="update" period="minute">
                  <period_start>2012-02-03 00:00:00 +0000</period_start>
                  <period_end>2012-02-03 00:00:00 +0000</period_end>
                  <max_value>0</max_value>
                  <current_value>0</current_value>
                </usage_report>
              </usage_reports>
            </status>'

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/oauth_authorize.xml?provider_key=1234abcd&app_id=foo&redirect_url=http%3A%2F%2Flocalhost%3A8080%2Foauth%2Foauth_redirect", :status => ['200', 'OK'], :body => body)

    response = @client.oauth_authorize(:app_id => 'foo', :redirect_url => "http://localhost:8080/oauth/oauth_redirect")
    assert response.success?
    assert !response.limits_exceeded?

    assert_equal '883bdb8dbc3b6b77dbcf26845560fdbb', response.app_key
    assert_equal 'http://localhost:8080/oauth/oauth_redirect', response.redirect_url

    assert_equal 'Ultimate', response.plan
    assert_equal 2, response.usage_reports.size

    assert_equal :week, response.usage_reports[0].period
    assert_equal Time.utc(2012, 1, 30), response.usage_reports[0].period_start
    assert_equal Time.utc(2012, 02, 06), response.usage_reports[0].period_end
    assert_equal 1, response.usage_reports[0].current_value
    assert_equal 5000, response.usage_reports[0].max_value

    assert_equal :minute, response.usage_reports[1].period
    assert_equal Time.utc(2012, 2, 03), response.usage_reports[1].period_start
    assert_equal Time.utc(2012, 2, 03), response.usage_reports[1].period_end
    assert_equal 0, response.usage_reports[1].current_value
    assert_equal 0, response.usage_reports[1].max_value
  end

  def test_oauth_authorize_with_exceeded_usage_limits
    body = '<status>
              <authorized>false</authorized>
              <reason>usage limits are exceeded</reason>
              <application>
                <id>94bd2de3</id>
                <key>883bdb8dbc3b6b77dbcf26845560fdbb</key>
                <redirect_url>http://localhost:8080/oauth/oauth_redirect</redirect_url>
              </application>
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

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/oauth_authorize.xml?provider_key=1234abcd&app_id=foo", :status => ['409'], :body => body)

    response = @client.oauth_authorize(:app_id => 'foo')

    assert !response.success?
    assert response.limits_exceeded?
    assert_equal 'usage limits are exceeded', response.error_message
    assert response.usage_reports.any? { |report| report.exceeded? }
  end

  def test_oauth_authorize_with_invalid_app_id
    body = '<error code="application_not_found">application with id="foo" was not found</error>'

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/oauth_authorize.xml?provider_key=1234abcd&app_id=foo", :status => ['403', 'Forbidden'], :body => body)

    response = @client.oauth_authorize(:app_id => 'foo')

    assert !response.success?
    assert !response.limits_exceeded?
    assert_equal 'application_not_found',                   response.error_code
    assert_equal 'application with id="foo" was not found', response.error_message
  end

  def test_oauth_authorize_with_server_error
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/oauth_authorize.xml?provider_key=1234abcd&app_id=foo", :status => ['500', 'Internal Server Error'], :body => 'OMG! WTF!')

    assert_raises ThreeScale::ServerError do
      @client.oauth_authorize(:app_id => 'foo')
    end
  end

  def test_oauth_authorize_with_usage_within_limits
    url = "http://#{@host}/transactions/oauth_authorize.xml"\
          "?provider_key=1234abcd&app_id=foo&%5Busage%5D%5Bmetric1%5D=1"\
          "&%5Busage%5D%5Bmetric2%5D=2"

    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
            </status>'

    FakeWeb.register_uri(:get, url, :status => ['200', 'OK'], :body => body)

    response = @client.oauth_authorize(
        :app_id => 'foo', :usage => { 'metric1' => 1, 'metric2' => 2 })

    assert response.success?
    assert !response.limits_exceeded?
  end

  def test_oauth_authorize_with_usage_and_limits_exceeded
    url = "http://#{@host}/transactions/oauth_authorize.xml"\
          "?provider_key=1234abcd&app_id=foo&%5Busage%5D%5Bhits%5D=1"

    body = '<status>
              <authorized>false</authorized>
              <reason>usage limits are exceeded</reason>

              <plan>Ultimate</plan>

              <usage_reports>
                <usage_report metric="hits" period="day" exceeded="true">
                  <period_start>2010-04-26 00:00:00 +0000</period_start>
                  <period_end>2010-04-27 00:00:00 +0000</period_end>
                  <current_value>10</current_value>
                  <max_value>5</max_value>
                </usage_report>
              </usage_reports>
            </status>'

    FakeWeb.register_uri(:get, url, :status => ['409'], :body => body)

    response = @client.oauth_authorize(:app_id => 'foo',
                                       :usage => { 'hits' => 1 })

    assert !response.success?
    assert response.limits_exceeded?
    assert_equal 'usage limits are exceeded', response.error_message
  end

  def test_report_raises_an_exception_if_no_transactions_given
    assert_raises ArgumentError do
      @client.report
    end

    [nil, []].each do |invalid_transactions|
      assert_raises ArgumentError do
        @client.report(transactions: invalid_transactions)
      end
    end
  end

  def test_successful_report
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['200', 'OK'])

    transactions = [{ :app_id    => 'foo',
                      :timestamp => Time.local(2010, 4, 27, 15, 00),
                      :usage     => {'hits' => 1 } }]

    response = @client.report(transactions: transactions)

    assert response.success?
  end

  def test_report_encodes_transactions
    payload = {
      'transactions[0][app_id]'      => 'foo',
      'transactions[0][timestamp]'   => '2010-04-27 15:42:17 0200',
      'transactions[0][usage][hits]' => '1',
      'transactions[0][log][request]'  => 'foo',
      'transactions[0][log][response]' => 'bar',
      'transactions[0][log][code]'   => '200',
      'transactions[1][app_id]'      => 'bar',
      'transactions[1][timestamp]'   => Time.local(2010, 4, 27, 15, 00).to_s,
      'transactions[1][usage][hits]' => '1',
      'provider_key'                 => '1234abcd'
    }

    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['200', 'OK'])

    transactions = [{ :app_id    => 'foo',
                      :usage     => { 'hits' => 1 },
                      :timestamp => '2010-04-27 15:42:17 0200',
                      :log       => {
                          'request'  => 'foo',
                          'response' => 'bar',
                          'code'     => 200
                      }
                    },
                    { :app_id    => 'bar',
                      :usage     => { 'hits' => 1 },
                      :timestamp => Time.local(2010, 4, 27, 15, 00) }]

    @client.report(transactions: transactions)

    request = FakeWeb.last_request

    assert_equal URI.encode_www_form(payload), request.body
  end

  def test_report_supports_user_key
    payload = {
      'transactions[0][user_key]'    => 'foo',
      'transactions[0][timestamp]'   => '2016-07-18 15:42:17 0200',
      'transactions[0][usage][hits]' => '1',
      'provider_key'                 => '1234abcd'
    }

    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['200', 'OK'])

    transactions = [{ :user_key  => 'foo',
                      :usage     => { 'hits' => 1 },
                      :timestamp => '2016-07-18 15:42:17 0200' }]

    @client.report(transactions: transactions)

    request = FakeWeb.last_request

    assert_equal URI.encode_www_form(payload), request.body
  end

  def test_report_with_service_id
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['200', 'OK'])

    transactions = [{ :app_id    => 'an_app_id',
                      :usage     => { 'hits' => 1 },
                      :timestamp => '2016-07-18 15:42:17 0200' }]

    @client.report(transactions: transactions, service_id: 'a_service_id')

    request = FakeWeb.last_request

    payload = {
        'transactions[0][app_id]'      => 'an_app_id',
        'transactions[0][timestamp]'   => '2016-07-18 15:42:17 0200',
        'transactions[0][usage][hits]' => '1',
        'provider_key'                 => '1234abcd',
        'service_id'                   => 'a_service_id'
    }

    assert_equal URI.encode_www_form(payload), request.body
  end

  # We changed the signature of the report method but we keep the compatibility
  # with the old one: def report(*transactions).This tests only checks that
  # backwards compatibility.
  def test_report_compatibility_with_old_report_format
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['200', 'OK'])

    transactions = [{ :app_id    => 'app_id_1',
                      :usage     => { 'hits' => 1 },
                      :timestamp => '2016-07-18 15:42:17 0200' },
                    { :app_id    => 'app_id_2',
                      :usage     => { 'hits' => 2 },
                      :timestamp => '2016-07-19 15:42:17 0200' },
                    { :app_id    => 'app_id_3',
                      :usage     => { 'hits' => 3 },
                      :timestamp => '2016-07-20 15:42:17 0200' }]

    @client.report(*transactions)

    request = FakeWeb.last_request

    payload = {
        'transactions[0][app_id]'      => 'app_id_1',
        'transactions[0][timestamp]'   => '2016-07-18 15:42:17 0200',
        'transactions[0][usage][hits]' => '1',
        'transactions[1][app_id]'      => 'app_id_2',
        'transactions[1][timestamp]'   => '2016-07-19 15:42:17 0200',
        'transactions[1][usage][hits]' => '2',
        'transactions[2][app_id]'      => 'app_id_3',
        'transactions[2][timestamp]'   => '2016-07-20 15:42:17 0200',
        'transactions[2][usage][hits]' => '3',
        'provider_key'                 => '1234abcd'
    }

    assert_equal URI.encode_www_form(payload), request.body
  end

  def test_failed_report
    error_body = '<error code="provider_key_invalid">provider key "foo" is invalid</error>'

    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['403', 'Forbidden'],
                         :body   => error_body)

    client   = ThreeScale::Client.new(provider_key: 'foo',
                                      warn_deprecated: WARN_DEPRECATED)
    transactions = [{ :app_id => 'abc', :usage => { 'hits' => 1 } }]
    response = client.report(transactions: transactions)

    assert !response.success?
    assert_equal 'provider_key_invalid',          response.error_code
    assert_equal 'provider key "foo" is invalid', response.error_message
  end

  def test_report_with_server_error
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['500', 'Internal Server Error'],
                         :body   => 'OMG! WTF!')

    transactions = [{ :app_id => 'foo', :usage => { 'hits' => 1 } }]

    assert_raises ThreeScale::ServerError do
      @client.report(transactions: transactions)
    end
  end

  def test_authorize_client_header_sent
    success_body = '<?xml version="1.0" encoding="UTF-8"?><status><authorized>true</authorized><plan>Default</plan><usage_reports><usage_report metric="hits" period="minute"><period_start>2014-08-22 09:06:00 +0000</period_start><period_end>2014-08-22 09:07:00 +0000</period_end><max_value>5</max_value><current_value>0</current_value></usage_report></usage_reports></status>'
    version       = ThreeScale::Client::VERSION
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?provider_key=foo&app_id=foo",
                         :status => ['200', 'OK'],
                         :body   => success_body)

    client = ThreeScale::Client.new(provider_key: 'foo',
                                    warn_deprecated: WARN_DEPRECATED)
    response = client.authorize(:app_id => 'foo')

    assert response.success?
    assert !response.limits_exceeded?
    request = FakeWeb.last_request
    assert_equal "plugin-ruby-v#{version}", request["X-3scale-User-Agent"]
    assert_equal "su1.3scale.net", request["host"]

  end

  def test_report_client_header_sent
    success_body = '<?xml version="1.0" encoding="UTF-8"?><status><authorized>true</authorized><plan>Default</plan><usage_reports><usage_report metric="hits" period="minute"><period_start>2014-08-22 09:06:00 +0000</period_start><period_end>2014-08-22 09:07:00 +0000</period_end><max_value>5</max_value><current_value>0</current_value></usage_report></usage_reports></status>'
    version       = ThreeScale::Client::VERSION
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['200', 'OK'],
                         :body   => success_body)
    client = ThreeScale::Client.new(provider_key: 'foo',
                                    warn_deprecated: WARN_DEPRECATED)
    transactions = [{ :app_id => 'abc', :usage => { 'hits' => 1 } }]
    client.report(transactions: transactions)

    request = FakeWeb.last_request
    assert_equal "plugin-ruby-v#{version}", request["X-3scale-User-Agent"]
    assert_equal "su1.3scale.net", request["host"]
  end

  def test_authrep_client_header_sent
    success_body = '<?xml version="1.0" encoding="UTF-8"?><status><authorized>true</authorized><plan>Default</plan><usage_reports><usage_report metric="hits" period="minute"><period_start>2014-08-22 09:06:00 +0000</period_start><period_end>2014-08-22 09:07:00 +0000</period_end><max_value>5</max_value><current_value>0</current_value></usage_report></usage_reports></status>'
    version       = ThreeScale::Client::VERSION
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authrep.xml?provider_key=foo&app_id=abc&%5Busage%5D%5Bhits%5D=1",
                         :status => ['200', 'OK'],
                         :body   => success_body)

    client = ThreeScale::Client.new(provider_key: 'foo',
                                    warn_deprecated: WARN_DEPRECATED)
    response = client.authrep(:app_id => 'abc')

    assert response.success?
    assert !response.limits_exceeded?
    request = FakeWeb.last_request
    assert_equal "plugin-ruby-v#{version}", request["X-3scale-User-Agent"]
    assert_equal "su1.3scale.net", request["host"]
  end

  EXTENSIONS_HASH = {
    'a special &=key' => 'a special =&value',
    'ary' => [1,2],
    'a hash' => { one: 'one', two: 'two' },
    'combined' =>
      { v: 'v', nested: [1, { h: [ { hh: [ { hhh: :deep }, 'val' ] } ], h2: :h2 } ] }
  }
  private_constant :EXTENSIONS_HASH
  EXTENSIONS_STR  = "a+special+%26%3Dkey=a+special+%3D%26value&ary[]=1&ary[]=2&" \
                    "a+hash[one]=one&a+hash[two]=two&combined[v]=v&" \
                    "combined[nested][]=1&combined[nested][][h][][hh][][hhh]=deep&" \
                    "combined[nested][][h][][hh][]=val&combined[nested][][h2]=h2".freeze
  private_constant :EXTENSIONS_STR

  def test_authorize_with_extensions
    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
            </status>'
    FakeWeb.register_uri(:get,
                         "http://#{@host}/transactions/authorize.xml?provider_key=1234abcd&app_id=foo",
                         :status => ['200', 'OK'], body: body)

    @client.authorize(:app_id => 'foo', extensions: EXTENSIONS_HASH)

    request = FakeWeb.last_request
    assert_equal EXTENSIONS_STR, request[ThreeScale::Client.const_get('EXTENSIONS_HEADER')]
  end

  def test_authrep_with_extensions
    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
            </status>'
    FakeWeb.register_uri(:get,
                         "http://#{@host}/transactions/authrep.xml?provider_key=1234abcd&app_id=foo&%5Busage%5D%5Bhits%5D=1",
                         :status => ['200', 'OK'], body: body)

    @client.authrep(:app_id => 'foo', extensions: EXTENSIONS_HASH)

    request = FakeWeb.last_request
    assert_equal EXTENSIONS_STR, request['3scale-options']
  end

  def test_report_with_extensions
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml",
                         :status => ['200', 'OK'])

    transactions = [{ :app_id    => 'app_id_1',
                      :usage     => { 'hits' => 1 },
                      :timestamp => '2016-07-18 15:42:17 0200' }]

    @client.report(transactions: transactions, service_id: 'a_service_id',
                   extensions: EXTENSIONS_HASH)

    request = FakeWeb.last_request
    assert_equal EXTENSIONS_STR, request['3scale-options']
  end

  def test_client_initialized_with_sevice_tokens_uses_percall_specified_token
    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
            </status>'
    transactions = [{ app_id:    'foo',
                      timestamp: Time.local(2010, 4, 27, 15, 00),
                      usage:     {'hits' => 1 } }]
    usage = { 'metric1' => 1, 'metric2' => 2}

    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authorize.xml?user_key=foo&service_id=1&service_token=newtoken", status: ['200', 'OK'], body: body)
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/authrep.xml?service_token=newtoken&user_key=foo&service_id=1&%5Busage%5D%5Bhits%5D=1", status: ['200', 'OK'], body: body)
    FakeWeb.register_uri(:post, "http://#{@host}/transactions.xml", parameters: {service_token: 'newtoken', service_id: '1', transactions: transactions}, status: ['200', 'OK'])
    FakeWeb.register_uri(:get, "http://#{@host}/transactions/oauth_authorize.xml?service_id=1&%5Busage%5D%5Bmetric1%5D=1&%5Busage%5D%5Bmetric2%5D=2&service_token=newtoken",
                         status: ['200', 'OK'], body: body)

    client = ThreeScale::Client.new(service_tokens: true)

    response = client.authorize(user_key: 'foo', service_token: 'newtoken', service_id: 1)
    assert response.success?
    response = client.authrep(user_key: 'foo', service_token: 'newtoken', service_id: 1)
    assert response.success?
    response = client.report(transactions: transactions, service_token: 'newtoken', service_id: 1)
    assert response.success?
    response = client.oauth_authorize(access_token: 'oauth', usage: usage, service_token: 'newtoken', service_id: 1)
    assert response.success?
  end

  def test_client_initialized_with_service_tokens_raises_if_unspecified_percall
    transactions = [{ app_id:    'foo',
                      timestamp: Time.local(2010, 4, 27, 15, 00),
                      usage:     {'hits' => 1 } }]
    usage = { 'metric1' => 1, 'metric2' => 2}

    client = ThreeScale::Client.new(service_tokens: true)

    assert_raises ArgumentError do
      client.authorize(user_key: 'foo', service_id: 1)
    end
    assert_raises ArgumentError do
      client.authrep(user_key: 'foo', service_id: 1)
    end
    assert_raises ArgumentError do
      client.report(transactions: transactions, service_id: 1)
    end
    assert_raises ArgumentError do
      client.oauth_authorize(user_key: 'foo', usage: usage, service_id: 1)
    end
  end

  private

  #OPTIMIZE this tricky test helper relies on fakeweb catching the urls requested by the client
  # it is brittle: it depends in the correct order or params in the url
  #
  def assert_authrep_url_with_params(str, protocol = 'http')
    authrep_url = "#{protocol}://#{@host}/transactions/authrep.xml?provider_key=#{@client.provider_key}"
    params = str # unless str.scan(/log/)
    params << "&%5Busage%5D%5Bhits%5D=1" unless params.scan(/usage.*hits/)
    parsed_authrep_url = URI.parse(authrep_url + params)
    # set to have the client working
    body = '<status>
              <authorized>true</authorized>
              <plan>Ultimate</plan>
            </status>'

    # this is the actual assertion, if fakeweb raises the client is submiting with wrong params
    FakeWeb.register_uri(:get, parsed_authrep_url, :status => ['200', 'OK'], :body => body)
  end

  def assert_secure_authrep_url_with_params(str = '&%5Busage%5D%5Bhits%5D=1')
    assert_authrep_url_with_params(str, 'https')
  end
end

class ThreeScale::NetHttpPersistentClientTest < ThreeScale::ClientTest
  def client(options = {})
    ThreeScale::Client::HTTPClient.persistent_backend = ThreeScale::Client::HTTPClient::NetHttpPersistent
    ThreeScale::Client.new({ provider_key: '1234abcd',
                             warn_deprecated: WARN_DEPRECATED,
                             persistent: true,
                           }.merge(options))
  end
end

class ThreeScale::NetHttpKeepAliveClientTest < ThreeScale::NetHttpPersistentClientTest
  def client(options = {})
    ThreeScale::Client::HTTPClient.persistent_backend = ThreeScale::Client::HTTPClient::NetHttpKeepAlive
    super
  end
end
