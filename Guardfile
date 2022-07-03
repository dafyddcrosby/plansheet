# frozen_string_literal: true

directories(%w[. exe bin lib test].select { |d| Dir.exist?(d) ? d : UI.warning("Directory #{d} does not exist") })

guard :rake, task: "default" do
  watch("Gemfile")
  watch("Rakefile")
  watch("Guardfile")
  watch(%r{^test/test_(.*)\.rb$})
  watch("exe/plansheet")
  watch("bin/console")
  watch(%r{^test/test_(.*)\.rb$})
  watch(%r{^lib/plansheet/(.*)\.rb$})
  watch(%r{^lib/plansheet\.rb$})
end
