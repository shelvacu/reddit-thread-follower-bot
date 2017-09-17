require "./listing-hack"

module Shreddit
  class Listing #< Array(RedditObject)
    @after : String?
    @before : String?
    
    property after, before
    
    def initialize(pull : JSON::PullParser)
      super()
      pull.read_object do |key|
        case key
        when "after"
          @after  = pull.read_string_or_null
        when "before"
          @before = pull.read_string_or_null
        when "children"
          pull.read_array do
            self << RedditThing.from_json(pull)
          end
        else
          pull.skip
        end
      end
    end
  end     
end
