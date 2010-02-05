# TODO: move paranoid property concerns to a ParanoidModel that is mixed
# into Model when a Paranoid property is used

# TODO: update Model#respond_to? to return true if method_method missing
# would handle the message

module DataMapper
  module Model
    module Property
      Model.append_extensions self

      extend Chainable

      def self.extended(model)
        model.instance_variable_set(:@field_naming_conventions, {})
        model.instance_variable_set(:@paranoid_properties,      {})
      end

      chainable do
        def inherited(model)
          model.instance_variable_set(:@properties,               properties.dup)
          model.instance_variable_set(:@field_naming_conventions, @field_naming_conventions.dup)
          model.instance_variable_set(:@paranoid_properties,      @paranoid_properties.dup)

          super
        end
      end

      # Defines a Property on the Resource
      #
      # @param [Symbol] name
      #   the name for which to call this property
      # @param [Type] type
      #   the type to define this property ass
      # @param [Hash(Symbol => String)] options
      #   a hash of available options
      #
      # @return [Property]
      #   the created Property
      #
      # @see Property
      #
      # @api public
      def property(name, type, options = {})
        property = DataMapper::Property.new(self, name, type, options)
        properties << property

        # Add the property to the lazy_loads set for this resources repository
        # only.
        # TODO Is this right or should we add the lazy contexts to all
        # repositories?
        if property.lazy?
          context = options.fetch(:lazy, :default)
          context = :default if context == true

          Array(context).each do |context|
            properties.lazy_context(context) << self
          end
        end

        # add the property to the child classes only if the property was
        # added after the child classes' properties have been copied from
        # the parent
        descendants.each do |descendant|
          descendant.properties[name] ||= property
        end

        create_reader_for(property)
        create_writer_for(property)

        property
      end

      # Gets a list of all properties that have been defined on this Model in
      # the requested repository
      #
      # @param [Symbol, String] repository_name
      #   The name of the repository to use. Uses the default Repository
      #   if none is specified.
      #
      # @return [Array]
      #   A list of Properties defined on this Model in the given Repository
      #
      # @api public
      def properties(repository_name = nil)
        unless repository_name.nil?
          warn "Passing in +repository_name+ to Model#properties is " \
               "deprecated; the method now returns all properties " \
               "(#{caller[0]})"
        end

        @properties ||= PropertySet.new
      end

      # Gets the list of key fields for this Model in +repository_name+
      #
      # @param [String] repository_name
      #   The name of the Repository for which the key is to be reported
      #
      # @return [Array]
      #   The list of key fields for this Model in +repository_name+
      #
      # @api public
      def key(repository_name = nil)
        unless repository_name.nil?
          warn "Passing in +repository_name+ to Model#key is deprecated; " \
               "the method now returns all relevant properties (#{caller[0]})"
        end

        properties.key
      end

      # @api public
      def serial(repository_name = nil)
        unless repository_name.nil?
          warn "Passing in +repository_name+ to Model#serial is " \
               "deprecated; the method now returns all relevant " \
               "properties (#{caller[0]})"
        end

        key.detect { |property| property.serial? }
      end

      # Gets the field naming conventions for this resource in the given Repository
      #
      # @param [String, Symbol] repository_name
      #   the name of the Repository for which the field naming convention
      #   will be retrieved
      #
      # @return [#call]
      #   The naming convention for the given Repository
      #
      # @api public
      def field_naming_convention(repository_name = default_storage_name)
        @field_naming_conventions[repository_name] ||= repository(repository_name).adapter.field_naming_convention
      end

      # @api private
      def properties_with_subclasses(repository_name = nil)
        unless repository_name.nil?
          warn "Passing in +repository_name+ to " \
               "Model#properties_with_subclasses is deprecated; the method " \
               "now returns all relevant properties (#{caller[0]})"
        end

        properties = PropertySet.new

        descendants.each do |model|
          model.properties.each do |property|
            properties[property.name] ||= property
          end
        end

        properties
      end

      # @api private
      def paranoid_properties
        @paranoid_properties
      end

      # @api private
      def set_paranoid_property(name, &block)
        paranoid_properties[name] = block
      end

      # @todo Once the deprecation notice is removed, *args can become +key+.
      #
      # @api private
      def key_conditions(*args)
        key = args.pop

        warn "Passing in +repository+ to Model#key_conditions is " \
             "deprecated (#{caller[0]})" if args.any?

        self.key.zip(key.nil? ? [] : key).to_hash
      end

      private

      # defines the reader method for the property
      #
      # @api private
      def create_reader_for(property)
        name                   = property.name.to_s
        reader_visibility      = property.reader_visibility
        instance_variable_name = property.instance_variable_name
        primitive              = property.primitive

        unless resource_method_defined?(name)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            #{reader_visibility}
            def #{name}
              return #{instance_variable_name} if defined?(#{instance_variable_name})
              #{instance_variable_name} = properties[#{name.inspect}].get(self)
            end
          RUBY
        end

        boolean_reader_name = "#{name}?"

        if primitive == TrueClass && !resource_method_defined?(boolean_reader_name)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            #{reader_visibility}
            alias #{boolean_reader_name} #{name}
          RUBY
        end
      end

      # defines the setter for the property
      #
      # @api private
      def create_writer_for(property)
        name              = property.name
        writer_visibility = property.writer_visibility

        writer_name = "#{name}="

        return if resource_method_defined?(writer_name)

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{writer_visibility}
          def #{writer_name}(value)
            properties[#{name.inspect}].set(self, value)
          end
        RUBY
      end

      chainable do
        # @api public
        def method_missing(method, *args, &block)
          if property = properties[method]
            return property
          end

          super
        end
      end
    end # module Property
  end # module Model
end # module DataMapper
