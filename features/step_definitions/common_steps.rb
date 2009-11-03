Before do
  $queries_executed = []
  
  @model      = nil
  @method     = :search
  @query      = ""
  @conditions = {}
  @with       = {}
  @without    = {}
  @with_all   = {}
  @options    = {}
  @results    = nil
end

Given "Sphinx is running" do
  ThinkingSphinx::Configuration.instance.controller.should be_running
end

Given /^I am searching on (.+)$/ do |model|
  @model = model.gsub(/\s/, '_').singularize.camelize.constantize
end

When "I wait for Sphinx to catch up" do
  sleep(0.25)
end

When /^I search for (\w+)$/ do |query|
  @results = nil
  @query = query
end

When /^I search for the document id of (\w+) (\w+) in the (\w+) index$/ do |model, name, index|
  model   = model.gsub(/\s/, '_').camelize.constantize
  @id     = model.find_by_name(name).sphinx_document_id
  @index  = index
end

Then /^I should get (\d+) results?$/ do |count|
  results.length.should == count.to_i
end

Then "it should exist" do
  ThinkingSphinx::Search.search_for_id(@id, @index).should == true
end

Then "it should not exist" do
  ThinkingSphinx::Search.search_for_id(@id, @index).should == false
end

def results
  @results ||= (@model || ThinkingSphinx).send(
    @method,
    @query,
    @options.merge(
      :conditions => @conditions,
      :with       => @with,
      :without    => @without,
      :with_all   => @with_all
    )
  )
end
