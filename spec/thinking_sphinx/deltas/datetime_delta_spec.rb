require 'spec/spec_helper'

describe ThinkingSphinx::Deltas::DatetimeDelta do
  before :each do
    @datetime_delta = ThinkingSphinx::Deltas::DatetimeDelta.new(
      stub('index'), {}
    )
  end
  
  describe '#index' do
    it "should do nothing to the model" do
      @datetime_delta.index(stub('model'))
    end
    
    it "should do nothing to the instance, if provided" do
      @datetime_delta.index(stub('model'), stub('instance'))
    end
    
    it "should make no system calls" do
      @datetime_delta.stub! :`      => true
      @datetime_delta.stub! :system => true
      
      @datetime_delta.should_not_receive(:`)
      @datetime_delta.should_not_receive(:system)
      
      @datetime_delta.index(stub('model'), stub('instance'))
    end
    
    it "should return true" do
      @datetime_delta.index(stub('model')).should be_true
    end
  end
  
  describe '#delayed_index' do
    let(:root) { File.expand_path File.dirname(__FILE__) + '/../../..' }
    
    before :each do
      @index = stub('index',
        :delta?     => true,
        :core_name  => 'foo_core',
        :delta_name => 'foo_delta'
      )
      @model = stub('foo',
        :name                   => 'foo',
        :source_of_sphinx_index => @model,
        :delta_index_names      => ['foo_delta'],
        :sphinx_indexes         => [@index]
      )
      
      ThinkingSphinx.suppress_delta_output = false
      
      @datetime_delta.stub! :`    => ""
      @datetime_delta.stub! :puts => nil
    end
    
    it "should process the delta index for the given model" do
      @datetime_delta.should_receive(:`).
        with("indexer --config #{root}/config/development.sphinx.conf foo_delta")
      
      @datetime_delta.delayed_index(@model)
    end
    
    it "should merge the core and delta indexes for the given model" do
      @datetime_delta.should_receive(:`).with("indexer --config #{root}/config/development.sphinx.conf --merge foo_core foo_delta --merge-dst-range sphinx_deleted 0 0")
      
      @datetime_delta.delayed_index(@model)
    end
    
    it "should include --rotate if Sphinx is running" do
      ThinkingSphinx.stub!(:sphinx_running? => true)
      @datetime_delta.should_receive(:`) do |command|
        command.should match(/\s--rotate\s/)
      end
      
      @datetime_delta.delayed_index(@model)
    end
    
    it "should output the details by default" do
      @datetime_delta.should_receive(:puts)
      
      @datetime_delta.delayed_index(@model)
    end
    
    it "should hide the details if suppressing delta output" do
      ThinkingSphinx.suppress_delta_output = true
      @datetime_delta.should_not_receive(:puts)
      
      @datetime_delta.delayed_index(@model)
    end
  end
  
  describe '#toggle' do
    it "should do nothing to the instance" do
      @datetime_delta.toggle(stub('instance'))
    end
  end
  
  describe '#toggled' do
    it "should return true if the column value is more recent than the threshold" do
      instance = stub('instance', :updated_at => 20.minutes.ago)
      @datetime_delta.threshold = 30.minutes
      
      @datetime_delta.toggled(instance).should be_true
    end
    
    it "should return false if the column value is older than the threshold" do
      instance = stub('instance', :updated_at => 30.minutes.ago)
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
      @model = stub('model', :connection => stub('connection'))
      @model.stub!(:quoted_table_name => '`foo`')
      @model.connection.stub!(:quote_column_name => '`updated_at`')
      
      @datetime_delta.stub!(
        :adapter => stub('adapter', :time_difference => 'time_difference')
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
