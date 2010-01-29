require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::AttributeSet do
  before(:all) do
    module ::Blog
      class Author
        include DataMapper::Resource

        property :id,   Integer, :key => true
        property :name, String
        property :job,  String,  :default => 'Regional Manager'
      end

      class Post
        include DataMapper::Resource

        property :id,    Integer, :key => true
        property :title, String
      end
    end

    @model = Blog::Author
  end

  def attribute_set(values = {})
    DataMapper::AttributeSet.new(@model.new, values)
  end

  it 'should respond to #resource' do
    attribute_set.should respond_to(:resource)
  end

  describe '#initialize' do
    it 'should set the resource' do
      attribute_set.resource.should be_kind_of(@model)
    end

    describe 'when given no values' do
      it 'not set any values' do
        attribute_set.get(:name).should be_nil
      end

      it 'should not be dirty' do
        attribute_set.should_not be_dirty
      end
    end

    describe 'when given initial values' do
      describe 'with Symbol keys' do
        it 'should set the attribute values' do
          set = attribute_set(:name => 'Michael Scarn')
          set.get(:name).should == 'Michael Scarn'
        end

        it "should not set a value when given a property name which " \
           "isn't part of the set" do
          set = attribute_set(:__invalid__ => 'Dwigt')
          set.get!(:__invalid__).should be_nil
        end

        it 'should not mark the set as dirty' do
          set = attribute_set(:name => 'Michael Scarn')
          set.should_not be_dirty
        end
      end # with Symbol keys

      describe 'with Property keys' do
        it 'should set the attribute values' do
          set = attribute_set(Blog::Author.properties[:name] => 'Michael Scarn')
          set.get(:name).should == 'Michael Scarn'
        end

        it "should not set a value when given a Property which " \
           "isn't part of the set" do
          set = attribute_set(Blog::Post.properties[:title] => 'Bees!')
          set.get!(:title).should be_nil
        end

        it 'should not mark the set as dirty' do
          set = attribute_set(Blog::Author.properties[:name] => 'Michael Scarn')
          set.should_not be_dirty
        end
      end # with Property keys
    end # when given initial values
  end # initialize

  describe '#original' do
    before(:each) do
      @attribute_set = attribute_set
    end

    it 'should return a Hash' do
      @attribute_set.original.should be_kind_of(Hash)
    end

    describe 'when the resource is new' do
      it 'should be empty when no values have been set' do
        @attribute_set.original.should be_empty
      end

      it 'should have a key for changed values, with a nil value' do
        @attribute_set.set(:name, 'Michael Scarn')
        @attribute_set.original.should == { :name => nil }
      end

      it 'should not contain a restored value' do
        @attribute_set.set(:name, 'Michael Scarn')
        @attribute_set.set(:name, nil)
        @attribute_set.original.should be_empty
      end

      it 'should not have a key for unset default attributes' do
        @attribute_set.original.keys.should_not include(:job)
      end

      it 'should have a key for set default attributes, with a nil value' do
        @attribute_set.set(:job, 'Boss')
        @attribute_set.original.should == { :job => nil }
      end

      it 'should should retain nil as the value when several values are set' do
        @attribute_set.set(:name, 'Michael Scarn')
        @attribute_set.set(:name, 'Samuel L. Chang')
        @attribute_set.original.should == { :name => nil }
      end
    end # when the resource is new

    supported_by :all do

      describe 'when the resource is persisted' do
        before(:each) do
          @attribute_set.set(:name, 'Michael Scarn')
          @attribute_set.resource.save.should be_true
        end

        it 'should be empty' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.original.should be_empty
          end
        end

        it 'should contain the value of changed attributes' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.set(:name, 'Catherine Zeta')
            @attribute_set.original.should == { :name => 'Michael Scarn' }
          end
        end

        it 'should not contain the current value' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.set(:name, 'Michael Scarn')
            @attribute_set.original.should be_empty
          end
        end

        it 'should not contain a restored value' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.set(:name, 'Catherine Zeta')
            @attribute_set.set(:name, 'Michael Scarn')
            @attribute_set.original.should be_empty
          end
        end

        it 'should store the original value when several new values are set' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.set(:name, 'Catherine Zeta')
            @attribute_set.set(:name, 'Samuel L. Chang')
            @attribute_set.original.should == { :name => 'Michael Scarn' }
          end
        end
      end # when the resource is persisted

    end # supported_by

  end # original

  it { attribute_set.should respond_to(:dirty) }

  describe '#dirty' do
    before(:each) do
      @attribute_set = attribute_set
    end

    it 'should return a Hash' do
      @attribute_set.dirty.should be_kind_of(Hash)
    end

    describe 'when the resource is new' do
      it 'should be empty when no values have been set' do
        @attribute_set.dirty.should be_empty
      end

      it 'should contain dirty attributes' do
        @attribute_set.set(:name, 'Michael Scarn')
        @attribute_set.dirty.should == {
          @model.properties[:name] => 'Michael Scarn'
        }
      end

      it 'should not contain a restored value' do
        @attribute_set.set(:name, 'Michael Scarn')
        @attribute_set.set(:name, nil)
        @attribute_set.dirty.should be_empty
      end

      it 'should contain the default value of an attribute' do
        @attribute_set.dirty.keys.should_not include(:job)
      end

      it 'should contain the value of an attribute which has a default' do
        @attribute_set.set(:job, 'Boss')
        @attribute_set.dirty.should == { @model.properties[:job] => 'Boss' }
      end
    end # when the resource is new

    supported_by :all do

      describe 'when the resource is persisted' do
        before(:each) do
          @attribute_set.set(:name, 'Michael Scarn')
          @attribute_set.resource.save.should be_true
        end

        it 'should be empty' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.dirty.should be_empty
          end
        end

        it 'should contain the value of changed attributes' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.set(:name, 'Catherine Zeta')
            @attribute_set.dirty.should == {
              @model.properties[:name] => 'Catherine Zeta'
            }
          end
        end

        it 'should not contain the current value' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.set(:name, 'Michael Scarn')
            @attribute_set.dirty.should be_empty
          end
        end

        it 'should not contain a restored value' do
          pending 'Awaiting support for saving an AttributeSet' do
            @attribute_set.set(:name, 'Catherine Zeta')
            @attribute_set.set(:name, 'Michael Scarn')
            @attribute_set.dirty.should be_empty
          end
        end
      end # when the resource is persisted

    end # supported_by

  end # dirty

end
