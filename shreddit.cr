require "./shreddit/*"

module Shreddit
  def self.read_thing(pull : JSON::PullParser)
    case pull.kind
    when :begin_array
      res = [] of RedditObject
      pull.read_array do
        res << RedditThing.from_json(pull)
      end
      return res
    when :begin_object
      return RedditThing.from_json(pull)
    else
      raise "not implemented #{pull.kind}"
    end
  end

  def self.read_thing(resp : (String | IO))
    pull = JSON::PullParser.new(resp)
    read_thing(pull)
  end

  def self.read_thing(resp : HTTP::Client::Response)
    body = resp.body? || resp.body_io
    read_thing(body)
  end
end
