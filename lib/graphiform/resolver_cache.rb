require 'monitor'
module Graphiform
  module ResolverCache
    @cache = {}
    @monitor = Monitor.new

    def self.fetch(key)
      @monitor.synchronize do
        @cache[key] ||= yield
      end
    end

    def self.clear!
      @monitor.synchronize { @cache.clear }
    end

    def self.size
      @cache.size
    end
  end
end
