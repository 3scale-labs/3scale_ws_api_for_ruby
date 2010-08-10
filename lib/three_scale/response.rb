module ThreeScale
  class Response
    def success!
      @error_code = nil
      @error_message = nil
    end

    def error!(message, code = nil)
      @error_code = code
      @error_message = message
    end

    def success?
      @error_code.nil? && @error_message.nil?
    end
 
    # System error code.
    attr_reader :error_code

    # Human readable error message.
    attr_reader :error_message  
  end
end

