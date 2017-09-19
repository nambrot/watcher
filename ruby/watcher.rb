class Watcher
  attr_accessor :models
  def initialize(models)
    self.models = models
  end

  def foreign_keys_for(model)
    model
      .reflections
      .select {|reflection_name, reflection| reflection.macro == :belongs_to && !reflection.options[:polymorphic]}
      .map { |reflection_name, reflection| reflection.foreign_key }
  end

  def serializable_hash
    models.map do |model|
      foreign_keys =  foreign_keys_for(model)
      {
        name: model.to_s,
        table_name: model.table_name,
        columns: model.column_types.map do |column_name, column_type|
          {
            name: column_name,
            type: column_type.type,
            primary_key: column_name == model.primary_key,
            foreign_key: foreign_keys.include?(column_name)
          }
        end,
        associations: model.reflections.select do |reflection_name, reflection|
          reflection.class_name.in?(models.map(&:to_s))
        end.map do |reflection_name, reflection|
          {
            name: reflection_name,
            joins: reflection.class_name,
            foreign_table: reflection.table_name,
            foreign_key: reflection.foreign_key,
            primary_key: reflection.association_primary_key,
            type: reflection.macro,
            # plural: plurality_for(reflection),
            through: reflection.options[:through],
            # source: reflection.source_reflection.name,
            inverse_of: reflection.inverse_of.try(:name),
          }
        end
      }
    end
  end

  def plurality_for(reflection)
    case reflection.macro
    when :belongs_to, :has_one
      false
    else
      true
    end
  end
end
