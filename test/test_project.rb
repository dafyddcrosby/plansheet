# frozen_string_literal: true

require "test_helper"

class TestProject < Minitest::Test
  PRIORITY_TEST_CASES = [
    [{}, {}, 0],
    [{ "priority" => "high" }, { "priority" => "high" }, 0],
    [{}, { "priority" => "high" }, 1],
    [{ "priority" => "high" }, {}, -1],
    [{ "priority" => "medium" }, { "priority" => "high" }, 1],
    [{ "priority" => "high" }, { "priority" => "medium" }, -1]
  ].freeze

  def test_priority_comparison
    PRIORITY_TEST_CASES.each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_priority(Plansheet::Project.new(y))
    end
  end

  STATUS_TEST_CASES = [
    [{}, {}, 0],
    [{}, { "status" => "idea" }, 0],
    [{}, { "status" => "dropped" }, -1],
    [{}, { "status" => "done" }, -1],
    [{}, { "status" => "wip" }, 1],
    [{}, { "status" => "ready" }, 1],
    [{}, { "status" => "blocked" }, 1],
    [{}, { "status" => "planning" }, 1],
    [{ "status" => "ready" }, { "status" => "wip" }, 1],
    [{ "status" => "planning" }, { "tasks" => ["foo"] }, 0],
    [{ "status" => "wip" }, { "tasks" => ["foo"], "done" => ["bar"] }, 0]
  ].freeze
  def test_status_comparison
    STATUS_TEST_CASES.each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_status(Plansheet::Project.new(y))
    end
  end
end
