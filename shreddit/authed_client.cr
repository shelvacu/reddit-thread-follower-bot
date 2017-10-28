module Shreddit
  class AuthedClient
    def initialize(@bearer_token : String, @user_agent : String)
      @client = HTTP::Client.new("oauth.reddit.com", tls: true)
      @default_params = {"api_type" => "json", "raw_json" => "1"}
      @client.before_request do |req|
        req.headers["User-Agent"] = @user_agent
        req.headers["Authorization"] = "Bearer #{@bearer_token}"
      end
      @last_ratelimit_info = {used: 0.0, remaining: 100000.0, reset: -1.0, rcvd_at: Time.now}
    end

    def time_to_wait
      l = @last_ratelimit_info
      return 0 if l[:remaining] > 0
      resets_at = l[:rcvd_at] + Time::Span.new(0,0,l[:reset])
      resets_in = Time.now - resets_at
      return 0 if resets_in.seconds <= 0
      return resets_in.seconds
    end
    
    def wait_for_rate #TODO: This needs a better name
      #TODO: This won't work correctly if multiple fibers are in play
      while (ttw = self.time_to_wait) > 0
        sleep ttw + 0.1
      end
    end

    def handle_res(res)
      rcvd_at = Time.now
      if {"X-Ratelimit-Used","X-Ratelimit-Remaining","X-Ratelimit-Reset"}.all?{|s| res.headers.has_key? s}
        @last_ratelimit_info = {
          used: res.headers["X-Ratelimit-Used"].to_f,
          remaining: res.headers["X-Ratelimit-Remaining"].to_f,
          reset: res.headers["X-Ratelimit-Reset"].to_f,
          rcvd_at: rcvd_at
        }
      else
        puts "no ratelimit headers"
        p res.status_code
        p res.headers
      end
      if res.success?
        puts res.body?
        return res.body? || ""
      else
        raise "TODO: Deal with this"
      end
    end

    def get(path, params : Hash(String, String))
      raise ArgumentError.new("path must not include parameters already") if path.includes? '?'
      params = @default_params.merge(params)
      p = HTTP::Params.build do |f|
        params.each do |key,val|
          f.add key.to_s, val
        end
      end
      wait_for_rate
      fullpath = path+"?"+p.to_s
      puts fullpath
      http_res = @client.get(fullpath)
      return handle_res(http_res)
    end

    def post(path, params : Hash(String, String))
      params = @default_params.merge(params)
      wait_for_rate
      http_res = @client.post_form(path, params)
      return handle_res(http_res)
    end
    
    # https://www.reddit.com/dev/api#GET_comments_{article}
    def get_comments(article, subreddit = nil, params = {} of String => String)
      if !subreddit.nil?
        str = "/r/#{subreddit}"
      else
        str = ""
      end
      resp = self.get(str+"/comments/#{article}", params)
      pull = JSON::PullParser.new(resp)
      pull.read_begin_array
      subreddit = Shreddit.read_thing(pull).as(Subreddit)
      comments = [] of Comment
      Shreddit.read_thing(pull).as(Listing).each do |red_obj|
        if red_obj.is_a? Comment
          comments << red_obj
        else
          raise "unexpected"
        end
      end
      pull.read_end_array

      return {subreddit: subreddit, comments: comments}
    end
  end
end
