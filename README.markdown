# Twitter To CSV

## Usage

      twitter_to_csv --username <your twitter username> --password <your twitter password> \
                     --json hi.json --filter zit,zits,pimple,pimples,acne \
                     --csv out.csv --fields text,
                     --fields text,retweeted_status.id,retweeted_status.favorited,...
                     
Use `--sample-fields 1000`` to output the occurrence count of different Twitter fields.

You can also `--replay-from-file` if you have a JSON output file and you want to run it back through the exporter.