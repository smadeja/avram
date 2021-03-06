class Avram::BaseQueryTemplate
  macro setup(type, columns, associations, table_name, primary_key_name, *args, **named_args)
    class ::{{ type }}::BaseQuery
      private class Nothing
      end

      def_clone
      include Avram::Queryable({{ type }})
      include Avram::PrimaryKeyQueryable({{ type }})

      # If not using default 'id' primary key
      {% if primary_key_name.id != "id".id %}
        # Then point 'id' to the primary key
        def id(*args, **named_args)
          {{ primary_key_name.id }}(*args, **named_args)
        end
      {% end %}

      macro generate_criteria_method(query_class, name, type)
        def \{{ name }}
          column_name = "#{table_name}.\{{ name }}"
          \{{ type }}::Lucky::Criteria(\{{ query_class }}, \{{ type }}).new(self, column_name)
        end
      end

      def update(
          {% for column in columns %}
            {{ column[:name] }} : {{ column[:type] }} | Nothing{% if column[:nilable] %} | Nil{% end %} = Nothing.new,
          {% end %}
        ) : Int64

        _changes = {} of Symbol => String?

        {% for column in columns %}
          if {{ column[:name] }}.nil?
            _changes[:{{ column[:name] }}] = nil
          elsif {{ column[:name] }}.is_a?(Nothing)
            nil
          else
            value = {{ column[:name] }}.not_nil!.class.adapter.to_db({{ column[:name] }}).to_s
            _changes[:{{ column[:name] }}] = value
          end
        {% end %}

        database.exec(
          query.statement_for_update(_changes, return_columns: false),
          args: query.args_for_update(_changes)
        ).rows_affected
      end

      {% for column in columns %}
        def {{ column[:name] }}(value)
          {{ column[:name] }}.eq(value)
        end

        {% if column[:type].is_a?(Generic) %}
          # Checking Array type
          generate_criteria_method(BaseQuery, {{ column[:name] }}, {{ column[:type].type_vars.first }})

          macro inherited
            generate_criteria_method(\{{ @type.name }}, {{ column[:name] }}, {{ column[:type].type_vars.first }})
          end
        {% else %}
          generate_criteria_method(BaseQuery, {{ column[:name] }}, {{ column[:type] }})

          macro inherited
            generate_criteria_method(\{{ @type.name }}, {{ column[:name] }}, {{ column[:type] }})
          end
        {% end %}
      {% end %}

      {% for assoc in associations %}
        def join_{{ assoc[:assoc_name] }}
          inner_join_{{ assoc[:assoc_name] }}
        end

        {% for join_type in ["Inner", "Left", "Right", "Full"] %}
          def {{ join_type.downcase.id }}_join_{{ assoc[:assoc_name] }}
            {% if assoc[:relationship_type] == :belongs_to %}
              join(
                Avram::Join::{{ join_type.id }}.new(
                  from: table_name,
                  to: :{{ assoc[:assoc_name] }},
                  primary_key: {{ assoc[:foreign_key] }},
                  foreign_key: {{ assoc[:type] }}::PRIMARY_KEY_NAME
                )
              )
            {% elsif assoc[:relationship_type] == :has_one %}
              join(
                Avram::Join::{{ join_type.id }}.new(
                  from: table_name,
                  to: {{ assoc[:type] }}::TABLE_NAME,
                  foreign_key: :{{ assoc[:foreign_key] }},
                  primary_key: primary_key_name
                )
              )
            {% elsif assoc[:through] %}
              {{ join_type.downcase.id }}_join_{{ assoc[:through].id }}
                .__yield_where_{{ assoc[:through].id }} do |join_query|
                  join_query.{{ join_type.downcase.id }}_join_{{ assoc[:assoc_name] }}
                end
            {% else %}
              join(
                Avram::Join::{{ join_type.id }}.new(
                  from: table_name,
                  to: :{{ assoc[:assoc_name] }},
                  foreign_key: {{ assoc[:foreign_key] }},
                  primary_key: primary_key_name
                )
              )
            {% end %}
          end
        {% end %}


        def where_{{ assoc[:assoc_name] }}(assoc_query : {{ assoc[:type] }}::BaseQuery, auto_inner_join : Bool = true)
          if auto_inner_join
            join_{{ assoc[:assoc_name] }}.merge_query(assoc_query.query)
          else
            merge_query(assoc_query.query)
          end
        end

        # :nodoc:
        # Used internally for has_many through queries
        def __yield_where_{{ assoc[:assoc_name] }}
          assoc_query = yield {{ assoc[:type] }}::BaseQuery.new
          merge_query(assoc_query.query)
        end

        def {{ assoc[:assoc_name] }}
          \{% raise <<-ERROR
            The methods for querying associations have changed

              * They are now prefixed with 'where_'.
              * The query is no longer yielded. You must pass it explicitly.

            Example:

              where_{{ assoc[:assoc_name] }}({{ assoc[:type] }}Query.new.some_condition)
            ERROR
          %}
          yield # This is not used. Just there so it works with blocks.
        end
      {% end %}
    end
  end
end
