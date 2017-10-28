module Shreddit
  abstract class Thing
  end

  module ListingHack
  end

  class Listing < Array(Thing | ListingHack)
    include ListingHack
  end

  alias RedditObject = (Thing | ListingHack)
end
