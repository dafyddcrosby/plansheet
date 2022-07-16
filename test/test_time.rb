# frozen_string_literal: true

require "test_helper"

require "plansheet/time"

class TestTime < Minitest::Test
  def test_parse_date_duration
    [
      ["1d", 1],
      ["5d", 5],
      ["88d", 88],
      ["1w", 7],
      ["10w", 70]
    ].each do |str, days|
      assert_equal days, parse_date_duration(str)
    end
  end

  def test_build_time_duration
    [
      [30, "30m"],
      [60, "1h"],
      [120, "2h"],
      [150, "2h 30m"]
    ].each do |minutes, str|
      assert_equal str, build_time_duration(minutes)
    end
  end

  def test_parse_time_duration
    [
      ["1m", 1],
      ["5m", 5],
      ["60m", 60],
      ["88m", 88],
      ["1h", 60],
      ["1.5h", 90],
      ["2.5h", 150],
      ["10h", 600]
    ].each do |str, minutes|
      assert_equal minutes, parse_time_duration(str)
    end
  end
end
