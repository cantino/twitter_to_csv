# Twitter To CSV

A tool for exporting the Twitter stream into a CSV file.

        (sudo) gem install twitter_to_csv

## Usage

You might start by first running the script for a while to dump the Twitter stream into a JSON file:

        twitter_to_csv --username <your twitter username> --password <your twitter password> \
                       --json out.json --filter your,keywords,of,interest

Then, later, you could export to CSV:

        twitter_to_csv --replay-from-file out.json --csv out.csv \
                       --fields text,created_at,user.name,retweeted_status.id,retweeted_status.favorited,...

Alternatively, you can always stream directly to CSV:

        twitter_to_csv --username <your twitter username> --password <your twitter password> \
                       --filter your,keywords,of,interest --csv out.csv \
                       --fields text,created_at,user.name,retweeted_status.id,retweeted_status.favorited,...

## Requiring English

You may want to limit to Tweets that appear to be writen in English.

        twitter_to_csv --username <your twitter username> --password <your twitter password> \
                       --require-english --fields ...

This filter isn't perfect and will have both false positives and false negatives, but it works pretty well.

## URLS

You can extract URLs from the tweet into their own columns by including `--url-columns 3`, for example, to get up to 3 extracted URLs in their own columns.

## Field names

Use `--sample-fields 1000`` to output the occurrence count of different Twitter fields, like so:

        twitter_to_csv --username <your twitter username> --password <your twitter password> --sample-fields 1000

Here's a partial list:

        in_reply_to_screen_name
        favorited
        text
        entities.urls
        entities.user_mentions
        entities.hashtags
        in_reply_to_user_id
        contributors
        place
        coordinates
        source
        geo
        retweeted
        retweet_count
        in_reply_to_status_id
        in_reply_to_status_id_str
        id_str
        user.default_profile_image
        user.verified
        user.notifications
        user.profile_sidebar_border_color
        user.screen_name
        user.lang
        user.favourites_count
        user.contributors_enabled
        user.profile_use_background_image
        user.friends_count
        user.location
        user.profile_text_color
        user.followers_count
        user.profile_image_url
        user.description
        user.statuses_count
        user.following
        user.profile_background_image_url
        user.show_all_inline_media
        user.listed_count
        user.profile_link_color
        user.is_translator
        user.default_profile
        user.time_zone
        user.profile_background_color
        user.protected
        user.id_str
        user.geo_enabled
        user.profile_background_tile
        user.name
        user.profile_background_image_url_https
        user.created_at
        user.profile_sidebar_fill_color
        user.id
        user.follow_request_sent
        user.utc_offset
        user.url
        user.profile_image_url_https
        truncated
        id
        created_at
        in_reply_to_user_id_str
        retweeted_status.in_reply_to_screen_name
        retweeted_status.favorited
        retweeted_status.text
        retweeted_status.entities.urls
        retweeted_status.entities.user_mentions
        retweeted_status.entities.hashtags
        retweeted_status.in_reply_to_user_id
        retweeted_status.contributors
        retweeted_status.place
        retweeted_status.coordinates
        retweeted_status.source
        retweeted_status.geo
        retweeted_status.retweeted
        retweeted_status.retweet_count
        retweeted_status.in_reply_to_status_id
        retweeted_status.in_reply_to_status_id_str
        retweeted_status.id_str
        retweeted_status.user.default_profile_image
        retweeted_status.user.verified
        retweeted_status.user.notifications
        retweeted_status.user.profile_sidebar_border_color
        retweeted_status.user.screen_name
        retweeted_status.user.lang
        retweeted_status.user.favourites_count
        retweeted_status.user.contributors_enabled
        retweeted_status.user.profile_use_background_image
        retweeted_status.user.friends_count
        retweeted_status.user.location
        retweeted_status.user.profile_text_color
        retweeted_status.user.followers_count
        retweeted_status.user.profile_image_url
        retweeted_status.user.description
        retweeted_status.user.statuses_count
        retweeted_status.user.following
        retweeted_status.user.profile_background_image_url
        retweeted_status.user.show_all_inline_media
        retweeted_status.user.listed_count
        retweeted_status.user.profile_link_color
        retweeted_status.user.is_translator
        retweeted_status.user.default_profile
        retweeted_status.user.time_zone
        retweeted_status.user.profile_background_color
        retweeted_status.user.protected
        retweeted_status.user.id_str
        retweeted_status.user.geo_enabled
        retweeted_status.user.profile_background_tile
        retweeted_status.user.name
        retweeted_status.user.profile_background_image_url_https
        retweeted_status.user.created_at
        retweeted_status.user.profile_sidebar_fill_color
        retweeted_status.user.id
        retweeted_status.user.follow_request_sent
        retweeted_status.user.utc_offset
        retweeted_status.user.url
        retweeted_status.user.profile_image_url_https
        retweeted_status.truncated
        retweeted_status.id
        retweeted_status.created_at
        retweeted_status.in_reply_to_user_id_str
        possibly_sensitive
        possibly_sensitive_editable
        retweeted_status.possibly_sensitive
        retweeted_status.possibly_sensitive_editable
        place.country_code
        place.place_type
        place.country
        place.bounding_box.type
        place.bounding_box.coordinates
        place.full_name
        place.name
        place.id
        place.url
        coordinates.type
        coordinates.coordinates
        geo.type
        geo.coordinates
        retweeted_status.entities.media
        entities.media
