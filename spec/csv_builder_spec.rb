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
