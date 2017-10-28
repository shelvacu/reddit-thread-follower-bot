module Shreddit
  class Message < Thing
    JSON.mapping(
      created_utc: {type: Time, converter: TimeStampConverter},
      
      author: String,
      body: String,
      body_html: String,
      context: String,
      first_message: String,
      first_message_name: String,
      likes: Bool?,
      link_title: String?,
      name: String,
      new: Bool,
      parent_id: String?,
      #replies:
      subject: String,
      subreddit: String?,
      was_comment: Bool
    )
  end
end
