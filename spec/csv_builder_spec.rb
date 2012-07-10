# encoding: utf-8
require 'spec_helper'
require 'time'

describe TwitterToCsv::CsvBuilder do
  describe "#handle_status" do
    describe "when :english is set" do
      it "skips non-English tweets" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:require_english => true, :csv => string_io, :fields => %w[text])
        csv_builder.handle_status('text' => "This is English", 'user' =>  { 'lang' => 'en' })
        csv_builder.handle_status('text' => "Esta frase se encuentra en Ingles.", 'user' =>  { 'lang' => 'en' })
        csv_builder.handle_status('text' => "This is still English", 'user' =>  { 'lang' => 'en' })
        string_io.rewind
        string_io.read.should == "\"This is English\"\n\"This is still English\"\n"
      end

      it "honors start_time and end_time" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[text],
                                                   :start_time => Time.parse("Mon Mar 07 07:42:22 +0000 2011"),
                                                   :end_time   => Time.parse("Mon Mar 08 02:00:00 +0000 2011"))

        # Order shouldn't matter
        csv_builder.handle_status('text' => "1", 'created_at' => 'Mon Mar 07 07:41:22 +0000 2011')
        csv_builder.handle_status('text' => "6", 'created_at' => 'Mon Mar 08 02:01:00 +0000 2011')
        csv_builder.handle_status('text' => "2", 'created_at' => 'Mon Mar 07 07:42:22 +0000 2011')
        csv_builder.handle_status('text' => "4", 'created_at' => 'Mon Mar 08 01:41:22 +0000 2011')
        csv_builder.handle_status('text' => "5", 'created_at' => 'Mon Mar 08 02:00:00 +0000 2011')
        csv_builder.handle_status('text' => "3", 'created_at' => 'Mon Mar 07 10:00:00 +0000 2011')
        string_io.rewind
        string_io.read.should == "\"2\"\n\"4\"\n\"3\"\n"
      end
    end

    describe "log_csv_header" do
      it "outputs the fields as header labels" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something something_else.a])
        csv_builder.log_csv_header
        string_io.rewind
        string_io.read.should == '"something","something_else.a"' + "\n"
      end

      it "includes urls if requested" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something], :url_columns => 2)
        csv_builder.log_csv_header
        string_io.rewind
        string_io.read.should == '"something","url_1","url_2"' + "\n"
      end

      it "includes date fields if requested" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something], :date_fields => %w[created_at])
        csv_builder.log_csv_header
        string_io.rewind
        string_io.read.should == '"something","created_at_week_day","created_at_day","created_at_month","created_at_year","created_at_hour","created_at_minute","created_at_second"' + "\n"
      end

      it "includes columns for the retweet_counts_at entries, if present" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io,
                                                   :fields => %w[something],
                                                   :retweet_mode => :rollup,
                                                   :retweet_threshold => 1,
                                                   :retweet_window => 4,
                                                   :retweet_counts_at => [0.5, 24, 48])
        csv_builder.log_csv_header
        string_io.rewind
        string_io.read.should == '"something","retweets_at_0.5_hours","retweets_at_24_hours","retweets_at_48_hours"' + "\n"
      end
    end

    describe "logging to a CSV" do
      it "outputs the requested fields when specified in dot-notation" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something something_else.a something_else.c.d])
        csv_builder.handle_status({
            'something' => "hello",
            'something_else' => {
                'a' => 'b',
                'c' => {
                    'd' => "foo",
                    'e' => 'bar'
                },
                'blah' => 'hi'
            }
        })
        string_io.rewind
        string_io.read.should == "\"hello\",\"b\",\"foo\"\n"
      end

      it "can extract URLs, hashtags, and user mentions" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something], :url_columns => 2, :hashtag_columns => 2, :user_mention_columns => 1)
        csv_builder.handle_status({
            'something' => "hello1",
            "entities" => {
                "hashtags" => [
                    { "text" => "AHashTag" },
                    { "text" => "AnotherHashTag" },
                    { "text" => "AThirdHashTag" }
                ],
                "user_mentions" => [
                    { "screen_name" => "ScreenNameOne" },
                    { "screen_name" => "ScreenNameTwo" },
                    { "screen_name" => "ScreenNameThree" }
                ],
                "urls" => [
                    { "url" => "http://t.co/1231" },
                    { "url" => "http://t.co/1232", "expanded_url" => "http://a.real.url2" },
                    { "url" => "http://t.co/1233", "expanded_url" => "http://a.real.url3" }
                ]
            },
            'text' => 'some text'

        })
        csv_builder.handle_status({
            'something' => "hello2",
            "entities" => {
                "hashtags" => [],
                "user_mentions" => [],
                "urls" => []
            },
            'text' => 'this is another status'
        })
        string_io.rewind
        string_io.read.should == "\"hello1\",\"http://t.co/1231\",\"http://a.real.url2\",\"AHashTag\",\"AnotherHashTag\",\"ScreenNameOne\"\n" +
                                 "\"hello2\",\"\",\"\",\"\",\"\",\"\"\n"
      end

      it "can compute the average sentiment" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something], :compute_sentiment => true)
        csv_builder.handle_status({
            'something' => "hello1",
            'text' => 'i love cheese'

        })
        csv_builder.handle_status({
            'something' => "hello2",
            'text' => 'i love cheese and like bread'
        })
        csv_builder.handle_status({
            'something' => "hello3",
            'text' => 'some   kind of once-in-a-lifetime cool-fest in the right   direction or the right-direction or the son_of a bitch' # it tries both hyphenated and non-hyphenated, and does phrases
        })
        string_io.rewind
        string_io.read.should == "\"hello1\",\"3.0\",\"1\"\n" +
                                 "\"hello2\",\"#{(3 + 2) / 2.0}\",\"2\"\n" +
                                 "\"hello3\",\"#{(0 + 3 + 1 + 3 + 3 + -5) / 6.0}\",\"6\"\n"
      end

      it "can compute word count" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something], :compute_word_count => true)
        csv_builder.handle_status({
            'something' => "hello1",
            'text' => 'i love cheese'

        })
        csv_builder.handle_status({
            'something' => "hello2",
            'text' => 'foo_bar baz9bing'
        })
        string_io.rewind
        string_io.read.should == "\"hello1\",\"3\"\n" +
                                 "\"hello2\",\"2\"\n"
      end

      it "can return date fields" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something], :date_fields => %w[created_at])
        csv_builder.handle_status({
            'something' => "hello1",
            'text' => 'i love cheese',
            'created_at' => "2012-06-29 13:12:09 -0700"

        })
        string_io.rewind
        string_io.read.should == "\"hello1\",\"5\",\"29\",\"6\",\"2012\",\"13\",\"12\",\"09\"\n"
      end

      it "can return a normalized source" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something], :normalize_source => true)
        csv_builder.handle_status({
            'something' => "hello1",
            'text' => 'i love cheese',
            'source' => "<a href=\"http://twitter.com/download/android\" rel=\"nofollow\">Twitter for Android</a>"

        })
        string_io.rewind
        string_io.read.should == "\"hello1\",\"Twitter for Android\"\n"
      end
    end

    describe "retweet handling" do
      def play_data(builder)
        days = 60 * 60 * 24
        now = Time.now

        builder.handle_status({
            'created_at' => now,
            'retweeted_status' => {
                'id' => 3,
                'created_at' => now - 1 * days,
                'retweet_count' => 1
            },
            'text' => 'RT not enough time has passed'
        })

        builder.handle_status({
            'id' => 3,
            'created_at' => now - 1 * days,
            'text' => 'not enough time has passed',
            'retweet_count' => 0
        })

        builder.handle_status({
            'created_at' => now - 1 * days,
            'retweeted_status' => {
                'id' => 2,
                'created_at' => now - 4 * days,
                'retweet_count' => 3
            },
            'text' => 'RT 2 retweets'
        })

        builder.handle_status({
            'created_at' => now - 2 * days,
            'retweeted_status' => {
                'id' => 4,
                'created_at' => now - 5 * days,
                'retweet_count' => 1
            },
            'text' => 'RT 1 retweet'
        })

        builder.handle_status({
            'created_at' => now - 3 * days,
            'retweeted_status' => {
                'id' => 2,
                'created_at' => now - 4 * days,
                'retweet_count' => 2
            },
            'text' => 'RT 2 retweets'
        })

        builder.handle_status({
            'created_at' => now - 3.99 * days,
            'retweeted_status' => {
                'id' => 2,
                'created_at' => now - 4 * days,
                'retweet_count' => 1
            },
            'text' => 'RT 2 retweets'
        })

        builder.handle_status({
            'id' => 2,
            'created_at' => now - 4 * days,
            'text' => '2 retweets',
            'retweet_count' => 0
        })

        builder.handle_status({
            'id' => 4,
            'created_at' => now - 5 * days,
            'text' => '1 retweet',
            'retweet_count' => 0
        })

        builder.handle_status({
            'id' => 5,
            'created_at' => now - 5.1 * days,
            'text' => 'no retweets',
            'retweet_count' => 0
        })
      end

      it "skips statuses with fewer than :retweet_threshold retweets and ignores statues that haven't been seen for retweet_window yet" do
        string_io = StringIO.new
        builder = TwitterToCsv::CsvBuilder.new(:retweet_mode => :rollup,
                                               :retweet_threshold => 2,
                                               :retweet_window => 2,
                                               :csv => string_io,
                                               :fields => %w[id retweet_count])
        play_data builder
        string_io.rewind
        string_io.read.should == "\"2\",\"2\"\n"

        string_io = StringIO.new
        builder = TwitterToCsv::CsvBuilder.new(:retweet_mode => :rollup,
                                               :retweet_threshold => 1,
                                               :retweet_window => 3,
                                               :csv => string_io,
                                               :fields => %w[id retweet_count])
        play_data builder
        string_io.rewind
        string_io.read.should == "\"2\",\"3\"\n" + "\"4\",\"1\"\n"

        string_io = StringIO.new
        builder = TwitterToCsv::CsvBuilder.new(:retweet_mode => :rollup,
                                               :retweet_threshold => 1,
                                               :retweet_window => 20,
                                               :csv => string_io,
                                               :fields => %w[id retweet_count])
        play_data builder
        string_io.rewind
        string_io.read.should == ""

        string_io = StringIO.new
        builder = TwitterToCsv::CsvBuilder.new(:retweet_mode => :rollup,
                                               :retweet_threshold => 1,
                                               :retweet_window => nil,
                                               :csv => string_io,
                                               :fields => %w[id retweet_count])
        play_data builder
        string_io.rewind
        string_io.read.should == "\"3\",\"1\"\n\"2\",\"3\"\n\"4\",\"1\"\n"

        string_io = StringIO.new
        builder = TwitterToCsv::CsvBuilder.new(:retweet_mode => :rollup,
                                               :retweet_threshold => 0,
                                               :retweet_window => nil,
                                               :csv => string_io,
                                               :fields => %w[id retweet_count])
        play_data builder
        string_io.rewind
        string_io.read.should == "\"3\",\"1\"\n\"2\",\"3\"\n\"4\",\"1\"\n\"5\",\"0\"\n"
      end

      it "logs at the hourly marks requested in retweet_counts_at" do
        string_io = StringIO.new
        builder = TwitterToCsv::CsvBuilder.new(:retweet_mode => :rollup,
                                               :retweet_threshold => 1,
                                               :retweet_window => 4,
                                               :retweet_counts_at => [0.5, 23, 24, 48, 73, 1000],
                                               :csv => string_io,
                                               :fields => %w[id retweet_count])
        play_data builder
        string_io.rewind
        string_io.read.should == "\"2\",\"3\",\"1\",\"1\",\"2\",\"2\",\"3\",\"3\"\n" +
                                 "\"4\",\"1\",\"0\",\"0\",\"0\",\"0\",\"1\",\"1\"\n"
      end
    end
  end

  describe "#extract_fields" do
    it "finds all the paths through a hash" do
      obj = {
          :a => :b,
          :b => "c",
          :d => {
              :e => :f,
              :g => {
                  :h => :i,
                  :j => {
                      :k => "l"
                  }
              },
              :m => "n"
          }
      }
      fields = { "a" => 1 }
      TwitterToCsv::CsvBuilder.new.extract_fields(obj, fields)
      fields.should == { "a" => 2, "b" => 1, "d.e" => 1, "d.g.h" => 1, "d.g.j.k" => 1, "d.m" => 1 }
    end
  end
end
