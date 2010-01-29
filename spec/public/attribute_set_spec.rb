require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::AttributeSet do
  before(:all) do
    class ::Person
      include DataMapper::Resource

      property :id,   Serial, :key => true
      property :name, String
      property :job,  String, :default => 'Boss', :field => 'role'
      property :lazy, String, :lazy => true
      property :prot, String, :accessor => :protected
      property :priv, String, :accessor => :private
    end

    class ::CompositeKeyResource
      include DataMapper::Resource

      property :id_one, Integer, :key => true
      property :id_two, Integer, :key => true
    end

    @model = Person
  end

  def attribute_set(values = {})
    DataMapper::AttributeSet.new(@model.new, values)
  end

  before(:each) do
    @resource   = Person.new(:name => 'Michael Scarn')
    @attributes = @resource._attributes
  end

  # ==========================================================================

  it { @attributes.should respond_to(:get) }

  describe '#get' do
    it 'should return the attribute value' do
      @attributes.get(:name).should == 'Michael Scarn'
    end

    describe 'when the attribute is not loaded' do
      describe 'and the resource is new' do
        it 'should return nil' do
          @attributes.get(:lazy).should be_nil
        end

        it 'should return the attribute default when one exists' do
          @attributes.get(:job).should == 'Boss'
        end
      end

      supported_by :all do

        describe 'and the resource is persisted' do
          it 'should load the value from the repository' do
            @attributes.set(:lazy, 'Very much so.')
            @resource.save.should be_true

            attributes = @resource.model.get(*@resource.key)._attributes

            pending 'Awaiting lazy-loading support' do
              attributes.get(:lazy).should == 'Very much so.'
            end
          end
        end

      end

      describe 'when given a PropertySet' do
        before(:each) do
          @property_set = CompositeKeyResource.key
          @resource     = CompositeKeyResource.new(:id_one => 1, :id_two => 2)
          @attributes   = @resource._attributes
        end

        it 'should return an array' do
          @attributes.get(@property_set).should be_kind_of(Array)
        end

        it 'should contain the value of each attribute' do
          @attributes.get(@property_set).should == [1, 2]
        end
      end

    end # when the attribute is not loaded
  end # get

  it { @attributes.should respond_to(:set) }

  describe '#set' do
    it 'should set the new value' do
      @attributes.set(:name, 'Samuel L. Chang')
      @attributes.get(:name).should == 'Samuel L. Chang'
    end

    it 'should typecast given values' do
      @attributes.set(:name, 1)
      @attributes.get(:name).should == '1'
    end

    it 'should return the typecast value' do
      @attributes.set(:name, 1).should == '1'
    end

    it 'should raise an ArgumentError if the property does not exist' do
      running_this = lambda { @attributes.set(:__invalid__, 1) }
      running_this.should raise_error(ArgumentError)
    end

    it 'should raise an ArgumentError if no property is given' do
      running_this = lambda { @attributes.set(nil, 1) }
      running_this.should raise_error(ArgumentError)
    end

    describe 'when given a PropertySet' do
      before(:each) do
        @property_set = CompositeKeyResource.key
        @attributes   = CompositeKeyResource.new._attributes
      end

      it 'should return the given values' do
        @attributes.set(@property_set, [1, 2]).should == [1, 2]
      end

      it 'should set the value of each attribute' do
        @attributes.set(@property_set, [1, 2])
        @attributes.get(:id_one).should == 1
        @attributes.get(:id_two).should == 2
      end
    end
  end # set

  it { @attributes.should respond_to(:dirty?) }

  describe '#dirty?' do
    describe 'when the resource is new' do
      it 'should be false when no attributes have been set' do
        @attributes.should_not be_dirty
      end

      it 'should be true when an attribute has been set' do
        @attributes.set(:name, 'Michael Scarn')
        @attributes.should be_dirty
      end
    end # when the resource is new

    supported_by :all do

      describe 'when the resource is persisted' do
        describe 'after setting an attribute value' do
          it 'should be true when an attribute has been changed' do
            person = Person.create(:name => 'Michael Scarn')
            person._attributes.set(:name, 'Samuel L. Chang')
            person._attributes.should be_dirty
          end

          it 'should be false if the new attribute value is the same as ' \
             'the old one' do
            person = Person.create(:name => 'Michael Scarn')
            person._attributes.set(:name, 'Michael Scarn')
            person._attributes.should_not be_dirty
          end

          it 'should be false if restoring the original value' do
            person = Person.create(:name => 'Michael Scarn')
            person._attributes.set(:name, 'Samuel L. Chang')
            person._attributes.set(:name, 'Michael Scarn')
            person._attributes.should_not be_dirty
          end

          it 'should be true when setting several new values' do
            person = Person.create(:name => 'Michael Scarn')
            person._attributes.set(:name, 'Samuel L. Chang')
            person._attributes.set(:name, 'Catherine Zeta')
            person._attributes.should be_dirty
          end
        end # after setting an attribute value

        describe 'when no attributes have been changed' do
          it 'should be false when the resource has a serial property' do
            resource = Person.create(:name => 'Michael Scarn')
            resource._attributes.should_not be_dirty
          end
        end # when no attributes have been changed
      end # when the resource is persisted


      describe '#keyed_on' do
        before(:each) do
          @attributes.set(:job, 'Boss')
        end

        describe 'with :name as the argument' do
          it 'should return a hash' do
            @attributes.keyed_on(:name).should be_kind_of(Hash)
          end

          it 'should return a hash with property names as the key' do
            @attributes.keyed_on(:name).should have_key(:job)
            @attributes.keyed_on(:name).should_not have_key(:role)
          end
        end

        describe 'with :field as the argument' do
          it 'should return a hash' do
            @attributes.keyed_on(:field).should be_kind_of(Hash)
          end

          it 'should return a hash with property field as the key' do
            @attributes.keyed_on(:field).should have_key('role')
            @attributes.keyed_on(:field).should_not have_key('job')
          end
        end

        describe 'with :property as the argument' do
          it 'should return a hash' do
            @attributes.keyed_on(:property).should be_kind_of(Hash)
          end

          it 'should return a hash with property instances as the key' do
            @attributes.keyed_on(:property).keys.each do |key|
              key.should be_kind_of(DataMapper::Property)
            end
          end
        end

        describe 'with nil as the argument' do
          it 'should return a hash' do
            @attributes.keyed_on(nil).should be_kind_of(Hash)
          end

          it 'should return a hash with property instances as the key' do
            @attributes.keyed_on(nil).keys.each do |key|
              key.should be_kind_of(DataMapper::Property)
            end
          end
        end

        it 'should include unloaded lazy attributes' do
          pending 'Awaiting lazy-loading support'
        end

        it 'should not include private attributes' do
          @attributes.set(:priv, 'Private')
          @attributes.keyed_on(:name).keys.should_not include(:priv)
        end

        it 'should not include protected attributes' do
          @attributes.set(:prot, 'Protected')
          @attributes.keyed_on(:name).keys.should_not include(:prot)
        end
      end

    end

  end # supported_by :all

  it { @attributes.should respond_to(:not_dirty!) }

  describe '#not_dirty!' do
    it 'should mark the AttributeSet as not being dirty' do
      set = attribute_set
      set.set(:name, 'Michael Scarn')
      lambda { set.not_dirty! }.should change(set, :dirty?).to(false)
    end
  end

  describe 'when triggering lazy loading' do
    it 'should not overwrite dirty attribute'
    it 'should not overwrite dirty lazy attribute'
    it 'should not overwrite dirty key'
  end


end
