# frozen_string_literal: true

module Plansheet
  class Project
    def to_s
      str = String.new
      str << "# "
      str << "#{@namespace} - " if @namespace
      str << "#{@name}\n"
      STRING_PROPERTIES.each do |o|
        str << stringify_string_property(o)
      end
      DATE_PROPERTIES.each do |o|
        str << stringify_string_property(o)
      end
      ARRAY_PROPERTIES.each do |o|
        str << stringify_array_property(o)
      end
      str
    end

    def stringify_string_property(prop)
      if instance_variable_defined? "@#{prop}"
        "#{prop}: #{instance_variable_get("@#{prop}")}\n"
      else
        ""
      end
    end

    def stringify_date_property(prop)
      if instance_variable_defined? "@#{prop}"
        "#{prop}: #{instance_variable_get("@#{prop}")}\n"
      else
        ""
      end
    end

    def stringify_array_property(prop)
      str = String.new
      if instance_variable_defined? "@#{prop}"
        str << "#{prop}:\n"
        instance_variable_get("@#{prop}").each do |t|
          str << "- #{t}\n"
        end
      end
      str
    end
  end
end
