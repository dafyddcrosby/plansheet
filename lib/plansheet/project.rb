# frozen_string_literal: true

require "yaml"

module Plansheet
  PROJECT_STATUS_PRIORITY = {
    "wip" => 1,
    "ready" => 2,
    "blocked" => 3,
    "planning" => 4,
    "idea" => 5,
    "dropped" => 6,
    "done" => 7
  }.freeze

  # Once there's some stability in plansheet and dc-kwalify, will pre-load this
  # to save the later YAML.load
  PROJECT_YAML_SCHEMA = <<~YAML
    desc: dc-tasks project schema
    type: seq
    sequence:
      - type: map
        mapping:
          "project":
            desc: Project name
            type: str
            required: yes
          "status":
            desc: The current status of the project
            type: str
            enum:
              - wip # project is a work-in-progress
              - ready # project is fully scoped, ready to go
              - blocked # project is blocked, but otherwise ready/wip
              - planning # project in planning phase
              - idea # project is little more than an idea
              - dropped # project has been explicitly dropped, but
                        # want to keep around for reference, etc
              - done # project is finished, but want to keep around
                     # for reference, etc.
          "priority":
            desc: Project priority (not currently implemented)
            type: str
            enum:
              - high
              - low
          "tasks":
            desc: List of tasks to do
            type: seq
            sequence:
              - type: str
          "done":
            desc: List of tasks which have been completed
            type: seq
            sequence:
              - type: str
          "notes":
            desc: Free-form notes string
            type: str
  YAML
  PROJECT_SCHEMA = YAML.safe_load(PROJECT_YAML_SCHEMA)
end
