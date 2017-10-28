require "./thing"

module Shreddit
  class More < Thing
    JSON.mapping(
      count: Int64,
      name: String,
      id: String,
      parent_id: String, #not documented in reddit's api, still needed sometimes
      depth: Int64,
      children: Array(String)#{type: Array(RedditThing), converter: ArrayConverter}
    )
  end
end
