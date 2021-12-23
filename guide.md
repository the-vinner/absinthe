## Dissecting use Absinthe Schema

Absinthe.Schema first adds 2 attributes:
```Elixir
Module.register_attribute(__CALLER__.module, :pipeline_modifier,
  accumulate: true,
  persist: true
)

Module.register_attribute(__CALLER__.module, :prototype_schema, persist: true
# persist: the attribute will be persisted in the Erlang Abstract Format. Useful when interfacing with Erlang libraries.
# accumulate:  several calls to the same attribute will accumulate instead of overriding the previous one. New attributes are always added to the top of the accumulated list.
```

module now looks like: 
```Elixir
defmodule Potion.Schema do
  @pipeline_modifier []
  @prototype_schema
end
```

Absinthe.Schema then requires and calls Absinthe.Schema.Notation which does:

```Elixir
Module.register_attribute(__CALLER__.module, :absinthe_blueprint, accumulate: true)
Module.register_attribute(__CALLER__.module, :absinthe_desc, accumulate: true)
put_attr(__CALLER__.module, %Absinthe.Blueprint{schema: __CALLER__.module})
Module.put_attribute(__CALLER__.module, :absinthe_scope_stack, [:schema])
Module.put_attribute(__CALLER__.module, :absinthe_scope_stack_stash, [])

#...
Module.register_attribute(__MODULE__, :__absinthe_type_import__, accumulate: true)

# where put_attr does:
def put_attr(module, thing) do
  ref = :erlang.unique_integer()
  Module.put_attribute(module, :absinthe_blueprint, {ref, thing})
  ref
end
```


module now looks like: 
```Elixir
defmodule Potion.Schema do
  @pipeline_modifier []
  @prototype_schema
  @absinthe_blueprint [{some_unique_integer, %Absinthe.Blueprint{schema: Potion.Schema}}]
  @absinthe_desc []
  @absinthe_scope_stack [:schema]
  @absinthe_scope_stack_stash []
  @__absinthe_type_import__ []
  @before_compile Absinthe.Schema.Notation
  import Absinthe.Schema.Notation [only: :macros]
  # imports field, query, mutation... macros
end
```

Next is Notation's "before_compile" step.

Here's a breakdown:

```Elixir
module_attribute_descs =
  env.module
  |> Module.get_attribute(:absinthe_desc)
  |> Map.new()

# module_attribute_descs = %{}

attrs =
  env.module
  |> Module.get_attribute(:absinthe_blueprint)
  |> List.insert_at(0, :close)
  |> reverse_with_descs(module_attribute_descs)

# attrs = [%Absinthe.Blueprint{schema: Potion.Schema}, :close]
# not sure about this step, to verify

# imports from import_types, I assume
imports =
  (Module.get_attribute(env.module, :__absinthe_type_imports__) || [])
  |> Enum.uniq()
  |> Enum.map(fn
    module when is_atom(module) -> {module, []}
    other -> other
  end)
# imports = []

schema_def = %Schema.SchemaDefinition{
  imports: imports,
  module: env.module,
  __reference__: %{
    location: %{file: env.file, line: 0}
  }
}

blueprint =
  attrs
  |> List.insert_at(1, schema_def)
  |> Absinthe.Blueprint.Schema.build()

# %Absinthe.Blueprint{ schema_definitions: [%Abinshte.Blueprint.Schema.SchemaDefinition{}]}

# Skipping the following lines did not seem to change anything:
# ================== START ======================
[schema] = blueprint.schema_definitions
{schema, functions} = lift_functions(schema, env.module)

sdl_definitions =
  (Module.get_attribute(env.module, :__absinthe_sdl_definitions__) || [])
  |> List.flatten()
  |> Enum.map(fn definition ->
    Absinthe.Blueprint.prewalk(definition, fn
      %{module: _} = node ->
        %{node | module: env.module}

      node ->
        node
    end)
  end)

{sdl_directive_definitions, sdl_type_definitions} =
  Enum.split_with(sdl_definitions, fn
    %Absinthe.Blueprint.Schema.DirectiveDefinition{} ->
      true

    _ ->
      false
  end)

schema =
  schema
  |> Map.update!(:type_definitions, &(sdl_type_definitions ++ &1))
  |> Map.update!(:directive_definitions, &(sdl_directive_definitions ++ &1))

blueprint = %{blueprint | schema_definitions: [schema]}
# ================== END ======================
quote do
  unquote(__MODULE__).noop(@desc)

  def __absinthe_blueprint__ do
    unquote(Macro.escape(blueprint, unquote: true))
  end

  unquote_splicing(functions)
end
```
Now testing in dynamic_test.exs