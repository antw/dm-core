module DataMapper
  # Takes a PropertySet and allows values to be assigned.
  #
  # An AttributeSet is used on each instance of Resource to store the values
  # associated with a particular record. AttributeSet also keeps track of
  # which attributes have been loaded, and which have been changed from their
  # original values.
  #
  class AttributeSet

    # The resource whose attributes are being stored.
    #
    # @return [Resource]
    #
    # @api semipublic
    attr_reader :resource

    # Creates a new AttributeSet instance
    #
    # @param [Resouce] resource
    #   The resource whose attributes are being stored.
    #
    # @api semipublic
    def initialize(resource, values = {})
      @resource   = resource
      @properties = resource.model.properties

      @values = values.inject(Hash.new) do |hash, (key, value)|
        if @properties.named?(property_name = name_for(key))
          hash[property_name] = value
        end

        hash
      end
    end

    # Returns the value of the +name+ attribute
    #
    # @param [Property, Symbol, PropertySet] name
    #   The property -- or the name of the property -- whose value is to be
    #   retrieved. If you supply a PropertySet, an Array containing the value
    #   of each attribute in the set will instead be returned.
    #
    # @return [Object, nil]
    #   Returns the attribute value, or nil if no such property exists in the
    #   AttributeSet.
    #
    # @raise [ArgumentError]
    #   An ArgumentError will be raised if the given property or property name
    #   is not present in the AttributeSet.
    #
    # @api public
    def get(name)
      if name.kind_of?(DataMapper::PropertySet)
        # Was given a PropertySet, so we create an Array with each property's
        # value (useful when retrieving composite keys, etc).
        return name.map { |property| get(property) }
      end

      unless property = property_for(name)
        raise ArgumentError, "The property '#{name}' does not exist " \
                             "in #{@resource.model}"
      end

      unless loaded?(property.name) or resource.new?
        load_lazy_attributes!(property)
      end

      if loaded?(property)
        @values[property.name]
      elsif property.default?
        set(property, property.default_for(resource))
      else
        set(property, nil)
      end
    end

    alias_method :[], :get

    # Sets the value of the +name+ attribute
    #
    # @param [Property, Symbol, PropertySet] name
    #   The property -- or the name of the property -- whose value is to be
    #   set.
    # @param [Object] value
    #   The value to set in the resource.
    #
    # @return [Object]
    #   +value+ after being typecasted according to this property's primitive
    #
    # @raise [ArgumentError]
    #   An ArgumentError will be raised if the given property or property name
    #   is not present in the AttributeSet.
    #
    # @api public
    def set(name, value)
      if name.kind_of?(DataMapper::PropertySet)
        # Was given a PropertySet, so we set each value it contains (useful
        # when setting composite keys, etc).
        name.each_with_index { |property, idx| set(property, value[idx]) }
        return get(name)
      end

      unless property = property_for(name)
        raise ArgumentError, "The property '#{name}' does not exist " \
                             "in #{@resource.model}"
      end

      new_value  = property.typecast(value)
      orig_value = @values[name]

      if resource.new?
        original[property] = nil
      else
        if original.key?(property)
          # If the new value is the same as the original, the user has reset
          # it; remove the key. Otherwise they've already changed the value at
          # least once; leave the original alone.
          original.delete(property) if original[property] == new_value
        elsif new_value != orig_value
          original[property] = orig_value
        end
      end

      @values[property.name] = new_value
    end

    alias_method :[]=, :set

    # Returns the value of the +name+ attribute
    #
    # @param [Property, Symbol, PropertySet] name
    #   The property -- or the name of the property -- whose value is to be
    #   retrieved. If you supply a PropertySet, an Array containing the value
    #   of each attribute in the set will instead be returned.
    #
    # @return [Object, nil]
    #   Returns the attribute value, or nil if no such property exists in the
    #   AttributeSet.
    #
    # @api private
    def get!(name)
      if name.kind_of?(DataMapper::PropertySet)
        name.each_with_index { |property, idx| get!(property, value[idx]) }
      else
        @values[name_for(name)]
      end
    end

    # Sets the value of the +name+ attribute directly
    #
    # Does not typecast or track that the attribute has changed. The
    # AttributeSet will _not_ be marked as dirty.
    #
    # @param [Property, Symbol, PropertySet] name
    #   The property -- or the name of the property -- whose value is to be
    #   set. If you supply a PropertySet, an Array containing the value of
    #   each attribute in the set will instead be returned.
    # @param [Object] value
    #   The value to set in the resource.
    #
    # @return [Object]
    #   Returns the given value.
    #
    # @api private
    def set!(name, value)
      if name.kind_of?(DataMapper::PropertySet)
        name.each_with_index { |property, idx| set!(property, value[idx]) }
      else
        @values[name] = value
      end
    end

    # Checks if the set is dirty
    #
    # The attribute set is considered to be dirty if any of the values have
    # been changed, or if the the attached resource is new and has a serial
    # property, or any properties with default values.
    #
    # @return [Boolean]
    #   True if the attribute set is dirty and may be persisted.
    #
    # @api public
    def dirty?
      not original.empty?
    end

    # Checks if the +name+ attribute is dirty
    #
    # @param [Symbol, Property] property
    #   A property to be checked, or the Symbol name of the property.
    #
    # @return [Boolean]
    #   True if the named attribute is dirty.
    #
    # @api semipublic
    def attribute_dirty?(name)
      original.key?(property_for(name))
    end

    # Marks the AttributeSet as being not dirty
    #
    # @return [nil]
    #
    # @api semipublic
    def not_dirty!
      @original_values = {}
      nil
    end

    # Hash of original values of attributes that have unsaved changes
    #
    # @return [Hash]
    #   Original values of attributes that have unsaved changes
    #
    # @api semipublic
    def original
      @original_values ||= {}
    end

    # Hash of attributes that have unsaved changed and their values
    #
    # @return [Hash]
    #   Attributes which have unsaved changed
    #
    # @api semipublic
    def dirty
      original.keys.inject({}) do |dirty, property|
        dirty[property] = @values[property.name] ; dirty
      end
    end

    # Get a Human-readable representation of this AttributeSet instance
    #
    # @return [String]
    #   Human-readable representation of this AttributeSet instance
    #
    # @api public
    def inspect
      attrs = @properties.map do |property|
        if loaded?(property)
          "#{property.name}=#{@values[property.name].inspect}"
        else
          "#{property.name}=<not loaded>"
        end
      end

      "#<#{self.class} #{attrs.join(' ')}>"
    end

    # Gets all the attributes as a Hash
    #
    # @param [Symbol] key_on
    #   Use this attribute of the Property as keys. :name uses the property
    #   name as each key, :field is useful for adapters, :property or nil use
    #   the actual Property object.
    #
    # @return [Hash]
    #   All the attributes
    #
    # @api public
    def keyed_on(key_on)
      attributes = {}

      @resource.__send__(:lazy_load,
        resource.model.properties(resource.repository.name))

      @values.each do |name, value|
        property = property_for(name)

        if property.reader_visibility == :public
          key = case key_on
            when :name  then name
            when :field then property.field
            else             property
          end

          attributes[key] = @values[name]
        end
      end

      attributes
    end

    # Check if the attribute corresponding to the property is loaded
    #
    # @param [Symbol, Property] property
    #   A property to be checked, or the Symbol name of the property.
    #
    # @return [Boolean]
    #   True if the attribute is loaded.
    #
    # @api semipublic
    def loaded?(property)
      @values.key?(name_for(property))
    end

    # Removes the loaded value for an attribute
    #
    # The next time it is requested it will be loaded from the repository
    #
    # @param [Property, Symbol, PropertySet] name
    #   The property -- or the name of the property -- whose value is to be
    #   set as clean.
    #
    # @return [nil]
    #
    # @api semipublic
    def unload_attribute(name)
      @values.delete(name_for(name))
      mark_attribute_clean(name)
    end

    # Sets that an attribute is not dirty, clearing the original value
    #
    # @param [Property, Symbol, PropertySet] name
    #   The property -- or the name of the property -- whose value is to be
    #   set as clean.
    #
    # @return [nil]
    #
    # @api private
    def mark_attribute_clean(name)
      original.delete(property_for(name))
      nil
    end

    private

    # Returns the property identified by +name+
    #
    # If +name+ is already property it will be returned.
    #
    # @param [Symbol, Property] name
    #   The name of the property to be retrieved.
    #
    # @return [Property, nil]
    #   Returns the property, or nil if it doesn't exist.
    #
    # @api private
    def property_for(name)
      name.kind_of?(Property) ? name : @properties[name]
    end

    # Returns the name for a given property.
    #
    # @param [Property, Symbol] property
    #   The property whose name is to be retrieved. If a Symbol is given, it
    #   will be returned.
    #
    # @return [Symbol, nil]
    #   Returns the property name.
    #
    # @api private
    def name_for(property)
      (prop = property_for(property)) && prop.name
    end

    def load_lazy_attributes!(with)
      resource.__send__(:lazy_load,
        @properties.in_context(with.lazy? ? [ with ] : @properties.defaults)
      )
    end

  end # AttributeSet
end # DataMapper
