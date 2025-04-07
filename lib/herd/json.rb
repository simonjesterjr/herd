require 'oj'

module Herd
  module JSON
    def self.dump(obj)
      Oj.dump(obj, mode: :compat)
    end

    def self.load(json)
      return nil if json.nil?
      Oj.load(json, mode: :compat)
    end

    def self.encode(obj)
      Oj.dump(obj, mode: :compat)
    end

    def self.decode(json)
      Oj.load(json, mode: :compat)
    end
  end
end
