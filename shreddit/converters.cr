module Shreddit
  module ArrayConverter
    def self.from_json(pull : JSON::PullParser)
      res = [] of RedditObject
      pull.read_array do
        res << RedditThing.from_json(pull)
      end
      return res
    end
  end

  module AssertTypeConverter(T)
    def self.from_json(pull : JSON::PullParser)
      res = RedditThing.from_json(pull)
      if res.is_a?(T)
        return res
      else
        raise ArgumentError.new("Expecting type #{T}, got type #{res.class}")
      end
    end
  end
  
  module RepliesConverter
    def self.from_json(pull : JSON::PullParser)
      if (str = pull.read?(String))
        raise "expected empty string" if !str.empty?
        return Listing.new()
      else
        return AssertTypeConverter(Listing).from_json(pull)
      end
    end
  end
  
  module TimeStampConverter
    def self.from_json(pull)
      unix = pull.read_float
      raise "this shouldn't happen" if (unix - unix.to_i) != 0.0
      return Time.epoch(unix.to_i)
    end
  end
  
  module BoolOrTimeStampConverter
    def self.from_json(pull)
      case pull.type
      when :float, :int
        return TimeStampConverter.from_json(pull)
      when :bool
        return pull.read_bool
      else
        raise "expected float, int, or bool but type was #{pull.type}"
      end
    end
  end
end
