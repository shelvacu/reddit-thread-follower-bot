module Shreddit
  class Comment < Thing
    JSON.mapping(
      id: String,
      name: String,

      # voteable
      ups: Int64,
      downs: Int64, #always zero
      likes: Bool?,

      # created
      #created: Float64,
      created_utc: {type: Time, converter: TimeStampConverter},

      approved_by: String?,
      author: String,
      author_flair_css_class: String,
      author_flair_text: String,
      banned_by: String,
      body: String,
      body_html: String,
      edited: {type: Bool | Time, converter: BoolOrTimeStampConverter},
      gilded: Int64,
      link_author: String?,
      link_id: String,
      link_title: String?,
      link_url: String?,
      num_reports: Int64?,
      parent_id: String,
      replies: {type: Listing, converter: RepliesConverter},
      saved: Bool,
      score: Int64,
      score_hidden: Bool,
      subreddit: String,
      subreddit_id: String,
      distinguished: String?,

      #approved_at_utc: Int64?,
      #removal_reason:
      #user_reports:
      #banned_at_utc:
      #archived: Bool,
      #report_reasons:
      #can_mod_post: Bool,
      #collapsed: Bool,
      #is_submitter: Bool,
      #collapsed_reason:
      #stickied: Bool,
      #can_gild: Bool,
      #subreddit_type: String,
      #subreddit_name_prefixed: String,
      #controversiality: Int64,
      #depth: Int64,
      #mod_reports:
    )

    def replies_no_bullshit(client) : Array(Comment)
      res = [] of Comment
      return res if @replies.size == 0
      if @replies.size == 1 && (m = @replies.first).is_a? More
        #resp = client.get_params("/comments/#{link_id.split("_").last}", comment: @id)
        #pull = JSON::PullParser.new(resp.body)
        #pull.read_begin_array
        #pull.skip
        #RedditThing::AssertTypeConverter(Listing).from_json(pull).each do
        #pull.on_key("data") do
        #  pull.on_key("children") do
        #    pull.read_array do
        #      res << AssertTypeConverter(Comment).from_json(pull)
        #    end
        #  end
        #end
        #pull.read_end_array
        return client.get_comments(link_id.split("_").last, params: {"comment" => @id})[:comments]
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
end
