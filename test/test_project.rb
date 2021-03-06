# frozen_string_literal: true

require "test_helper"

# TODO: yuck, that's gross
Plansheet::Pool::POOL_COMPARISON_ORDER = Plansheet::Pool::DEFAULT_COMPARISON_ORDER

require "plansheet/project"

class TestProjectInputs < Minitest::Test
  def test_implied_due
    # Empty project
    assert_nil Plansheet::Project.new({}).due

    # Non-empty projects
    [
      # First-time recurring due
      [{ "frequency" => "1w" }, Date.today],

      # Subsequent recurring due
      [{ "frequency" => "1w", "last_done" => Date.today - 7 }, Date.today],
      [{ "frequency" => "1w", "last_done" => Date.today - 1 }, Date.today + 6]
    ].each do |proj, due|
      assert_equal due, Plansheet::Project.new(proj).due
    end
  end

  def test_defer
    assert_nil Plansheet::Project.new({}).defer

    [
      [
        {

          "project" => "Deferred to today",
          "defer" => Date.today
        },
        Date.today
      ],
      [
        {
          "project" => "Deferred to tomorrow",
          "defer" => Date.today + 1
        },
        Date.today + 1
      ],
      [
        {
          "project" => "Defer was yesterday, now irrelevant",
          "defer" => Date.today - 1
        },
        nil
      ],
      [
        {
          "project" => "Lasts until today",
          "last_for" => "1w",
          "last_done" => Date.today - 7
        },
        Date.today
      ],
      [
        {
          "project" => "Lasts until tomorrow",
          "last_for" => "1w",
          "last_done" => Date.today - 6
        },
        Date.today + 1
      ],
      [
        {
          "project" => "Defer was yesterday",
          "last_for" => "1w",
          "last_done" => Date.today - 8
        },
        Date.today - 1
      ]
    ].each do |proj, due|
      assert_equal due, Plansheet::Project.new(proj).defer, proj
    end
  end

  def test_implied_status
    [
      # Empty project
      [{}, "idea"],

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

  def test_time_roi_payoff
    [
      [
        {
          "daily_time_roi" => "1m",
          "time_estimate" => "365m"
        },
        1.0
      ],
      [
        {
          "weekly_time_roi" => "30m",
          "time_estimate" => "1h"
        },
        26.0
      ],
      [
        {
          "yearly_time_roi" => "2h",
          "time_estimate" => "1h"
        },
        2.0
      ]
    ].each do |proj, payoff|
      x = Plansheet::Project.new(proj)
      assert_equal payoff, x.time_roi_payoff
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
        name: "non-recurring task",
        proj: {},
        recurring: false,
        status: "idea"
      },
      {
        name: "Implied first time - frequency",
        proj: {
          "frequency" => "1w"
        },
        recurring: true,
        status: "idea",
        due: Date.today
      },
      {
        name: "Implied first time - frequency (using lead_time)",
        proj: {
          "frequency" => "1w",
          "lead_time" => "1d"
        },
        recurring: true,
        status: "idea",
        due: Date.today,
        defer: Date.today
      },
      # TODO: add rest of last_for cases
      {
        name: "Implied first time - last_for",
        proj: {
          "last_for" => "1w"
        },
        recurring: true,
        status: "idea",
        defer: Date.today
      },
      {
        name: "Implied first time - day-of-week",
        proj: {
          "day_of_week" => Date.today.strftime("%A")
        },
        recurring: true,
        status: "idea",
        due: Date.today
      },
      {
        name: "Implied first time - day-of-week (using lead_time)",
        proj: {
          "day_of_week" => Date.today.strftime("%A")
        },
        recurring: true,
        status: "idea",
        due: Date.today
      },
      {
        name: "Frequency recurring - done exactly last week",
        proj: {
          "frequency" => "1w",
          "last_done" => Date.today - 7
        },
        recurring: true,
        status: "idea",
        due: Date.today
      },
      {
        name: "Frequency recurring - done over a week ago",
        proj: {
          "frequency" => "1w",
          "last_done" => Date.today - 8
        },
        recurring: true,
        status: "idea",
        due: Date.today - 1
      },
      {
        name: "Frequency recurring - done less than a week ago",
        proj: {
          "frequency" => "1w",
          "last_done" => Date.today - 6
        },
        recurring: true,
        status: "done",
        due: Date.today + 1
      },
      {
        name: "Frequency recurring - finished today",
        proj: {
          "frequency" => "1w",
          "last_done" => Date.today
        },
        recurring: true,
        status: "done",
        due: Date.today + 7
      },
      {
        name: "Day-of-week recurring - done exactly last week",
        proj: {
          "day_of_week" => Date.today.strftime("%A"),
          "last_done" => Date.today - 7
        },
        recurring: true,
        status: "idea",
        due: Date.today
      },
      {
        name: "Day-of-week recurring - done over a week ago",
        proj: {
          "day_of_week" => Date.today.strftime("%A"),
          "last_done" => Date.today - 8
        },
        recurring: true,
        status: "idea",
        due: Date.today - 1
      },
      {
        name: "Day-of-week recurring - done less than a week ago",
        proj: {
          "day_of_week" => Date.today.strftime("%A"),
          "last_done" => Date.today - 6
        },
        recurring: true,
        status: "idea",
        due: Date.today
      },
      {
        name: "Day-of-week recurring - finished today",
        proj: {
          "day_of_week" => Date.today.strftime("%A"),
          "last_done" => Date.today
        },
        recurring: true,
        status: "done",
        due: Date.today + 7
      }
      # TODO: test that lead time works
    ].each do |t|
      x = Plansheet::Project.new(t[:proj])
      assert_equal t[:recurring], x.recurring?, t
      assert_equal t[:status], x.status, t
      assert_equal t[:defer], x.defer, t
      assert_equal t[:due], x.due, t
    end
  end

  def duplicate_hash_expected(hsh)
    # TODO: can we get away with a clone operation here?
    [hsh, Marshal.load(Marshal.dump(hsh))]
  end

  def test_to_h
    # These projects should have almost identical outputs (save for namespace on created_on)
    [
      { "project" => "empty project" },
      { "project" => "explicit status - idea", "status" => "idea" },
      { "project" => "explicit status - paused", "status" => "paused" },
      { "project" => "explicit status - dropped", "status" => "dropped" },
      { "project" => "explicit status - done", "status" => "done" },
      { "project" => "explicit status - wip", "status" => "wip" },
      { "project" => "explicit status - ready", "status" => "ready" },
      { "project" => "explicit status - blocked", "status" => "blocked" },
      { "project" => "explicit status - planning", "status" => "planning" },
      { "project" => "explicit status - waiting", "status" => "waiting" },
      { "project" => "explicit due", "due" => Date.today },
      {
        "project" => "project with non-low priority",
        "priority" => "high"
      },
      {
        "project" => "project with non-idea status",
        "status" => "ready"
      },
      {
        "project" => "project with explicit time_estimate 30m",
        "time_estimate" => "30m"
      },
      {
        "project" => "project with unparseable task time durations",
        "tasks" => [
          "task d (1.5h) ", # trailing space
          "task (1.5h) e" # trailing characters
        ]
      }
    ].map { |x| duplicate_hash_expected(x) } +
      # The following test cases have some sort of mutation
      [
        [
          {
            "project" => "convert status: done to completed_on: today",
            "status" => "done"
          },
          {
            "project" => "convert status: done to completed_on: today",
            "completed_on" => Date.today
          }
        ],
        [
          {
            "project" => "convert status: dropped to dropped_on: today",
            "status" => "dropped"
          },
          {
            "project" => "convert status: dropped to dropped_on: today",
            "dropped_on" => Date.today
          }
        ],
        [
          {
            "project" => "convert status: paused to paused_on: today",
            "status" => "paused"
          },
          {
            "project" => "convert status: paused to paused_on: today",
            "paused_on" => Date.today
          }
        ],
        [
          {
            "project" => "removes time_estimate if project is done",
            "time_estimate" => "30m",
            "status" => "done"
          },
          {
            "project" => "removes time_estimate if project is done",
            "completed_on" => Date.today
          }
        ],
        [
          {
            "project" => "convert all done tasks to completed_on: today",
            "done" => %w[foo bar]
          },
          {
            "project" => "convert all done tasks to completed_on: today",
            "done" => %w[foo bar],
            "completed_on" => Date.today
          }
        ],
        [
          {
            "project" => "doesn't add completed_on if task is recurring",
            "frequency" => "1w",
            "done" => %w[foo bar]
          },
          {
            "project" => "doesn't add completed_on if task is recurring",
            "frequency" => "1w",
            "done" => %w[foo bar]
          }
        ],
        [
          {
            "project" => "nil task 1",
            "tasks" => ["a", nil, "b"]
          },
          {
            "project" => "nil task 1",
            "tasks" => %w[a b]
          }
        ],
        [
          {
            "project" => "nil task 2",
            "tasks" => [nil]
          },
          {
            "project" => "nil task 2"
          }
        ],
        [
          {
            "project" => "stale defer",
            "created_on" => Date.today - 2,
            "defer" => Date.today - 1
          },
          {
            "project" => "stale defer",
            "created_on" => Date.today - 2
          }
        ],
        [
          {
            "project" => "project with explicit time_estimate 60m",
            "time_estimate" => "60m"
          },
          {
            "project" => "project with explicit time_estimate 60m",
            "time_estimate" => "1h" # NOTE: change from 60m to 1h
          }
        ],
        [
          {
            "project" => "project with implied time_estimate (single)",
            "tasks" => [
              "task (15m)"
            ]
          },
          {
            "project" => "project with implied time_estimate (single)",
            "time_estimate" => "15m",
            "tasks" => [
              "task (15m)"
            ]
          }
        ],
        [
          {
            "project" => "project with implied time_estimate (stale explicit)",
            "time_estimate" => "55m",
            "tasks" => [
              "task (15m)"
            ]
          },
          {
            "project" => "project with implied time_estimate (stale explicit)",
            "time_estimate" => "15m",
            "tasks" => [
              "task (15m)"
            ]
          }
        ],
        [
          {
            "project" => "project with implied time_estimate (multiple)",
            "tasks" => [
              "task a (15m)",
              "task b (15m)"
            ]
          },
          {
            "project" => "project with implied time_estimate (multiple)",
            "time_estimate" => "30m",
            "tasks" => [
              "task a (15m)",
              "task b (15m)"
            ]
          }
        ],
        [
          {
            "project" => "task with missing task name",
            "tasks" => [
              "normal task (1.5h)",
              "(1.5h)" # Weird, but legal for implementation reasons
            ]
          },
          {
            "project" => "task with missing task name",
            "time_estimate" => "3h",
            "tasks" => [
              "normal task (1.5h)",
              "(1.5h)"
            ]
          }
        ],
        [
          {
            "project" => "project with implied time_estimate (multiple with missing)",
            "tasks" => [
              "task a (15m)",
              "task with no estimate",
              "task b (15m)"
            ]
          },
          {
            "project" => "project with implied time_estimate (multiple with missing)",
            "time_estimate" => "30m",
            "tasks" => [
              "task a (15m)",
              "task with no estimate",
              "task b (15m)"
            ]
          }
        ]
      ].each do |proj, p_to_h_results|
        # handle here for brevity of expected results
        p_to_h_results["namespace"] = nil
        p_to_h_results["created_on"] ||= Date.today

        assert_equal p_to_h_results, Plansheet::Project.new(proj).to_h, proj
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

  def test_name_comparison
    add_inverted_test_cases(
      [
        [{}, {}, 0],
        [{ "project" => "a" }, { "project" => "b" }, -1]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_name(Plansheet::Project.new(y))
    end
  end

  def test_completed_on_comparison
    add_inverted_test_cases(
      [
        [{}, {}, 0],
        [{ "completed_on" => Date.today }, {}, 1],
        [{ "completed_on" => Date.today }, { "completed_on" => Date.today }, 0],
        [{ "completed_on" => Date.today - 1 }, { "completed_on" => Date.today }, 1]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_completed_on(Plansheet::Project.new(y))
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
      assert_equal e, Plansheet::Project.new(x).compare_completeness(Plansheet::Project.new(y)), [x, y, e]
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

  def test_time_roi_comparison
    add_inverted_test_cases(
      [
        [{}, {}, 0],

        [{ "time_estimate" => "30m", "daily_time_roi" => "5m" }, {}, -1],
        [{ "time_estimate" => "30m", "weekly_time_roi" => "5m" }, {}, -1],
        [{ "time_estimate" => "30m", "yearly_time_roi" => "5m" }, {}, -1],
        [
          { "time_estimate" => "30m", "daily_time_roi" => "5m" },
          { "time_estimate" => "1h", "daily_time_roi" => "5m" },
          -1
        ],
        [
          { "time_estimate" => "30m", "weekly_time_roi" => "5m" },
          { "time_estimate" => "1h", "weekly_time_roi" => "5m" },
          -1
        ],
        [
          { "time_estimate" => "30m", "yearly_time_roi" => "5m" },
          { "time_estimate" => "1h", "yearly_time_roi" => "5m" },
          -1
        ]
      ]
    ).each do |x, y, e|
      assert_equal e, Plansheet::Project.new(x).compare_time_roi(Plansheet::Project.new(y))
    end
  end
end
