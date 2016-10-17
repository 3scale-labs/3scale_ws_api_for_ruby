require 'time'

module ThreeScale
  class AuthorizeResponse < Response
    def initialize
      super
      @usage_reports = []

      # hierarchy is a hash where the keys are metric names, and the values
      # their children (array of metric names).
      # Only metrics that have at least one child appear as keys.
      @hierarchy = {}
    end

    attr_accessor :plan
    attr_accessor :app_key
    attr_accessor :redirect_url
    attr_accessor :service_id
    attr_reader :usage_reports
    attr_reader :hierarchy # Not part of the stable API

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

    def add_usage_report(options)
      @usage_reports << UsageReport.new(options)
    end

    def add_metric_to_hierarchy(metric_name, children)
      @hierarchy[metric_name] = children
    end
  end
end
