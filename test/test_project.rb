# frozen_string_literal: true

require "test_helper"

# TODO: yuck, that's gross
Plansheet::Pool::POOL_COMPARISON_ORDER = [].freeze

require "plansheet/project"

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

  DUE_TEST_CASES = [
    # Explicit due
    [{ "due" => Date.today }, Date.today],

    # First-time recurring due
    [{ "frequency" => "1w" }, Date.today],

    # Subsequent recurring due
    [{ "frequency" => "1w", "last_done" => Date.today - 7 }, Date.today],
    [{ "frequency" => "1w", "last_done" => Date.today - 1 }, Date.today + 6]
  ].freeze
  def test_due
    # Empty project
    assert_nil Plansheet::Project.new({}).due

    # Non-empty projects
    DUE_TEST_CASES.each do |proj, due|
      assert_equal due, Plansheet::Project.new(proj).due
    end
  end

  STATUS_TEST_CASES = [
    # Empty project
    [{}, "idea"],

    # Explicit status
    [{ "status" => "idea" }, "idea"],
    [{ "status" => "dropped" }, "dropped"],
    [{ "status" => "done" }, "done"],
    [{ "status" => "wip" }, "wip"],
    [{ "status" => "ready" }, "ready"],
    [{ "status" => "blocked" }, "blocked"],
    [{ "status" => "planning" }, "planning"],
    [{ "status" => "waiting" }, "waiting"],

    # Task-based status
    [{ "tasks" => [] }, "idea"],
    [{ "done" => [] }, "idea"],
    [{ "tasks" => [], "done" => [] }, "idea"],
    [{ "tasks" => ["foo"] }, "ready"],
    [{ "done" => ["foo"] }, "done"],
    [{ "tasks" => ["foo"], "done" => ["bar"] }, "wip"],

    # First-time recurring status
    [
      { "frequency" => "1w" },
      "idea"
    ],
    [
      { "frequency" => "1w", "tasks" => ["foo"] },
      "ready"
    ],
    [
      { "frequency" => "1w", "tasks" => ["foo"], "done" => ["bar"] },
      "wip"
    ],
    # Subsequent recurring status
    [
      { "frequency" => "1w", "last_done" => Date.today - 1 },
      "done"
    ],

    # Inferred 'done' with 'completed_on'
    [{ "completed_on" => Date.today }, "done"]
  ].freeze
  def test_status
    STATUS_TEST_CASES.each do |proj, status|
      assert_equal status, Plansheet::Project.new(proj).status
    end
  end
  STATUS_COMPARISON_TEST_CASES = [
    [{}, {}, 0],
    [{}, { "status" => "idea" }, 0],
    [{}, { "status" => "dropped" }, -1],
    [{}, { "status" => "done" }, -1],
    [{}, { "status" => "wip" }, 1],
    [{}, { "status" => "ready" }, 1],
    [{}, { "status" => "blocked" }, 1],
    [{}, { "status" => "planning" }, 1],
    [{ "status" => "ready" }, { "status" => "wip" }, 1],
    [{ "status" => "ready" }, { "tasks" => ["foo"] }, 0],
    [{ "status" => "wip" }, { "tasks" => ["foo"], "done" => ["bar"] }, 0]
  ].freeze
  def test_status_comparison
    STATUS_COMPARISON_TEST_CASES.each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_status(Plansheet::Project.new(y))
    end
  end

  DUE_COMPARISON_TEST_CASES = [
    [{}, {}, 0],
    [{ "due" => Date.today }, {}, -1],
    [{}, { "due" => Date.today },  1],
    [{ "due" => Date.today }, { "due" => Date.today }, 0],
    [{ "due" => (Date.today + 1) }, { "due" => Date.today }, 1],
    [{ "due" => Date.today }, { "due" => Date.today + 1 }, -1]
  ].freeze
  def test_due_comparison
    DUE_COMPARISON_TEST_CASES.each do |x, y, e|
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

  def test_parse_date_duration
    [
      ["1d", 1],
      ["1D", 1],
      ["5d", 5],
      ["5D", 5],
      ["88d", 88],
      ["88D", 88],
      ["1w", 7],
      ["1W", 7],
      ["10w", 70],
      ["10W", 70]
    ].each do |str, days|
      assert_equal days, Plansheet.parse_date_duration(str)
    end
  end

  LEAD_TIME_TEST_CASES = [
    {
      proj: {
        "lead_time" => "1w",
        "due" => Date.today + 14
      },
      defer: Date.today + 7
    }
  ].freeze
  def test_lead_time
    assert_nil Plansheet::Project.new({}).defer
    LEAD_TIME_TEST_CASES.each do |t|
      x = Plansheet::Project.new(t[:proj])
      assert_equal t[:defer], x.defer
    end
  end

  RECURRING_PROJECT_TEST_CASES = [
    {
      proj: {},
      recurring: false
    },
    {
      proj: {
        "frequency" => "1w"
      },
      recurring: true,
      status: "ready",
      defer: Date.today
    }
  ].freeze
  def test_recurring_projects
    RECURRING_PROJECT_TEST_CASES.each do |t|
      x = Plansheet::Project.new(t[:proj])
      assert_equal t[:recurring], x.recurring?
      # test for last done
      # test for lead time
      # test for due
      # test that status changes to ready
      # test that done tasks are moved to ready tasks
    end
  end
end
