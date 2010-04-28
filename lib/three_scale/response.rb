module ThreeScale
  class Response
    def initialize(options)
      @success = options[:success]
      @errors  = options[:errors] || []
    end

    def success?
      @success
    end
  
    Error = Struct.new(:index, :code, :message)
    
    attr_reader :errors

    def add_error(*args)
      @errors << Error.new(*args)
    end
  end
end

