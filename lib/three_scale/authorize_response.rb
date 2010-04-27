require 'time'

module ThreeScale
  class AuthorizeResponse < Response
    def initialize(options = {})
      super({:success => true}.merge(options))
      @usages = options[:usages] || []
    end

    attr_accessor :plan

    class Usage
      attr_reader :metric
      attr_reader :period
      attr_reader :current_value
      attr_reader :max_value

      def initialize(options = {})
        options.each do |name, value|
          instance_variable_set("@#{name}", value)
        end
      end

      def period_start
        @parsed_period_start ||= @period_start && Time.parse(@period_start)
      end

      def period_end
        @parsed_period_end ||= @period_end && Time.parse(@period_end)
      end
    end      

    attr_reader :usages

    def add_usage(options)
      @usages << Usage.new(options)
    end
  end
end
