require "./listing-hack"

module Shreddit
  TYPE_MAPPING = {
    "Listing" => Listing,
    "t1" => Comment,
    "t2" => Account,
    "t3" => Link,
    "t4" => Message,
    "t5" => Subreddit,
    "t6" => Award,
    "more" => More
  }

  abstract class Thing
    def self.from_json(pull : JSON::PullParser)
      kind = ""
      res = nil
      pull.read_object do |key|
        case key
        when "kind"
          kind = pull.read_string
        when "data"
          if kind == ""
            raise "The software needs to be redesigned"
          end
          res = TYPE_MAPPING[kind].new(pull)
        else
          # TODO: warn about unrecognized object key
          pull.skip
        end
      end
      return res.not_nil!
    end
    
    def fullname
      name
    end
    
    abstract def initialize(pull : JSON::PullParser)
  end
end

