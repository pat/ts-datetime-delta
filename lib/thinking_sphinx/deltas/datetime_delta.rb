# Datetime Deltas for Thinking Sphinx
#
# This documentation is aimed at those reading the code. If you're looking for
# a guide to Thinking Sphinx and/or deltas, I recommend you start with the
# Thinking Sphinx site instead - or the README for this library at the very
# least.
#
# @author Patrick Allan
# @see http://ts.freelancing-gods.com Thinking Sphinx
#
class ThinkingSphinx::Deltas::DatetimeDelta < ThinkingSphinx::Deltas::DefaultDelta
  attr_accessor :column, :threshold
  attr_reader :adapter

  def self.index
    if ThinkingSphinx.respond_to?(:context) # Thinking Sphinx v2
      ThinkingSphinx.context.indexed_models.collect { |model|
        model.constantize
      }.select { |model|
        model.define_indexes
        model.delta_indexed_by_sphinx?
      }.each do |model|
        model.sphinx_indexes.select { |index|
          index.delta? && index.delta_object.respond_to?(:delayed_index)
        }.each { |index|
          index.delta_object.delayed_index(index.model)
        }
      end
    else # Thinking Sphinx v3
      configuration = ThinkingSphinx::Configuration.instance
      configuration.preload_indices
      configuration.indices.each do |index|
        if (index.delta?)
          if (index.delta_processor.respond_to?(:delayed_index))
            index.delta_processor.delayed_index(index)
          end
        end
      end
    end
  end

  # Initialises the Delta object for the given index and settings. All handled
  # by Thinking Sphinx, so you shouldn't need to call this method yourself in
  # general day-to-day situations.
  # @param arg Depending on the version of Thinking Sphinx
  #   For TS v2: the index
  #   For TS v3: the database adapter
  def initialize(arg, options = {})
    if ThinkingSphinx.respond_to?(:context) # Thinking Sphinx v2
      @index    = arg
    else # Thinking Sphinx v3
      @adapter  = arg
    end
    @column     = options[:column]    || :updated_at
    @threshold  = options[:threshold] || 1.day
  end

  # Does absolutely nothing, beyond returning true. Thinking Sphinx expects
  # this method, though, and we don't want to use the inherited behaviour from
  # DefaultDelta.
  #
  # All the real indexing logic is done by the delayed_index method.
  #
  def index(arg, instance=nil)
    # do nothing
    true
  end

  # Processes the given delta index, and then merges the relevant
  # core and delta indexes together. By default, the output of these indexer
  # commands are printed to stdout. If you'd rather it didn't, set
  # config.settings['quiet_deltas'] to true.
  #
  # @param arg Depending on the version of Thinking Sphinx
  #   For TS v2: the ActiveRecord model to index
  #   For TS v3: the delta index to index
  # @return [Boolean] true
  #
  def delayed_index(arg)
    config = ThinkingSphinx::Configuration.instance
    if ThinkingSphinx.respond_to?(:context) # Thinking Sphinx v2
      model = arg
      rotate = ThinkingSphinx.sphinx_running? ? " --rotate" : ""
      output = `#{config.bin_path}#{config.indexer_binary_name} --config #{config.config_file}#{rotate} #{model.delta_index_names.join(' ')}`

      model.sphinx_indexes.select(&:delta?).each do |index|
        output += `#{config.bin_path}#{config.indexer_binary_name} --config #{config.config_file}#{rotate} --merge #{index.core_name} #{index.delta_name} --merge-dst-range sphinx_deleted 0 0`
      end unless ENV['DISABLE_MERGE'] == 'true'

      puts output unless ThinkingSphinx.suppress_delta_output?
    else # Thinking Sphinx v3
      delta_index = arg
      controller = config.controller
      output = controller.index(delta_index.name)
      output = "" unless output.is_a?(String) # Riddle::Controller.index may return true, false, nil or String, depending on its options[:verbose] value
      rotate = (controller.running? ? ' --rotate' : '')

      unless(ENV['DISABLE_MERGE'] == 'true')
        core_index = config.indices.select{|idx|idx.reference == delta_index.reference && idx.delta? == false}.first
        if (core_index)
          output += `#{controller.bin_path}#{controller.indexer_binary_name} --config #{config.configuration_file}#{rotate} --merge #{core_index.name} #{delta_index.name} --merge-dst-range sphinx_deleted 0 0`
        end
      end

      puts output unless config.settings['quiet_deltas']
    end

    true
  end

  # Toggles the given instance to be flagged as part of the next delta indexing.
  # For datetime deltas, this means do nothing at all.
  #
  # @param [ActiveRecord::Base] instance the instance to be toggled
  #
  def toggle(instance)
    # do nothing
  end

  # Report whether a given instance is considered toggled (part of the next
  # delta process). For datetime deltas, this is true if the delta column
  # (updated_at by default) has a value within the threshold. Otherwise, false
  # is returned.
  #
  # @param [ActiveRecord::Base] instance the instance to check
  # @return [Boolean] True if within the threshold window, otherwise false.
  #
  def toggled?(instance)
    res = instance.send(@column)
    res && (res > @threshold.ago)
  end
  alias_method :toggled, :toggled?

  # Returns the SQL query that resets the model data after a normal index. For
  # datetime deltas, nothing needs to be done, so this method returns nil.
  #
  # @return [NilClass] Always nil
  #
  def reset_query(model=nil)
    nil
  end

  # A SQL condition (as part of the WHERE clause) that limits the result set to
  # just the delta data, or all data, depending on whether the toggled argument
  # is true or not. For datetime deltas, the former value is a check on the
  # delta column being within the threshold. In the latter's case, no condition
  # is needed, so nil is returned.
  #
  # @param args Depends on version of Thinking Sphinx:
  #   For ThinkingSphinx v2 this should be: def clause(model, is_delta)
  #   For ThinkingSphinx v3 this should be: def clause(is_delta=false)
  # @param [Class]   model:    The ActiveRecord model for which the clause is for
  # @param [Boolean] is_delta: Whether the clause is for the core or delta index
  # @return [String, NilClass] The SQL condition if the is_delta is true,
  #   otherwise nil
  def clause(*args)
    model    = (args.length >= 2 ? args[0] : nil)
    is_delta = (args.length >= 2 ? args[1] : args[0]) || false

    table_name  = (model.nil? ? adapter.quoted_table_name   : model.quoted_table_name)
    column_name = (model.nil? ? adapter.quote(@column.to_s) : model.connection.quote_column_name(@column.to_s))

    if is_delta
      if adapter.class.name.downcase[/postgres/]
        "#{table_name}.#{column_name} > current_timestamp - interval '#{@threshold} seconds'"
      elsif adapter.class.name.downcase[/mysql/]
        "#{table_name}.#{column_name} > DATE_SUB(NOW(), INTERVAL #{@threshold} SECOND)"
      else
        raise 'Unknown adapter type.'
      end
    else
      nil
    end
  end
end
