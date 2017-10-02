class Watcher
  attr_accessor :models
  def initialize(models)
    self.models = models
    @association_tables = {}
  end

  def foreign_keys_for(model)
    model
      .reflections
      .select {|reflection_name, reflection| reflection.macro == :belongs_to && !reflection.options[:polymorphic]}
      .map { |reflection_name, reflection| reflection.foreign_key }
  end

  def serialized_column(column_name, column_type, model, foreign_keys)
    ret = { name: column_name, type: column_type.type }

    ret[:primary_key] = true if column_name == model.primary_key
    ret[:foreign_key] = true if foreign_keys.include?(column_name)
    ret
  end

  def seriaized_association(reflection_name, reflection)
    foreign_key_on_foreign_table =
      case
      when reflection.options[:through]
        reflection.source_reflection.macro.in? %i{has_many has_one}
      else
        reflection.macro.in? %i{has_many has_one}
      end
    return [] if reflection.options[:as]
    ret = {
      name: reflection_name,
      joins: reflection.class_name,
      foreign_table: reflection.table_name,
      foreign_key: foreign_key_on_foreign_table ? reflection.foreign_key : reflection.association_primary_key,
      primary_key: foreign_key_on_foreign_table ? reflection.association_primary_key : reflection.foreign_key,
      type: reflection.macro,
      through: reflection.options[:through],
      inverse_of: reflection.inverse_of.try(:name),
    }

    sec = nil

    if reflection.macro == :has_and_belongs_to_many
      ret[:through] = reflection.join_table
      ret[:type] = :has_many
      ret[:primary_key] = reflection.association_foreign_key
      sec = {
        name: reflection.join_table,
        joins: reflection.join_table.camelize,
        foreign_table: reflection.join_table,
        foreign_key: reflection.foreign_key,
        primary_key: reflection.association_primary_key,
        type: :has_many
      }
    end

    [ret.compact, sec].compact
  end

  def serialize_habtam_reflection(model, reflection)
    name = reflection.join_table.camelize
    @association_tables[name] = {
      name: name,
      table_name: reflection.join_table,
      columns: [
        {
          name: reflection.association_foreign_key,
          type: :integer,
          foreign_key: true
        },
        {
          name: reflection.foreign_key,
          type: :integer,
          foreign_key: true
        }
      ],
      associations: [
        {
          name: reflection.class_name.underscore,
          joins: reflection.class_name,
          foreign_table: reflection.table_name,
          foreign_key: reflection.association_primary_key,
          primary_key: reflection.association_foreign_key,
          type: :belongs_to
        },
        {
          name: model.to_s.underscore,
          joins: model.to_s,
          foreign_table: model.table_name,
          foreign_key: reflection.association_primary_key,
          primary_key: reflection.foreign_key,
          type: :belongs_to
        }
      ]
    }
  end

  def serializable_hash
    models.map do |model|
      foreign_keys =  foreign_keys_for(model)
      # find association tables
      model
        .reflections
        .select { |_, reflection| reflection.class_name.in?(models.map(&:to_s)) && reflection.macro == :has_and_belongs_to_many }
        .each { |reflection_name, reflection| serialize_habtam_reflection(model, reflection) }
      {
        name: model.to_s,
        table_name: model.table_name,
        columns:
          model
            .column_types
            .map { |column_name, column_type| serialized_column(column_name, column_type, model, foreign_keys) },
        associations:
          model
            .reflections
            .select { |_, reflection| reflection.class_name.in?(models.map(&:to_s)) }
            .flat_map { |reflection_name, reflection| seriaized_association(reflection_name, reflection) }
      }
    end + @association_tables.values
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
