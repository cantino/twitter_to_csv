# Twitter To CSV

[![Build Status](https://travis-ci.org/cantino/twitter_to_csv.png)](https://travis-ci.org/cantino/twitter_to_csv)

A tool for exporting the Twitter stream into a CSV file.

    (sudo) gem install twitter_to_csv

## Usage

### Quick Example

You might start by first running the script for a while to dump the Twitter stream into a JSON file:

    twitter_to_csv --api-key <your twitter api key> --api-secret <your twitter api secret> \
                   --access-token <your twitter access token> --access-token-secret <your twitter access token secret> \
                   --json out.json --filter your,keywords,of,interest

Then, later, you could export to CSV:

    twitter_to_csv --replay-from-file out.json --csv out.csv \
                   --fields text,created_at,user.name,retweeted_status.id,retweeted_status.favorited,...

Alternatively, you can always stream directly to CSV:

    twitter_to_csv --api-key <your twitter api key> --api-secret <your twitter api secret> \
                   --access-token <your twitter access token> --access-token-secret <your twitter access token secret> \
                   --filter your,keywords,of,interest --csv out.csv \
                   --fields text,created_at,user.name,retweeted_status.id,retweeted_status.favorited,...

### Getting your Twitter API Key and Token

Twitter requires all API access over oAuth. Follow these instructions to get register and authorize a free Twitter API Application:

 * Visit https://apps.twitter.com/app/new
 * Enter something like "my twitter\_to\_csv" as the name, "Using twitter_to_csv Ruby gem" as the description, and "https://github.com/cantino/twitter_to_csv" as the website.
 * Click "manage API keys"
 * Copy down the "API key" and "API secret"
 * Click "Create my access token" at the bottom of the page, refreshing until your new access token shows up at the bottom of the page.  Copy down your "Access token" and "Access token secret".
 * You're all set!

## Requiring English

You may want to limit to Tweets that appear to be written in English.

    twitter_to_csv --api-key <your twitter api key> --api-secret <your twitter api secret> \
                   --access-token <your twitter access token> --access-token-secret <your twitter access token secret> \
                   --require-english --fields ...

This filter isn't perfect and will have both false positives and false negatives, but it works fairly well.

## URLS, Hashtags, and User Mentions

You can extract URLs, Hashtags, and User Mentions from the tweet into their own columns by using `--url-columns`, `--hashtag-columns`, and `--user-mention-columns`.  For example, you could use `--url-columns 3` to get up to 3 extracted URLs in their own columns.

## Sentiment Tagging

Twitter To CSV can compute an average sentiment score for each tweet.  Provide `--compute-sentiment` to use this feature. The [AFINN-111](http://fnielsen.posterous.com/old-anew-a-sentiment-about-sentiment-analysis) valence database is used to look up the valence of each recognized word, then the average is computed, only considering words that have some known valence associated.  That is, "I love cheese" only has one word with valence, "love" with a score of 3, so the average is 3.  "I love cheese and like bread", on the other hand, has two words with valence, "love" (3) and "like" (2), and so has an average valence of (3 + 2) / 2, or 2.5.  The library will break hyphenated words up and score them as separate words unless the whole thing has a single known valence.

## Handling of Retweets

Once you have a recorded Twitter stream, you can rollup retweets in various ways.  Here is an example that collapses retweets into the `retweet_count` field of the original tweet, only outputs tweets with at least 1 retweet, ignores retweets that happened more than 7 days after the original tweet, and outputs retweet count columns at half an hour, 2 hours, and 2 days after the original tweet:

    twitter_to_csv --replay-from-file out.json -c out.csv \
                   --retweet-mode rollup \
                   --retweet-threshold 1 \
                   --retweet-window 7 \
                   --retweet-counts-at 0.5,2,48 \
                   --fields retweet_count,text

*Note* that all of the retweet features require you to `--replay-from-file` because they parse the stream backwards.  They WILL NOT function correctly when you're reading directly from the stream .

## Selecting Windows

To select a specific window of time in a pre-recorded stream by `created_at`, pass in `--start` and `--end`, for example:

    twitter_to_csv --replay-from-file out.json \
                   --start "Mon Mar 07 07:42:22 +0000 2011" \
                   --end "Mon Mar 08 07:42:22 +0000 2011" \
                   ...

## Mind the Gap

Sometimes the Twitter API goes down.  You can analyze a json output file to see where data gaps (of over 10 minutes, in this case) have occurred:

    twitter_to_csv --replay-from-file out.json --analyze-gaps 10

## Creating Dynamic Binary Fields

If you're doing research on Twitter, it may make sense to construct composite binary variables predicated on the existence of certain tokens in a tweet.  For example, you may want
a variable called _sf_ that is true if the tweet contains _san francisco_ OR _sf_ OR _bay area_ (but not _area by the bay_).  You could do that as follows:

    twitter_to_csv --replay-from-file out.json \
                   --csv out.csv \
                   -w "sf: san francisco OR sf OR bay area" \

If you did want to allow _area by the bay_, you might need something like:

                   -w "sf: san francisco OR sf OR (bay AND area)"

## Other Options

Use `twitter_to_csv --help` to see all available options:

    Usage: twitter_to_csv [options]
    
    These four fields are required.  Please see the README to learn how to get them for your Twitter account.
            --api-key KEY                Twitter API key
            --api-secret SECRET          Twitter API secret
            --access-token TOKEN         Twitter access token
            --access-token-secret SECRET Twitter access token secret
    
    General settings:
        -c, --csv FILE                   The CSV file to append to, or - for STDOUT
        -j, --json FILE                  The JSON file to append to, or - for STDOUT
        -f, --filter KEYWORDS            Keywords to ask Twitter to filter on
        -x, --fields FIELDS              Fields to include in the CSV
            --date-fields FIELD_NAMES    Break these fields into separate numerical columns for weekday, day, month, your, hour, minute, and second.
        -e, --require-english [STRATEGY] Attempt to filter out non-English tweets. This will have both false positives and false negatives.
                                         The strategy can be either 'uld' to use the UnsupervisedLanguageDetection Ruby gem,
                                         'lang' to use Twitter's guessed 'lang' attribute, or 'both' to only remove tweets that
                                         both Twitter and ULD think are non-English.  This is most conservative and is the default.
        -v, --[no-]verbose               Run verbosely
        -r, --replay-from-file FILENAME  Replay tweets from a JSON dump file
            --analyze-gaps MINUTES       Look at the stream and display gap information for gaps longer than MINUTES
            --sample-fields NUMBER_OF_SAMPLES
                                         Record NUMBER_OF_SAMPLES tweets and then print out all
                                         of the field names seen.  Use to find out what can be passed to.
            --url-columns NUM_COLUMNS    Extract up to NUM_COLUMNS urls from the status and include them in the CSV
            --hash-columns NUM_COLUMNS   Extract up to NUM_COLUMNS hashtags (#foo) from the status and include them in the CSV
            --user-columns NUM_COLUMNS   Extract up to NUM_COLUMNS user mentions (@foo) from the status and include them in the CSV
        -s, --compute-sentiment          Compute an average sentiment score for each status using the AFINN-111 sentiment dictionary
            --compute-word-count         Include a word count for each status in the output CSV
            --normalize-source           Return just the domain name from the Tweet source (i.e., tweetdeck, facebook)
            --remove-quotes              This option strips all double quotes from the output to help some CSV parsers.
            --prefix-ids                 Prefix any field ending in _id or _id_str with 'id' to force parsing as a string in some programs.
        -w "NAME:WORD AND WORD AND WORD",
            --bool-word-field            Create a named CSV column that is true when the word expression matches, false otherwise.
                                         Word expressions are boolean expressions where neighboring words must occur sequentially
                                         and you can use parentheses, AND, and OR to test for occurrence relationships.  Examples:
                                           keyword_any:tanning booth OR tanning booths OR tanningbooth
                                           keyword_both:tanning AND booth
                                           keyword_complex:tanning AND (booth OR bed)
                                         This option can be used multiple times.
            --start TIME                 Ignore tweets with a created_at earlier than TIME
            --end TIME                   Ignore tweets with a created_at later than TIME
    
    If you would like to do special retweet handling, use the following options.
    For these to function, you must be using --replay-from-file.  The replay will be performed in reverse.
            --retweet-mode MODE          Determine how to handle retweets
                                         Options are just 'ROLLUP'
            --retweet-threshold COUNT    Only consider statuses with at least COUNT retweets
            --retweet-window WINDOW      Ignore retweets that occur beyond WINDOW days
                                         Additionally, statuses where WINDOW days have not yet passed will be ignored.
            --retweet-counts-at HOURS    Output the number of retweets seen at specific times after the original tweet
        -h, --help                       Show this message
            --version                    Show version

## Field names

Use `--sample-fields 1000` to output the occurrence count of different Twitter fields, like so:

    twitter_to_csv --api-key <your twitter api key> --api-secret <your twitter api secret> \
                   --access-token <your twitter access token> --access-token-secret <your twitter access token secret> \
                   --sample-fields 1000

Here's a list of fields and their occurrences in a 50,000 tweet dataset:

    id                                                            50000
    id_str                                                        50000
    created_at                                                    50000
    text                                                          50000
    source                                                        50000
    truncated                                                     50000
    in_reply_to_status_id                                         50000
    in_reply_to_status_id_str                                     50000
    in_reply_to_user_id                                           50000
    in_reply_to_user_id_str                                       50000
    in_reply_to_screen_name                                       50000
    user.id                                                       50000
    user.id_str                                                   50000
    user.name                                                     50000
    user.screen_name                                              50000
    user.location                                                 50000
    user.url                                                      50000
    user.description                                              50000
    user.protected                                                50000
    user.followers_count                                          50000
    user.friends_count                                            50000
    user.listed_count                                             50000
    user.created_at                                               50000
    user.favourites_count                                         50000
    user.utc_offset                                               50000
    user.time_zone                                                50000
    user.geo_enabled                                              50000
    user.verified                                                 50000
    user.statuses_count                                           50000
    user.lang                                                     50000
    user.contributors_enabled                                     50000
    user.is_translator                                            50000
    user.profile_background_color                                 50000
    user.profile_background_image_url                             50000
    user.profile_background_image_url_https                       50000
    user.profile_background_tile                                  50000
    user.profile_image_url                                        50000
    user.profile_image_url_https                                  50000
    user.profile_banner_url                                       41614
    user.profile_link_color                                       50000
    user.profile_sidebar_border_color                             50000
    user.profile_sidebar_fill_color                               50000
    user.profile_text_color                                       50000
    user.profile_use_background_image                             50000
    user.default_profile                                          50000
    user.default_profile_image                                    50000
    user.following                                                50000
    user.follow_request_sent                                      50000
    user.notifications                                            50000
    geo                                                           48656
    coordinates                                                   48656
    place                                                         48664
    contributors                                                  50000
    retweet_count                                                 50000
    favorite_count                                                50000
    favorited                                                     50000
    retweeted                                                     50000
    filter_level                                                  50000
    lang                                                          36041
    entities.hashtags[].text                                      11024
    entities.hashtags[].indices[]                                 11024
    entities.user_mentions[].screen_name                          22368
    entities.user_mentions[].name                                 22368
    entities.user_mentions[].id                                   22368
    entities.user_mentions[].id_str                               22368
    entities.user_mentions[].indices[]                            22368
    retweeted_status.created_at                                   13959
    retweeted_status.id                                           13959
    retweeted_status.id_str                                       13959
    retweeted_status.text                                         13959
    retweeted_status.source                                       13959
    retweeted_status.truncated                                    13959
    retweeted_status.in_reply_to_status_id                        13959
    retweeted_status.in_reply_to_status_id_str                    13959
    retweeted_status.in_reply_to_user_id                          13959
    retweeted_status.in_reply_to_user_id_str                      13959
    retweeted_status.in_reply_to_screen_name                      13959
    retweeted_status.user.id                                      13959
    retweeted_status.user.id_str                                  13959
    retweeted_status.user.name                                    13959
    retweeted_status.user.screen_name                             13959
    retweeted_status.user.location                                13959
    retweeted_status.user.url                                     13959
    retweeted_status.user.description                             13959
    retweeted_status.user.protected                               13959
    retweeted_status.user.followers_count                         13959
    retweeted_status.user.friends_count                           13959
    retweeted_status.user.listed_count                            13959
    retweeted_status.user.created_at                              13959
    retweeted_status.user.favourites_count                        13959
    retweeted_status.user.utc_offset                              13959
    retweeted_status.user.time_zone                               13959
    retweeted_status.user.geo_enabled                             13959
    retweeted_status.user.verified                                13959
    retweeted_status.user.statuses_count                          13959
    retweeted_status.user.lang                                    13959
    retweeted_status.user.contributors_enabled                    13959
    retweeted_status.user.is_translator                           13959
    retweeted_status.user.profile_background_color                13959
    retweeted_status.user.profile_background_image_url            13959
    retweeted_status.user.profile_background_image_url_https      13959
    retweeted_status.user.profile_background_tile                 13959
    retweeted_status.user.profile_image_url                       13959
    retweeted_status.user.profile_image_url_https                 13959
    retweeted_status.user.profile_banner_url                      11028
    retweeted_status.user.profile_link_color                      13959
    retweeted_status.user.profile_sidebar_border_color            13959
    retweeted_status.user.profile_sidebar_fill_color              13959
    retweeted_status.user.profile_text_color                      13959
    retweeted_status.user.profile_use_background_image            13959
    retweeted_status.user.default_profile                         13959
    retweeted_status.user.default_profile_image                   13959
    retweeted_status.user.following                               13959
    retweeted_status.user.follow_request_sent                     13959
    retweeted_status.user.notifications                           13959
    retweeted_status.geo                                          13728
    retweeted_status.coordinates                                  13728
    retweeted_status.place                                        13724
    retweeted_status.contributors                                 13959
    retweeted_status.retweet_count                                13959
    retweeted_status.favorite_count                               13959
    retweeted_status.entities.hashtags[].text                     2438
    retweeted_status.entities.hashtags[].indices[]                2438
    retweeted_status.entities.urls[].url                          361
    retweeted_status.entities.urls[].expanded_url                 361
    retweeted_status.entities.urls[].display_url                  361
    retweeted_status.entities.urls[].indices[]                    361
    retweeted_status.favorited                                    13959
    retweeted_status.retweeted                                    13959
    retweeted_status.possibly_sensitive                           916
    retweeted_status.lang                                         13959
    entities.urls[].url                                           3662
    entities.urls[].expanded_url                                  3662
    entities.urls[].display_url                                   3662
    entities.urls[].indices[]                                     3662
    possibly_sensitive                                            5339
    entities.media[].id                                           1736
    entities.media[].id_str                                       1736
    entities.media[].indices[]                                    1736
    entities.media[].media_url                                    1736
    entities.media[].media_url_https                              1736
    entities.media[].url                                          1736
    entities.media[].display_url                                  1736
    entities.media[].expanded_url                                 1736
    entities.media[].type                                         1736
    entities.media[].sizes.thumb.w                                1736
    entities.media[].sizes.thumb.h                                1736
    entities.media[].sizes.thumb.resize                           1736
    entities.media[].sizes.large.w                                1736
    entities.media[].sizes.large.h                                1736
    entities.media[].sizes.large.resize                           1736
    entities.media[].sizes.small.w                                1736
    entities.media[].sizes.small.h                                1736
    entities.media[].sizes.small.resize                           1736
    entities.media[].sizes.medium.w                               1736
    entities.media[].sizes.medium.h                               1736
    entities.media[].sizes.medium.resize                          1736
    geo.type                                                      1344
    geo.coordinates[]                                             1344
    coordinates.type                                              1344
    coordinates.coordinates[]                                     1344
    place.id                                                      1336
    place.url                                                     1336
    place.place_type                                              1336
    place.name                                                    1336
    place.full_name                                               1336
    place.country_code                                            1336
    place.country                                                 1336
    place.bounding_box.type                                       1336
    place.bounding_box.coordinates[][][]                          1336
    entities.media[].source_status_id                             621
    entities.media[].source_status_id_str                         621
    retweeted_status.entities.user_mentions[].screen_name         1379
    retweeted_status.entities.user_mentions[].name                1379
    retweeted_status.entities.user_mentions[].id                  1379
    retweeted_status.entities.user_mentions[].id_str              1379
    retweeted_status.entities.user_mentions[].indices[]           1379
    retweeted_status.entities.media[].id                          609
    retweeted_status.entities.media[].id_str                      609
    retweeted_status.entities.media[].indices[]                   609
    retweeted_status.entities.media[].media_url                   609
    retweeted_status.entities.media[].media_url_https             609
    retweeted_status.entities.media[].url                         609
    retweeted_status.entities.media[].display_url                 609
    retweeted_status.entities.media[].expanded_url                609
    retweeted_status.entities.media[].type                        609
    retweeted_status.entities.media[].sizes.thumb.w               609
    retweeted_status.entities.media[].sizes.thumb.h               609
    retweeted_status.entities.media[].sizes.thumb.resize          609
    retweeted_status.entities.media[].sizes.medium.w              609
    retweeted_status.entities.media[].sizes.medium.h              609
    retweeted_status.entities.media[].sizes.medium.resize         609
    retweeted_status.entities.media[].sizes.large.w               609
    retweeted_status.entities.media[].sizes.large.h               609
    retweeted_status.entities.media[].sizes.large.resize          609
    retweeted_status.entities.media[].sizes.small.w               609
    retweeted_status.entities.media[].sizes.small.h               609
    retweeted_status.entities.media[].sizes.small.resize          609
    retweeted_status.place.id                                     235
    retweeted_status.place.url                                    235
    retweeted_status.place.place_type                             235
    retweeted_status.place.name                                   235
    retweeted_status.place.full_name                              235
    retweeted_status.place.country_code                           235
    retweeted_status.place.country                                235
    retweeted_status.place.bounding_box.type                      235
    retweeted_status.place.bounding_box.coordinates[][][]         235
    retweeted_status.geo.type                                     231
    retweeted_status.geo.coordinates[]                            231
    retweeted_status.coordinates.type                             231
    retweeted_status.coordinates.coordinates[]                    231
    retweeted_status.entities.media[].source_status_id            42
    retweeted_status.entities.media[].source_status_id_str        42
    place.attributes.street_address                               2

