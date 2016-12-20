# A simple module to encode hashes of param keys and values as expected by
# Rack in its nested queries parsing.
#
module ThreeScale
  class Client
    module RackQuery
      class << self
        def encode(hash)
          hash.flat_map do |hk, hv|
            encode_value(CGI.escape(hk.to_s), hv)
          end.join('&'.freeze)
        end

        private

        def encode_value(rack_param, val)
          if val.is_a? Array
            encode_array(rack_param, val)
          elsif val.is_a? Hash
            encode_hash(rack_param, val)
          else
            "#{rack_param}=#{CGI.escape(val.to_s)}"
          end
        end

        def encode_array(rack_param, val)
          rack_param = rack_param + '[]'
          val.flat_map do |v|
            encode_value(rack_param, v)
          end
        end

        def encode_hash(rack_param, val)
          val.flat_map do |k, v|
            encode_value(rack_param + "[#{CGI.escape(k.to_s)}]", v)
          end
        end
      end
    end
  end
end
