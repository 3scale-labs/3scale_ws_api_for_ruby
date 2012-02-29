require 'time'

module ThreeScale
  class AuthorizeResponse < Response
    def initialize
      super
      @usage_reports = []
    end

    attr_accessor :plan
    attr_accessor :app_key
    attr_accessor :redirect_url

    class UsageReport
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

      def exceeded?
        current_value > max_value
      end
    end

    attr_reader :usage_reports

    def add_usage_report(options)
      @usage_reports << UsageReport.new(options)
    end
  end
end
