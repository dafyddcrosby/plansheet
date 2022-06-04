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

  DUE_TEST_CASES = [
    [{}, {}, 0],
    [{ "due" => Date.today }, {}, -1],
    [{}, { "due" => Date.today },  1],
    [{ "due" => Date.today }, { "due" => Date.today }, 0],
    [{ "due" => (Date.today + 1) }, { "due" => Date.today }, 1],
    [{ "due" => Date.today }, { "due" => Date.today + 1 }, -1]
  ].freeze
  def test_due_comparison
    DUE_TEST_CASES.each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_due(Plansheet::Project.new(y))
    end
  end

  DEFER_TEST_CASES = [
    [{}, {}, 0],
    [{ "defer" => Date.today }, {}, 0],
    [{}, { "defer" => Date.today }, 0],
    [{ "defer" => Date.today }, { "defer" => Date.today }, 0],
    [{}, { "defer" => Date.today + 1 }, -1],
    [{ "defer" => Date.today + 1 }, {}, 1],
    [{ "defer" => Date.today - 1 }, {}, 0],
    [{}, { "defer" => Date.today - 1 }, 0]
  ].freeze
  def test_defer_comparison
    DEFER_TEST_CASES.each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_defer(Plansheet::Project.new(y))
    end
  end

  DEPENDENCY_TEST_CASES = [
    [{}, {}, 0],
    [{ "project" => "foo" }, { "dependencies" => ["foo"] }, -1],
    [{ "project" => "Foo" }, { "dependencies" => ["foo"] }, -1],
    [{ "project" => "foo" }, { "dependencies" => ["bar"] }, 0],
    [{ "project" => "foo" }, { "dependencies" => [] }, 0],
    [{ "dependencies" => ["foo"] }, { "project" => "foo" }, 1],
    [{ "dependencies" => ["foo"] }, { "project" => "Foo" }, 1],
    [{ "dependencies" => ["bar"] }, { "project" => "foo" }, 0],
    [{ "dependencies" => [] }, { "project" => "foo" }, 0]
  ].freeze
  def test_dependency_comparison
    DEPENDENCY_TEST_CASES.each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_dependency(Plansheet::Project.new(y))
    end
  end

  COMPLETENESS_TEST_CASES = [
    [{}, {}, 0],
    [{ "status" => "dropped" }, {}, 1],
    [{ "status" => "done" }, {}, 1],
    [{}, { "status" => "done" }, -1],
    [{}, { "status" => "dropped" }, -1],
    [{ "status" => "done" }, { "status" => "done" }, 0],
    [{ "status" => "done" }, { "status" => "dropped" }, 0],
    [{ "status" => "dropped" }, { "status" => "done" }, 0]
  ].freeze
  def test_completeness_comparison
    COMPLETENESS_TEST_CASES.each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_completeness(Plansheet::Project.new(y))
    end
  end
end
