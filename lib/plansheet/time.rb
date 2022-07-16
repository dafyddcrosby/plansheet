# frozen_string_literal: true

module Plansheet
  module TimeUtils
    def parse_date_duration(str)
      return Regexp.last_match(1).to_i if str.strip.match(/(\d+)[dD]/)
      return (Regexp.last_match(1).to_i * 7) if str.strip.match(/(\d+)[wW]/)

      raise "Can't parse time duration string #{str}"
    end

    def parse_time_duration(str)
      if str.match(/(\d+h) (\d+m)/)
        return (parse_time_duration(Regexp.last_match(1)) + parse_time_duration(Regexp.last_match(2)))
      end

      return Regexp.last_match(1).to_i if str.strip.match(/(\d+)m/)
      return (Regexp.last_match(1).to_f * 60).to_i if str.strip.match(/(\d+\.?\d*)h/)

      raise "Can't parse time duration string #{str}"
    end

    def build_time_duration(minutes)
      if minutes > 59
        if (minutes % 60).zero?
          "#{minutes / 60}h"
        else
          "#{minutes / 60}h #{minutes % 60}m"
        end
      else
        "#{minutes}m"
      end
    end
  end
end
