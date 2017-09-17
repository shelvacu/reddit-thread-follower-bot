module Shreddit
  class Subreddit < RedditThing
    JSON.mapping(
      accounts_active: Int64,
      comment_score_hide_mins: Int64,
      description: String,
      description_html: String,
      display_name: String,
      header_img: String?,
      header_size: Array(Int64), #todo: make this a tuple, possibly named
      over18: Bool,
      public_description: String,
      public_traffic: Bool,
      subscribers: Int64,
      submission_type: String, # according to reddit this should be: one of "any", "link" or "self"
      submit_link_label: String,
      submit_text_label: String,
      subreddit_type: String,
      title: String,
      url: String,
      user_is_banned: Bool,
      user_is_contributor: Bool,
      user_is_moderator: Bool,
      user_is_subscriber: Bool
    )

    def over_18
      over18
    end
  end
end
