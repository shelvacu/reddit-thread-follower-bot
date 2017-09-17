require "./thing"
require "./converters"

module Shreddit
  class Link < RedditThing
    JSON.mapping(
      ups: Int64,
      downs: In64, #(always zero)
      likes: Bool?,
      
      created_utc: {type: Time, converter: TimeStampConverter},

      author: String,
      author_flair_css_class: String,
      author_flair_text: String,
      clicked: Bool, #From reddit docs: "probably always returns false"
      domain: String,
      hidden: Bool,
      is_self: Bool,
      link_flair_css_class: String,
      link_flair_text: String,
      locked: Bool,
      #media: TODO
      #media_embed: TODO
      num_comments: Int64,
      over_18: Bool,
      permalink: String,
      saved: Bool,
      #score
      selftext: String,
      selftext_html: String?,
      subreddit: String,
      subreddit_id: String,
      thumbnail: String,
      title: String,
      url: String,
      edited: {type: Bool | Time, converter: BoolOrTimeStampConverter}
    )

    def over18
      over_18
    end
  end
end
