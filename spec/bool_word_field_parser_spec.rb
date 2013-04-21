# encoding: utf-8
require 'spec_helper'
require 'time'

describe TwitterToCsv::BoolWordFieldParser do
  describe "#parse" do
    it "parses name:string AND string AND string... syntax" do
      TwitterToCsv::BoolWordFieldParser.parse("something:string1 string2 AND string3 AND string4").should == {
          :name => "something",
          :logic => ["string1 string2", :and, ["string3", :and, ["string4"]]]
      }
    end

    it "parses name:string OR string OR string... syntax" do
      TwitterToCsv::BoolWordFieldParser.parse("something:string1 string2 OR string3 OR string4").should == {
          :name => "something",
          :logic => ["string1 string2", :or, ["string3", :or, ["string4"]]]
      }
    end

    it "parses parens" do
      TwitterToCsv::BoolWordFieldParser.parse("something_else:string1   STRING2 OR ( string3 AND (string4 OR string5 ))").should == {
          :name => "something_else",
          :logic => ["string1 string2", :or, ["string3", :and, ["string4", :or, ["string5"]]]]
      }
    end
  end

  describe "#check" do
    it "returns true when an expression matches some text, false when it doesn't" do
      pattern = TwitterToCsv::BoolWordFieldParser.parse("something_else:string1 string2 OR (string3 AND (string4 OR string5))")
      TwitterToCsv::BoolWordFieldParser.check(pattern, "string1 string2").should be_true
      TwitterToCsv::BoolWordFieldParser.check(pattern, "string1").should be_false
      TwitterToCsv::BoolWordFieldParser.check(pattern, "string2").should be_false
      TwitterToCsv::BoolWordFieldParser.check(pattern, "string3 string4").should be_true
      TwitterToCsv::BoolWordFieldParser.check(pattern, "string4 string3").should be_true
      TwitterToCsv::BoolWordFieldParser.check(pattern, "string5 string3").should be_true
      TwitterToCsv::BoolWordFieldParser.check(pattern, "foo bar string3 string5 baz").should be_true
      TwitterToCsv::BoolWordFieldParser.check(pattern, "foo bar string5 baz").should be_false
      TwitterToCsv::BoolWordFieldParser.check(pattern, "foo bar string3 string4 string5 baz").should be_true
      TwitterToCsv::BoolWordFieldParser.check(pattern, "foo bar string3 string5 baz string4").should be_true
      TwitterToCsv::BoolWordFieldParser.check(pattern, "string1 string2 string3 string4").should be_true
    end

    it "raises errors when the input is un-evaluable" do
      pattern = TwitterToCsv::BoolWordFieldParser.parse("something_else:string1 string2 OR (string3 AND OR string5))")
      lambda { TwitterToCsv::BoolWordFieldParser.check(pattern, "string1 string2") }.should raise_error(TwitterToCsv::InvalidLogicError)

      pattern = TwitterToCsv::BoolWordFieldParser.parse("hello (")
      lambda { TwitterToCsv::BoolWordFieldParser.check(pattern, "string1 string2") }.should raise_error(TwitterToCsv::InvalidLogicError)

      pattern = TwitterToCsv::BoolWordFieldParser.parse("hello ()")
      lambda { TwitterToCsv::BoolWordFieldParser.check(pattern, "string1 string2") }.should raise_error(TwitterToCsv::InvalidLogicError)
    end
  end
end
