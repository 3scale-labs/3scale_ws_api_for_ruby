require 'time'

module ThreeScale
  class AuthorizeResponse < Response
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

    # These 2 constants are defined according to what the 3scale
    # backend returns in the response of authorize calls.
    LIMITS_EXCEEDED = 'limits_exceeded'.freeze
    private_constant :LIMITS_EXCEEDED
    LIMITS_EXCEEDED_MSG = 'usage limits are exceeded'.freeze
    private_constant :LIMITS_EXCEEDED_MSG

    attr_accessor :plan
    attr_accessor :app_key
    attr_accessor :redirect_url
    attr_accessor :service_id
    attr_reader :usage_reports
    attr_reader :hierarchy # Not part of the stable API

    def initialize
      super
      @usage_reports = []

      # hierarchy is a hash where the keys are metric names, and the values
      # their children (array of metric names).
      # Only metrics that have at least one child appear as keys.
      @hierarchy = {}
    end

    def add_usage_report(options)
      @usage_reports << UsageReport.new(options)
    end

    def add_metric_to_hierarchy(metric_name, children)
      @hierarchy[metric_name] = children
    end

    # The response already specifies whether any usage report (if present)
    # is over the limits, so use that instead of scanning the reports.
    def limits_exceeded?
      error_code == LIMITS_EXCEEDED || error_message == LIMITS_EXCEEDED_MSG
    end
  end
end
