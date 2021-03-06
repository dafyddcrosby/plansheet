# frozen_string_literal: true

require_relative "plansheet/version"
require_relative "plansheet/pool"
require "yaml"

module Plansheet
  class Error < StandardError; end

  # TODO: config schema validation
  def self.load_config
    YAML.load_file "#{Dir.home}/.plansheet.yml"
  rescue StandardError
    abort "unable to load plansheet config file"
  end
end
