# frozen_string_literal: true

require "test_helper"
require "plansheet/pool"

class TestPoolSorting < Minitest::Test
  def projectify_array(arr)
    arr.map { |proj| Plansheet::Project.new proj }
  end

  def test_priority_comparison
    [
      # Empty projects
      [
        [], []
      ],
      # One project
      [
        [
          { "project" => "only", "priority" => "low" }
        ],
        [
          { "project" => "only", "priority" => "low" }
        ]
      ],
      # Simple list, no dependencies
      [
        [
          { "project" => "a", "priority" => "low" },
          { "project" => "b", "priority" => "high" },
          { "project" => "c", "priority" => "medium" }
        ],
        [
          { "project" => "b", "priority" => "high" },
          { "project" => "c", "priority" => "medium" },
          { "project" => "a", "priority" => "low" }
        ]
      ],
      # Simple dependency
      [
        [
          { "project" => "a", "dependencies" => %w[b] },
          { "project" => "b" }
        ],
        [
          { "project" => "b" },
          { "project" => "a", "dependencies" => %w[b] }
        ]
      ],
      # Simple dependencies with priorities
      [
        [
          { "project" => "a", "dependencies" => %w[b c] },
          { "project" => "b", "priority" => "medium" },
          { "project" => "c", "priority" => "high" }
        ],
        [
          { "project" => "c", "priority" => "high" },
          { "project" => "b", "priority" => "medium" },
          { "project" => "a", "dependencies" => %w[b c] }
        ]
      ],
      # Dependencies with lower priorities
      [
        [
          { "project" => "a", "priority" => "high", "dependencies" => %w[b c] },
          { "project" => "b", "priority" => "medium" },
          { "project" => "c", "priority" => "low" }
        ],
        [
          { "project" => "b", "priority" => "medium" },
          { "project" => "c", "priority" => "low" },
          { "project" => "a", "priority" => "high", "dependencies" => %w[b c] }
        ]
      ],
      # Dependency chain
      [
        [
          { "project" => "a", "dependencies" => %w[b] },
          { "project" => "c" },
          { "project" => "b", "dependencies" => %w[c] }
        ],
        [
          { "project" => "c" },
          { "project" => "b", "dependencies" => %w[c] },
          { "project" => "a", "dependencies" => %w[b] }
        ]
      ],
      # Inherited dependency strength
      [
        [
          { "project" => "medium", "priority" => "medium" },
          { "project" => "parent", "priority" => "high", "dependencies" => %w[child] },
          { "project" => "child", "priority" => "low" }
        ],
        [
          { "project" => "child", "priority" => "low" },
          { "project" => "parent", "priority" => "high", "dependencies" => %w[child] },
          { "project" => "medium", "priority" => "medium" }
        ]
      ],
      # Grandparent projects
      [
        [
          { "project" => "medium", "priority" => "medium" },
          { "project" => "parent", "priority" => "high", "dependencies" => %w[child] },
          { "project" => "grandparent", "priority" => "low", "dependencies" => %w[parent] },
          { "project" => "child", "priority" => "medium" }
        ],
        [
          { "project" => "child", "priority" => "medium" },
          { "project" => "parent", "priority" => "high", "dependencies" => %w[child] },
          { "project" => "medium", "priority" => "medium" },
          { "project" => "grandparent", "priority" => "low", "dependencies" => %w[parent] }
        ]
      ]
      # TODO: In this case the child should be getting the priority of high
      # [
      #   [
      #     { "project" => "medium", "priority" => "medium" },
      #     { "project" => "parent", "priority" => "medium", "dependencies" => %w[child] },
      #     { "project" => "grandparent", "priority" => "high", "dependencies" => %w[parent] },
      #     { "project" => "child", "priority" => "low" },
      #   ],
      #   [
      #     { "project" => "child", "priority" => "low" },
      #     { "project" => "parent", "priority" => "medium", "dependencies" => %w[child] },
      #     { "project" => "grandparent", "priority" => "high", "dependencies" => %w[parent] },
      #     { "project" => "medium", "priority" => "medium" },
      #   ]
      # ]
    ].each do |x, y|
      pool = Plansheet::Pool.new({}, debug: true)
      pool.projects = projectify_array(x)
      pool.sort_projects
      assert_equal projectify_array(y), pool.projects
    end
  end
end
