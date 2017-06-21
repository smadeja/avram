class LuckyRecord::BaseQueryTemplate
  macro setup(model_type, fields, table_name)
    class BaseQuery < LuckyRecord::Query
      include LuckyRecord::Queryable({{ model_type }})

      @@table_name = {{ table_name }}
      @@schema_class = {{ model_type }}

      def field_names
        [
          {% for field in fields %}
            {{field[:name]}},
          {% end %}
        ]
      end

      {% for field in fields %}
        def {{ field[:name] }}(value)
          where(:{{ field[:name] }}, value)
        end

        def {{ field[:name] }}
          {{ field[:type] }}::Criteria(BaseQuery, {{ field[:type] }}::BaseType).new(self, :{{ field[:name] }})
        end
      {% end %}
    end
  end
end
