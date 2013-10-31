require './spec/spec_helper'

describe ThinkingSphinx::Deltas::DatetimeDelta do
  before :each do
    @sphinx_version = (ThinkingSphinx.constants.include?(:Version) ? ThinkingSphinx::Version : '3.0.0').to_f

    if @sphinx_version < 3
      @datetime_delta = ThinkingSphinx::Deltas::DatetimeDelta.new(double('index'), {})
    else
      @datetime_delta = ThinkingSphinx::Deltas::DatetimeDelta.new(double('adapter'), {})
    end
  end

  describe '#index' do
    it "should do nothing to the model" do
      @datetime_delta.index(double('model'))
    end

    it "should do nothing to the instance, if provided" do
      @datetime_delta.index(double('model'), double('instance'))
    end

    it "should make no system calls" do
      @datetime_delta.stub :`      => true
      @datetime_delta.stub :system => true

      @datetime_delta.should_not_receive(:`)
      @datetime_delta.should_not_receive(:system)

      @datetime_delta.index(double('model'), double('instance'))
    end

    it "should return true" do
      @datetime_delta.index(double('model')).should be_true
    end
  end

  describe '#delayed_index' do
    let(:root) { File.expand_path File.dirname(__FILE__) + '/../../..' }

    before :each do
      @index = double('index',
        :delta?     => true,
        :name       => 'foo_delta',
        :core_name  => 'foo_core',
        :delta_name => 'foo_delta',
        :reference  => 'foo',
      )
      @model = double('foo',
        :name                   => 'foo',
        :source_of_sphinx_index => @model,
        :delta_index_names      => ['foo_delta'],
        :sphinx_indexes         => [@index],
      )

      #ThinkingSphinx.suppress_delta_output = false

      @datetime_delta.stub :`    => ""
      @datetime_delta.stub :puts => nil
        
      @controller = ThinkingSphinx::Configuration.instance.controller
      @controller.stub :`      => ""
      @controller.stub :system => true
    end

    it "should process the delta index for the given model" do
      if @sphinx_version < 3
        @datetime_delta.should_receive(:`).
          with("indexer --config /config/development.sphinx.conf foo_delta")

        @datetime_delta.delayed_index(@model)
      else
        @controller.stub :index => ""
        @controller.should_receive(:index).with(@index.name)
        @datetime_delta.delayed_index(@index)
      end
    end

    it "should merge the core and delta indexes for the given model" do
      @datetime_delta.should_receive(:`).with(/indexer --config \S+ --merge foo_core foo_delta --merge-dst-range sphinx_deleted 0 0/)
      if @sphinx_version < 3
        @datetime_delta.delayed_index(@model)
      else
        core_index = double('index',
          :delta? => false,
          :name   => 'foo_core',
          :reference => 'foo',
        )
        ThinkingSphinx::Configuration.instance.stub :indices => [core_index, @index]
        @datetime_delta.delayed_index(@index)
      end
    end

    it "should include --rotate if Sphinx is running" do
      if @sphinx_version < 3
        ThinkingSphinx.stub(:sphinx_running? => true)
        @datetime_delta.should_receive(:`) do |command|
          command.should match(/\s--rotate\s/)
          'output'
        end

        @datetime_delta.delayed_index(@model)
      else
        @controller.stub :running? => true
        @controller.should_receive(:`).with(/indexer.*--rotate/)

        @datetime_delta.delayed_index(@index)
      end
    end

    it "should output the details by default" do
      @datetime_delta.should_receive(:puts)

      @datetime_delta.delayed_index(@model)
    end

    it "should hide the details if suppressing delta output" do
      if @sphinx_version < 3
        ThinkingSphinx.suppress_delta_output = true
      else
        ThinkingSphinx::Configuration.instance.settings['quiet_deltas'] = true
      end
      @datetime_delta.should_not_receive(:puts)

      @datetime_delta.delayed_index(@model)
    end
  end

  describe '#toggle' do
    it "should do nothing to the instance" do
      @datetime_delta.toggle(double('instance'))
    end
  end

  describe '#toggled' do
    it "should return true if the column value is more recent than the threshold" do
      instance = double('instance', :updated_at => 20.minutes.ago)
      @datetime_delta.threshold = 30.minutes

      @datetime_delta.toggled(instance).should be_true
    end

    it "should return false if the column value is older than the threshold" do
      instance = double('instance', :updated_at => 30.minutes.ago)
      @datetime_delta.threshold = 20.minutes

      @datetime_delta.toggled(instance).should be_false
    end

    it "should return false if the column value is null" do
      instance = double('instance', :updated_at => nil)
      @datetime_delta.threshold = 20.minutes

      @datetime_delta.toggled(instance).should be_false
    end
  end

  describe '#reset_query' do
    it "should be nil" do
      @datetime_delta.reset_query(@model).should be_nil
    end
  end

  describe '#clause' do
    before :each do
      @model = double('model', :connection => double('connection'))
      @model.stub(:quoted_table_name => '`foo`')
      @model.connection.stub(:quote_column_name => '`updated_at`')

      @datetime_delta.stub(
        :adapter => double('adapter', :time_difference => 'time_difference')
      )
    end

    it "should return nil if not for the toggled results" do
      @datetime_delta.clause(@model, false).should be_nil
    end

    it "should return only records within the threshold" do
      @datetime_delta.clause(@model, true).
        should == '`foo`.`updated_at` > time_difference'
    end
  end
end
