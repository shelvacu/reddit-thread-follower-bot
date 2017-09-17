module Shreddit
  class Account < RedditThing
    JSON.mapping(
      id: String,

      comment_karma: Int64,
      has_mail: Bool?,
      has_mod_mail: Bool?,
      has_verified_email: Bool,
      inbox_count: Int64?,
      is_friend: Bool,
      is_gold: Bool,
      is_mod: Bool,
      link_karma: Int64,
      modhash: String?,
      name: String,
      over_18: Bool
    )

    def fullname
      return "t2_" + self.id
    end
  end
end
