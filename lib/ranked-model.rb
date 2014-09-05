require File.dirname(__FILE__)+'/ranked-model/ranker'
require File.dirname(__FILE__)+'/ranked-model/railtie' if defined?(Rails::Railtie)

module RankedModel

  # Signed MEDIUMINT in MySQL
  #
  MAX_RANK_VALUE = 8388607
  MIN_RANK_VALUE = -8388607

  def self.included base

    base.class_eval do
      class_attribute :rankers

      extend RankedModel::ClassMethods

      before_save :handle_ranking

      scope :rank, lambda { |name|
        order ranker(name.to_sym).column
      }
    end

  end

  private

  def handle_ranking
    self.class.rankers.each do |ranker|
      ranker.with(self).handle_ranking
    end
  end

  module ClassMethods

    def ranker name
      rankers.find do |ranker|
        ranker.name == name
      end
    end

  private

    def ranks *args
      self.rankers ||= []
      ranker = RankedModel::Ranker.new(*args)
      self.rankers << ranker
      attr_reader "#{ranker.name}_position"
      define_method "#{ranker.name}_position=" do |position|
        if position.present?
          send "#{ranker.column}_will_change!"
          instance_variable_set "@#{ranker.name}_position", position
        end
      end
      define_method "position" do
        @position ||= begin
          position_value = send(ranker.name)
          return nil unless position_value

          where_lower = self.class.send(ranker.scope).where("#{ranker.name} < ?", position_value)
          (id ? where_lower.where("id != ?", id) : where_lower).count
        end
      end

      public "#{ranker.name}_position", "#{ranker.name}_position=", :position
    end

  end

end
