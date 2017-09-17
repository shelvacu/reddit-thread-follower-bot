module Shreddit
  abstract class RedditThing
  end

  module ListingHack
  end

  class Listing < Array(RedditThing | ListingHack)
    include ListingHack
  end

  alias RedditObject = (RedditThing | Listing)
end
