######################################################################
#
# This file is part of reddit-thread-follower.
#
# reddit-thread-follower is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# reddit-thread-follower is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with reddit-thread-follower. If not, see <http://www.gnu.org/licenses/>.
#
######################################################################

require "json"
require "http/client"
require "oauth"

def die(msg)
  STDERR.puts msg
  exit 1
end

abstract class RedditThing
end

module ListingHack
end

class Listing < Array(RedditThing | ListingHack)
  include ListingHack
end

alias RedditObject = (RedditThing | Listing)

abstract class RedditThing
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
  
  TYPE_MAPPING = {
    "Listing" => Listing,
    "t1" => Comment,
    "t3" => Post,
    "more" => MoreReddit
  }
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
  
  #abstract def initialize(pull : JSON::PullParser)
end

class MoreReddit < RedditThing
  JSON.mapping(
    count: Int64,
    name: String,
    id: String,
    parent_id: String,
    depth: Int64,
    children: Array(String)#{type: Array(RedditThing), converter: RedditThing::ArrayConverter}
  )
end

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

  def initialize()
    super
  end
end     

class DefunctListing < RedditThing
  JSON.mapping(
    #modhash: String?,
    children: {type: Array(RedditObject), converter: RedditThing::ArrayConverter},
    after: String?,
    before: String?
  )
  
  def initialize
    @children = [] of RedditObject
  end
  
  #  delegate :[], :[]=, size, each, to: @children
end

class Comment < RedditThing
  JSON.mapping(
    subreddit_id: String,
    #approved_at_utc: Int64?,
    #banned_by:
    #removal_reason:
    link_id: String,
    likes: Bool?,
    replies: {type: Listing, converter: RedditThing::RepliesConverter},
    #user_reports:
    saved: Bool,
    id: String,
    #banned_at_utc:
    gilded: Int64,
    archived: Bool,
    #report_reasons:
    author: String,
    can_mod_post: Bool,
    ups: Int64,
    parent_id: String,
    score: Int64,
    #approved_by: String?,
    downs: Int64, #always zero?
    body: String,
    #edited: (Float64|Bool), # This is annoying complicated, prob needs its own conv
    #author_flair_css_class: String?,
    collapsed: Bool,
    is_submitter: Bool,
    #collapsed_reason:
    body_html: String,
    stickied: Bool,
    can_gild: Bool,
    subreddit: String,
    score_hidden: Bool,
    subreddit_type: String,
    name: String,
    #created: Float64,
    #author_flair_text:
    created_utc: {type: Time, converter: RedditThing::TimeStampConverter},
    subreddit_name_prefixed: String,
    controversiality: Int64,
    depth: Int64,
    #mod_reports:
    #num_reports:
    distinguished: String? #probably?
  )

  def replies_no_bullshit(client) : Array(Comment)
    res = [] of Comment
    return res if @replies.size == 0
    if @replies.size == 1 && (m = @replies.first).is_a? MoreReddit
      resp = client.get_params("/comments/#{link_id.split("_").last}", comment: @id)
      pull = JSON::PullParser.new(resp.body)
      pull.read_begin_array
      pull.skip
      #RedditThing::AssertTypeConverter(Listing).from_json(pull).each do
      pull.on_key("data") do
        pull.on_key("children") do
          pull.read_array do
            res << AssertTypeConverter(Comment).from_json(pull)
          end
        end
      end
      pull.read_end_array
    else
      @replies.each do |r|
        if r.is_a? Comment
          res << r
        else
          raise "not implemented"
        end
      end
    end
    return res
  end
end

class Post < RedditThing
  JSON.mapping(
    domain: String,
    #approved_at_utc: {type: Time, converter: RedditThing::TimeStampConverter},
    #distinguished:
    #banned_by:
    #media_embed:
    subreddit: String,
    selftext_html: String?,
    selftext: String,
    likes: Int64?,
    #suggested_sort:
    #user_reports
    #secure_media
    saved: Bool,
    created_utc: {type: Time, converter: RedditThing::TimeStampConverter},
    id: String
    #TODO
  )
end
    
    
class AuthData
  JSON.mapping(
    user_agent: String,
    client_id: String,
    secret: String,
    username: String,
    password: String
  )

  #property user_agent, client_id, secret, username, password
end

class RedditClient < HTTP::Client
  @default_params : Hash(Symbol, String) = {} of Symbol => String

  property default_params

  def get_params(path, **kwargs)
    return self.get_params(path, kwargs.to_h)
  end
  
  def get_params(path, params : Hash(String|Symbol, String))
    params = @default_params.merge(params)
    p = HTTP::Params.build do |f|
      params.each do |key,val|
        f.add key.to_s, val
      end
    end
    raise ArgumentError.new() if path.includes? '?'
    return self.get(path+"?"+p.to_s)
  end
end

#File.open("example-body-beautiful.json", "r") do |fh|
#  pull = JSON::PullParser.new(fh)
#  pull.read_begin_array
#  pull.skip
#  res = RedditThing.from_json(pull)
#  pull.read_end_array
#  p res
#end

#exit

def read_thing(pull : JSON::PullParser)
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

def read_thing(resp : (String | IO))
  pull = JSON::PullParser.new(resp)
  read_thing(pull)
end

def read_thing(resp : HTTP::Client::Response)
  body = resp.body? || resp.body_io
  read_thing(body)
end

STDERR.puts "reading authdata"
authdata = AuthData.from_json(File.read("auth_data.json"))

STDERR.puts "reading last comment id"
last_comment_id = File.read("last_comment.txt").strip

client = RedditClient.new("www.reddit.com", tls: true)

client.before_request do |req|
  req.headers["User-Agent"] = authdata.user_agent
end

client.basic_auth(username: authdata.client_id, password: authdata.secret)

STDERR.puts "requesting access"
resp = client.post_form(
  "/api/v1/access_token",
  {
    grant_type: "password",
    username: authdata.username,
    password: authdata.password
  }
)

auth_resp = JSON.parse(resp.body).as_h

if auth_resp.has_key?("error")
  die "Failed to authenticate, reddit gave error #{auth_resp["error"].inspect}"
end

#p auth_resp

access_token : String = auth_resp["access_token"].as(String)

client = RedditClient.new("oauth.reddit.com", tls: true)

client.before_request do |req|
  sleep 1 #easiest way to never exceed ratelimit restrictions
  req.headers["User-Agent"] = authdata.user_agent
  #            Authorization
  req.headers["Authorization"] = "Bearer #{access_token}"
  #p req
end

client.default_params = {:api_type => "json", :raw_json => "1"}

resp = client.get_params(
  "/comments/6vy17t", #/r/AskReddit
  comment: last_comment_id #"dm6nvsq" #"dm6a42m"
)

#resp = client.get("/top")

#p resp

#print resp.body

#respj = JSON.parse(resp.body)

#comments = respj.as_a[1]

#threads = [] of String

comments = [] of Comment

pull = JSON::PullParser.new(resp.body? || resp.body_io)
pull.read_begin_array
pull.skip
read_thing(pull).as(Listing).each do |red_obj|
  if red_obj.is_a? Comment
    comments << red_obj
  else
    raise "unexpected"
  end
end
pull.read_end_array

p comments

def recurse(client, coms)
  com = coms.last
  puts "#{com.id}: #{com.body.inspect}"
  repls = com.replies_no_bullshit(client)
  return coms if repls.empty?
  coms << repls.first
  coms.shift if coms.size > 5
  return recurse(client, coms)
end

last_comments = recurse(client, comments)

File.write("last_comment.txt", last_comments.first.id)

# Post to edit: https://www.reddit.com/r/AskReddit/comments/6vy17t/what_was_hugely_hyped_up_but_flopped/dm689wn/

post_text = "[Click here to skip to post ##{last_comments.first.body.to_i(strict: false)}.](https://www.reddit.com/r/AskReddit/comments/6vy17t/what_was_hugely_hyped_up_but_flopped/#{last_comments.first.id}/?context=100)

This post (hopefully) updates every minute.

---
I am a bot. Contact /u/shelvac2 with any questions/comments/concerns/concerts/erotic fantasies. [Source](https://github.com/shelvacu/reddit-thread-follower-bot)."

puts post_text

puts client.post_form("/api/editusertext", {"api_type" => "json", "raw_json" => "1", "thing_id" => "t1_dm689wn", "text" => post_text})
