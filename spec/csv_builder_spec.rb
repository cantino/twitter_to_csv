# encoding: utf-8
require 'spec_helper'

describe TwitterToCsv::CsvBuilder do
  describe "#handle_status" do
    describe "when :english is set" do
      it "skips non-English tweets" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:require_english => true, :csv => string_io, :fields => %w[text])
        csv_builder.handle_status('text' => "This is English", 'user' =>  { 'lang' => 'en' })
        csv_builder.handle_status('text' => "هذه الجملة باللغة الإنجليزية.", 'user' =>  { 'lang' => 'en' })
        csv_builder.handle_status('text' => "Esta frase se encuentra en Ingles.", 'user' =>  { 'lang' => 'en' })
        csv_builder.handle_status('text' => "This is still English", 'user' =>  { 'lang' => 'en' })
        csv_builder.handle_status('text' => "The lang code can lie, but we trust it for now.", 'user' =>  { 'lang' => 'fr' })
        string_io.rewind
        string_io.read.should == "\"This is English\"\n\"This is still English\"\n"
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
    end

    describe "logging to a CSV" do
      it "outputs the requested fields when requested in dot-notation" do
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

      it "can extract URLs" do
        string_io = StringIO.new
        csv_builder = TwitterToCsv::CsvBuilder.new(:csv => string_io, :fields => %w[something], :url_columns => 2)
        csv_builder.handle_status({
            'something' => "hello",
            'text' => 'this is http://a.com/url and http://a.com/nother'
        })
        csv_builder.handle_status({
            'something' => "hello",
            'text' => 'this is http://a.com/url/again'
        })
        string_io.rewind
        string_io.read.should == "\"hello\",\"http://a.com/url\",\"http://a.com/nother\"\n" +
                                 "\"hello\",\"http://a.com/url/again\",\"\"\n"
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
            'created_at' => now - 3.5 * days,
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

      it "skips statuses with fewer than :retweet_threshold retweets and ignores statues that haven't been seen for retweet_window yet'" do
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
