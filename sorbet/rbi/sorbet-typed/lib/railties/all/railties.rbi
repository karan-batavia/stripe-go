# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi sorbet-typed
#
# If you would like to make changes to this file, great! Please upstream any changes you make here:
#
#   https://github.com/sorbet/sorbet-typed/edit/master/lib/railties/all/railties.rbi
#
# typed: strong

module Rails
  class << self
    sig { returns(Rails::Application) }
    def application; end

    sig { returns(ActiveSupport::BacktraceCleaner) }
    def backtrace_cleaner; end

    sig { returns(ActiveSupport::Cache::Store) }
    def cache; end

    sig { returns(ActiveSupport::StringInquirer) }
    def env; end

    sig { returns(Logger) }
    def logger; end

    sig { returns(Pathname) }
    def root; end

    sig { returns(String) }
    def version; end
  end
end

class Rails::Application < ::Rails::Engine
  sig { returns(Rails::Application::Configuration) }
  def config; end
end

Rails::Application::INITIAL_VARIABLES = T.let(T.unsafe(nil), T::Array[T.untyped])

class Rails::Application::NonSymbolAccessDeprecatedHash < ::ActiveSupport::HashWithIndifferentAccess
  K = type_member {{fixed: T.untyped}}
  V = type_member {{fixed: T.untyped}}
  Elem = type_member {{fixed: T.untyped}}
end

module Rails::Command::Behavior
  mixes_in_class_methods(::Rails::Command::Behavior::ClassMethods)
end

module Rails::Command::Behavior::ClassMethods; end

Rails::Command::HELP_MAPPINGS = T.let(T.unsafe(nil), T::Array[T.untyped])

class Rails::Engine < ::Rails::Railtie
  sig { params(block: T.untyped).returns(ActionDispatch::Routing::RouteSet) }
  def routes(&block); end
end

Rails::Generators::AppName::RESERVED_NAMES = T.let(T.unsafe(nil), T::Array[T.untyped])

Rails::Generators::DEFAULT_ALIASES = T.let(T.unsafe(nil), T::Hash[T.untyped, T.untyped])

Rails::Generators::DEFAULT_OPTIONS = T.let(T.unsafe(nil), T::Hash[T.untyped, T.untyped])

Rails::Generators::Database::DATABASES = T.let(T.unsafe(nil), T::Array[T.untyped])

Rails::Generators::Database::JDBC_DATABASES = T.let(T.unsafe(nil), T::Array[T.untyped])

module Rails::Generators::Migration
  mixes_in_class_methods(::Rails::Generators::Migration::ClassMethods)
end

module Rails::Generators::Migration::ClassMethods; end

module Rails::Initializable
  mixes_in_class_methods(::Rails::Initializable::ClassMethods)
end

module Rails::Initializable::ClassMethods; end

class Rails::Railtie
  sig { params(block: T.proc.bind(Rails::Railtie).void).void }
  def configure(&block); end
end

Rails::Railtie::ABSTRACT_RAILTIES = T.let(T.unsafe(nil), T::Array[T.untyped])

module Rails::VERSION; end

Rails::VERSION::MAJOR = T.let(T.unsafe(nil), Integer)

Rails::VERSION::MINOR = T.let(T.unsafe(nil), Integer)

Rails::VERSION::PRE = T.let(T.unsafe(nil), String)

Rails::VERSION::STRING = T.let(T.unsafe(nil), String)

Rails::VERSION::TINY = T.let(T.unsafe(nil), Integer)

Rails::Generators::GeneratedAttribute::INDEX_OPTIONS = T.let(T.unsafe(nil), T::Array[T.untyped])

Rails::Generators::GeneratedAttribute::UNIQ_INDEX_OPTIONS = T.let(T.unsafe(nil), T::Array[T.untyped])

Rails::Generators::ModelHelpers::IRREGULAR_MODEL_NAME_WARN_MESSAGE = T.let(T.unsafe(nil), String)

Rails::Generators::ModelHelpers::PLURAL_MODEL_NAME_WARN_MESSAGE = T.let(T.unsafe(nil), String)

SourceAnnotationExtractor = Rails::SourceAnnotationExtractor
