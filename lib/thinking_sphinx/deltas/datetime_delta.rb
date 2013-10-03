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

  # Initialises the Delta object for the given index and settings. All handled
  # by Thinking Sphinx, so you shouldn't need to call this method yourself in
  # general day-to-day situations.
  #
  # TODO Update documentation
  #
  def initialize(adapter, options = {})
    @adapter    = adapter
    @column     = options.delete(:delta_column) || :updated_at
    @threshold  = options.delete(:threshold)    || 1.day
  end

  # Does absolutely nothing, beyond returning true. Thinking Sphinx expects
  # this method, though, and we don't want to use the inherited behaviour from
  # DefaultDelta.
  #
  # All the real indexing logic is done by the delayed_index method.
  #
  # @param [Class] model the ActiveRecord model to index.
  # @param [ActiveRecord::Base] instance the instance of the given model that
  #   has changed. Optional.
  # @return [Boolean] true
  # @see #delayed_index
  #
  def index(index)
    # do nothing
    true
  end

  # Processes the given delta index, and then merges the relevant
  # core and delta indexes together. By default, the output of these indexer
  # commands are printed to stdout. If you'd rather it didn't, set
  # config.settings['quiet_deltas'] to true.
  #
  # @param [Class] model the ActiveRecord model to index
  # @return [Boolean] true
  #
  def delayed_index(delta_index)
    STDERR.puts "@tjv DEBUG: delayed_index called for #{delta_index.inspect}"
    config = ThinkingSphinx::Configuration.instance
    controller = config.controller
    output = controller.index(delta_index.name)
    rotate = (controller.running? ? ' --rotate' : '')

    unless(ENV['DISABLE_MERGE'] == 'true')
      core_index = config.indices.select{|idx|idx.reference == delta_index.reference && idx.delta? == false}.first
      if (core_index)
        output += `#{controller.bin_path}#{controller.indexer_binary_name} --config #{config.configuration_file}#{rotate} --merge #{core_index.name} #{delta_index.name} --merge-dst-range sphinx_deleted 0 0`
      end
    end

    puts output unless config.settings['quiet_deltas']

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

  # Returns the SQL query that resets the model data after a normal index. For
  # datetime deltas, nothing needs to be done, so this method returns nil.
  #
  # @param [Class] model The ActiveRecord model that is requesting the query
  # @return [NilClass] Always nil
  #
  def reset_query
    nil
  end

  # TODO Update documentation
  def clause(delta_source = false)
    if (delta_source)
      if (adapter.respond_to?(:time_difference))
        "#{adapter.quoted_table_name}.#{adapter.quote @column.to_s} > #{adapter.time_difference(@threshold)}"
      else
        # Workaround - remove when adapter gets updated
        "#{adapter.quoted_table_name}.#{adapter.quote @column.to_s} > DATE_SUB(NOW(), INTERVAL #{@threshold} SECOND)"
      end
    else
      nil
    end
  end
end
