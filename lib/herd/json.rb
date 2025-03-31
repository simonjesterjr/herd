require 'oj'

module Herd
  class JSON
    def self.encode(data)
      Oj.dump(data, :mode => :rails)
    end

    def self.decode(data, options = {})
      options.merge!( symbol_keys: true )
      Oj.load(data, options)
    end
  end
end
