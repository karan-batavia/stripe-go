# typed: strict
require File.expand_path('../config/environment', __dir__)


class SequelSorbetPlugin
  extend T::Sig
  # include SorbetRails::ModelColumnUtils

  class ColumnType < T::Struct
    extend T::Sig

    const :base_type, T.any(Class, String)
    const :nilable, T.nilable(T::Boolean)
    const :array_type, T.nilable(T::Boolean)

    sig { returns(String) }
    def to_s
      type = base_type.to_s
      # A nullable array column should be T.nilable(T::Array[column_type]) not T::Array[T.nilable(column_type)]
      type = "T::Array[#{type}]" if array_type
      type = "T.nilable(#{type})" if nilable
      type
    end
  end

  def initialize(model_class)
    @model_class = model_class
  end

  sig { params(root: Parlour::RbiGenerator::Namespace).void }
  def generate(root)
    return if !defined?(Sequel::Model) && @model_class.superclass != Sequel::Model

    attribute_module_name = "#{@model_class}::GeneratedAttributeMethods"
    attribute_module_rbi = root.create_module(attribute_module_name)

    model_class_rbi = root.create_class(@model_class.to_s)
    model_class_rbi.create_include(attribute_module_name)

    table_schema = @model_class.db.schema(@model_class.table_name)

    @model_class.columns.sort.each do |column_name|
      # => {:oid=>23, :db_type=>"integer", :default=>nil, :allow_null=>false, :primary_key=>true, :type=>:integer, :auto_increment=>true, :ruby_default=>nil}
      column_schema = table_schema.detect {|c| c[0] == column_name }[1]
      ruby_column_type = sequel_to_ruby_type(column_schema[:type])

      column_type = ColumnType.new(
        base_type: ruby_column_type,
        nilable: column_schema[:allow_null],
        array_type: false
      )

      attribute_module_rbi.create_method(
        column_name.to_s,
        return_type: column_type.to_s,
      )

      attribute_module_rbi.create_method(
        "#{column_name}=",
        parameters: [
          Parlour::RbiGenerator::Parameter.new("value", type: value_type_for_attr_writer(column_type)),
        ],
        return_type: nil,
      )
    end
  end

  sig { params(sequel_type: Symbol).returns(String) }
  def sequel_to_ruby_type(sequel_type)
    case sequel_type
    when :integer
      "Integer"
    when :string
      "String"
    when :boolean
      "T::Boolean"
    else
      raise 'unsupported type'
    end
  end

  sig { params(column_type: ColumnType).returns(String) }
  def value_type_for_attr_writer(column_type)
    assignable_time_supertypes = [Date, Time].map(&:to_s)

    type = column_type.base_type
    if type.is_a?(Class)
      # TODO this needs to handle sequel date classes
      if type == ActiveSupport::TimeWithZone
        type = "T.any(#{assignable_time_supertypes.join(', ')})"
      elsif type < Numeric
        type = "T.any(Numeric)"
      elsif type == String
        type = "T.any(String, Symbol)"
      end
    end

    ColumnType.new(
      base_type: type,
      nilable: column_type.nilable,
      array_type: column_type.array_type
    ).to_s
  end
end

# SorbetRails::ModelRbiFormatter.register_plugin(SequelSorbetPlugin)

# SorbetRails.configure do |config|
#   config.enabled_gem_plugins += [
#     :sequel_sorbet_plugin,
#   ]
# end

# SorbetRails::ModelRbiFormatter.class_eval do
#   def get_plugins
#     [SequelSorbetPlugin]
#   end
# end

generator = Parlour::RbiGenerator.new(break_params: 3)
SequelSorbetPlugin.new(StripeForce::User).generate(generator.root)
binding.pry
