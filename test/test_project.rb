# frozen_string_literal: true

require "test_helper"

# TODO: yuck, that's gross
Plansheet::Pool::POOL_COMPARISON_ORDER = Plansheet::Pool::DEFAULT_COMPARISON_ORDER

require "plansheet/project"

class TestProjectInputs < Minitest::Test
  def test_due
    # Empty project
    assert_nil Plansheet::Project.new({}).due

    # Non-empty projects
    [
      # Explicit due
      [{ "due" => Date.today }, Date.today],

      # First-time recurring due
      [{ "frequency" => "1w" }, Date.today],

      # Subsequent recurring due
      [{ "frequency" => "1w", "last_done" => Date.today - 7 }, Date.today],
      [{ "frequency" => "1w", "last_done" => Date.today - 1 }, Date.today + 6]
    ].each do |proj, due|
      assert_equal due, Plansheet::Project.new(proj).due
    end
  end

  def test_status
    [
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
    ].each do |proj, status|
      assert_equal status, Plansheet::Project.new(proj).status
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

  def test_lead_time
    assert_nil Plansheet::Project.new({}).defer
    [
      {
        proj: {
          "lead_time" => "1w",
          "due" => Date.today + 14
        },
        defer: Date.today + 7
      }
    ].each do |t|
      x = Plansheet::Project.new(t[:proj])
      assert_equal t[:defer], x.defer
    end
  end

  def test_recurring_projects
    [
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
    ].each do |t|
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

class TestProjectComparison < Minitest::Test
  # This makes test cases DRYer, while testing both sides of an equality test
  def add_inverted_test_cases(arr)
    arr + arr.map do |x, y, z|
      [y, x, (z * -1)]
    end
  end

  def test_priority_comparison
    add_inverted_test_cases(
      [
        [{}, {}, 0],
        [{}, { "priority" => "low" }, 0],
        [{ "priority" => "high" }, { "priority" => "high" }, 0],
        [{ "priority" => "medium" }, { "priority" => "medium" }, 0],
        [{ "priority" => "low" }, { "priority" => "low" }, 0],
        [{}, { "priority" => "high" }, 1],
        [{}, { "priority" => "medium" }, 1],
        [{ "priority" => "medium" }, { "priority" => "high" }, 1],
        [{ "priority" => "low" }, { "priority" => "high" }, 1]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_priority(Plansheet::Project.new(y))
    end
  end

  def test_completeness_comparison
    add_inverted_test_cases(
      [
        [{}, {}, 0],
        [{ "status" => "done" }, { "status" => "done" }, 0],
        [{ "status" => "done" }, { "status" => "dropped" }, 0],
        [{ "status" => "dropped" }, { "status" => "done" }, 0],
        [{}, { "status" => "done" }, -1],
        [{}, { "status" => "dropped" }, -1]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_completeness(Plansheet::Project.new(y))
    end
  end

  def test_status_comparison
    add_inverted_test_cases(
      [
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
        [{ "status" => "wip" },
         { "tasks" => ["foo"], "done" => ["bar"] }, 0]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_status(Plansheet::Project.new(y))
    end
  end

  def test_due_comparison
    add_inverted_test_cases(
      [
        [{}, {}, 0],
        [{}, { "due" => Date.today }, 1],
        [{ "due" => Date.today }, { "due" => Date.today }, 0],
        [{ "due" => (Date.today + 1) }, { "due" => Date.today }, 1]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_due(Plansheet::Project.new(y))
    end
  end

  def test_defer_comparison
    add_inverted_test_cases(
      [
        [{}, {}, 0],
        [{}, { "defer" => Date.today }, 0],
        [{ "defer" => Date.today }, { "defer" => Date.today }, 0],
        [{}, { "defer" => Date.today - 1 }, 0],
        [{}, { "defer" => Date.today + 1 }, -1]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_defer(Plansheet::Project.new(y))
    end
  end

  def test_dependency_comparison
    add_inverted_test_cases(
      [
        [{}, {}, 0],

        [{ "dependencies" => [] }, { "project" => "foo" }, 0],
        [{ "dependencies" => [] }, {}, 0],
        [{ "dependencies" => ["foo"] }, {}, 0],
        [{ "dependencies" => ["bar"] }, { "project" => "foo" }, 0],
        [{ "dependencies" => ["bar"] }, { "project" => "foo" }, 0],

        # Handle circular dependencies
        [{ "project" => "foo", "dependencies" => ["bar"] },
         { "project" => "bar", "dependencies" => ["foo"] },
         0],

        [{ "dependencies" => ["foo"] }, { "project" => "foo" }, 1],
        # Handle case inconsistency
        [{ "dependencies" => ["foo"] }, { "project" => "Foo" }, 1],
        # Multiple dependencies
        [{ "dependencies" => %w[bar foo] }, { "project" => "foo" }, 1]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_dependency(Plansheet::Project.new(y))
    end
  end
end
