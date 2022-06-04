# frozen_string_literal: true

directories(%w[lib test].select { |d| Dir.exist?(d) ? d : UI.warning("Directory #{d} does not exist") })

guard :minitest do
  watch(%r{^test/test_(.*)\.rb$}) { "test" }
  watch(%r{^lib/plansheet/(.*)\.rb$}) { "test" }
  watch(%r{^lib/plansheet\.rb$}) { "test" }
end
