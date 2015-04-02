require "erb"
require "json"
require "pathname"
require "tempfile"
require "yaml"

module Serverkit
  module Loaders
    class BaseLoader
      YAML_EXTNAMES = [".yaml", ".yml"]

      # @param [String] path
      def initialize(path)
        @path = path
      end

      # @todo Rescue Error::ENOENT error
      # @return [Serverkit::Recipe]
      def load
        case
        when has_directory_path?
          load_from_directory
        when has_erb_path?
          load_from_erb
        else
          loaded_class.new(load_data)
        end
      end

      private

      # @return [Binding]
      def binding_for_erb
        TOPLEVEL_BINDING
      end

      # @return [String]
      def expand_erb
        ERB.new(pathname.read).result(binding_for_erb)
      end

      # @return [String]
      def expanded_erb_path_suffix
        "." + pathname.basename(".erb").to_s.split(".", 2).last
      end

      # @note Memoizing to prevent GC
      # @return [Tempfile]
      def expanded_erb_tempfile
        @expanded_erb_tempfile ||= Tempfile.new(["", expanded_erb_path_suffix]).tap do |tempfile|
          tempfile << expand_erb
          tempfile.close
          tempfile
        end
      end

      # @return [String]
      def execute
        `#{pathname}`
      end

      def has_directory_path?
        pathname.directory?
      end

      def has_erb_path?
        pathname.extname == ".erb"
      end

      def has_executable_path?
        pathname.executable?
      end

      def has_yaml_path?
        YAML_EXTNAMES.include?(pathname.extname)
      end

      # @return [Hash]
      def load_data
        case
        when has_executable_path?
          load_data_from_executable
        when has_erb_path?
          load_data_from_erb
        when has_yaml_path?
          load_data_from_yaml
        else
          load_data_from_json
        end
      end

      # @return [Serverkit::Recipe]
      def load_from_directory
        loads_from_directory.inject(loaded_class.new, :merge)
      end

      # @return [Serverkit::Recipe]
      def load_from_erb
        self.class.new(expanded_erb_tempfile.path).load
      end

      # @return [Array<Serverkit::Recipe>]
      def loads_from_directory
        Dir.glob(pathname.join("*")).sort.flat_map do |path|
          self.class.new(path).load
        end
      end

      # @return [Hash]
      def load_data_from_executable
        JSON.parse(execute)
      end

      # @return [Hash]
      def load_data_from_json
        JSON.parse(pathname.read)
      end

      # @return [Hash]
      def load_data_from_yaml
        YAML.load_file(pathname)
      end

      # @return [Pathname]
      def pathname
        @pathname ||= Pathname.new(@path)
      end
    end
  end
end