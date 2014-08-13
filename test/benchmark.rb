require 'benchmark'

require '3scale/client'

provider_key = ENV['TEST_3SCALE_PROVIDER_KEY']

client = ThreeScale::Client.new(:provider_key => provider_key)
persistent_client = ThreeScale::Client.new(:provider_key => provider_key, :persistent => true)
persistent_ssl_client = ThreeScale::Client.new(:provider_key => provider_key, :secure => true, :persistent => true)
ssl_client = ThreeScale::Client.new(:provider_key => provider_key, :secure => true)

auth = { :app_id => ENV['TEST_3SCALE_APP_IDS'], :app_key => ENV['TEST_3SCALE_APP_KEYS'] }

N = 10

Benchmark.bmbm do |x|
  x.report('http') { N.times{ client.authorize(auth) } }
  x.report('http+persistent') { N.times{ persistent_client.authorize(auth) } }
  x.report('https+persistent') { N.times{ persistent_ssl_client.authorize(auth) } }
  x.report('https') { N.times{ ssl_client.authorize(auth) } }
end
