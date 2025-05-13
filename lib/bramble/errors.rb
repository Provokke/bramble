module Bramble
  class Error < StandardError; end

  class UsageError < Error; end

  class NotFound < Error
    def initialize(id)
      super("no item with id #{id}")
    end
  end

  class CorruptStore < Error
    def initialize(path, line_number, reason)
      super("#{path}:#{line_number}: #{reason}")
    end
  end
end
