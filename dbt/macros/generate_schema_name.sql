{#
  Ghi đè hành vi mặc định của dbt (vốn ghép <default>_<custom>).
  Dùng thẳng tên schema khai báo trong +schema (STAGING / ANALYTICS).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
