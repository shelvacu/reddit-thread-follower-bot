require "json"
require "http/client"
require "oauth"

require "./shreddit"

def die(msg)
  STDERR.puts msg
  exit 1
end

class AuthData
  JSON.mapping(
    user_agent: String,
    client_id: String,
    secret: String,
    username: String,
    password: String
  )
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

comments = [] of Shreddit::Comment

pull = JSON::PullParser.new(resp.body? || resp.body_io)
pull.read_begin_array
pull.skip
Shreddit.read_thing(pull).as(Shreddit::Listing).each do |red_obj|
  if red_obj.is_a? Shreddit::Comment
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
I am a bot. Contact /u/shelvac2 with any questions/comments/concerns/concerts/erotic fantasies."

puts post_text

puts client.post_form("/api/editusertext", {"thing_id" => "t1_dm689wn", "text" => post_text})
