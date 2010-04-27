module ThreeScale
  class Response
    def initialize(options)
      @success = options[:success]
      @errors  = options[:errors] || []
    end

    def success?
      @success
    end
  
    Error = Struct.new(:code, :message)
    
    attr_reader :errors

    def add_error(index, code, message)
      @errors[index] = Error.new(code, message)
    end
  end
end

