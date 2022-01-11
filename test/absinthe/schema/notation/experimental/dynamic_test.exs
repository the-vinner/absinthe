defmodule Absinthe.Schema.Notation.Experimental.DynamicGenTest do
  use Absinthe.Case

  defmodule Potion.SchemaPrototype do
    use Absinthe.Schema.Prototype

    directive :auth do
      arg :role, non_null(:string), description: "Auth Role"

      on [:field, :query, :field_definition]

      expand fn
        %{auth: auth}, node ->
          # AbsinBlueprint.put_flag(node, :auth, auth)
          IO.inspect(node, label: "auth test")
          node

        _, node ->
          node
      end
    end
  end

  defmodule Potion.Schema do
    @prototype_schema Potion.SchemaPrototype
    @schema_provider Absinthe.Schema.PersistentTerm
    @pipeline_modifier []

    def __absinthe_lookup__(name) do
      __absinthe_type__(name)
    end

    @behaviour Absinthe.Schema

    @doc false
    def middleware(middleware, _field, _object) do
      middleware
    end

    @doc false
    def plugins do
      Absinthe.Plugin.defaults()
    end

    @doc false
    def context(context) do
      context
    end

    def __absinthe_pipeline_modifiers__ do
      [@schema_provider]
    end

    def __absinthe_schema_provider__ do
      @schema_provider
    end

    def __absinthe_type__({name, schema_name}) do
      @schema_provider.__absinthe_type__(schema_name, name)
    end
    def __absinthe_type__(name) do
      @schema_provider.__absinthe_type__(__MODULE__, name)
    end

    def __absinthe_directive__(name, schema_name) do
      @schema_provider.__absinthe_directive__(schema_name, name)
    end

    def __absinthe_types__() do
      @schema_provider.__absinthe_types__(__MODULE__)
    end

    def __absinthe_types__(group) do
      @schema_provider.__absinthe_types__(__MODULE__, group)
    end

    def __absinthe_directives__() do
      @schema_provider.__absinthe_directives__(__MODULE__)
    end

    def __absinthe_interface_implementors__() do
      @schema_provider.__absinthe_interface_implementors__(__MODULE__)
    end

    def __absinthe_prototype_schema__() do
      @prototype_schema
    end

    def hydrate(%Absinthe.Blueprint.Schema.FieldDefinition{identifier: :posts}, [
          %Absinthe.Blueprint.Schema.ObjectTypeDefinition{identifier: :query} | _
        ]) do
      {:resolve, &__MODULE__.health/3}
    end

    def hydrate(_node, _ancestors), do: []

    # Resolver implementation:
    def health(a, b, c) do
      {:ok, %{id: "test"}}
    end

    def persistent_term_name, do: __MODULE__
  end

  describe "Dynamic Runtime Schema" do
    test "dynamic gen" do
      prototype_schema = Potion.SchemaPrototype
      blueprint = %Absinthe.Blueprint{schema: Potion.Schema}
      attrs = [blueprint]

      schema_def = %Absinthe.Blueprint.Schema.SchemaDefinition{
        imports: [],
        module: Potion.Schema,
        __reference__: Absinthe.Schema.Notation.build_reference(__ENV__)
      }

      {:ok, definitions} =
        Absinthe.Schema.Notation.SDL.parse(
          """
          type Query {
            "A list of posts"
            posts(reverse: Boolean): [Post] @auth(role: "test")
          }
          type Post {
            id: String
            title: String!
          }
          """,
          Potion.Schema,
          Absinthe.Schema.Notation.build_reference(__ENV__),
          []
        )

      blueprint =
        attrs
        |> List.insert_at(1, schema_def)
        |> Kernel.++([{:sdl, definitions}, :close])
        |> Absinthe.Blueprint.Schema.build()

      pipeline =
        Potion.Schema
        |> Absinthe.Pipeline.for_schema(prototype_schema: prototype_schema)
        |> Absinthe.Schema.apply_modifiers(Potion.Schema)

      blueprint
      |> Absinthe.Pipeline.run(pipeline)

      """
      query posts {
        posts {
          id
        }
      }
      """
      |> Absinthe.run(Potion.Schema)
      |> IO.inspect(label: "result")
    end

    test "dynamic gen custom name" do
      prototype_schema = Potion.SchemaPrototype
      blueprint = %Absinthe.Blueprint{schema: Potion.Schema}
      attrs = [blueprint]

      schema_def = %Absinthe.Blueprint.Schema.SchemaDefinition{
        imports: [],
        module: Potion.Schema,
        __reference__: Absinthe.Schema.Notation.build_reference(__ENV__)
      }

      {:ok, definitions} =
        Absinthe.Schema.Notation.SDL.parse(
          """
          type Query {
            "A list of posts"
            posts(reverse: Boolean): [Post] @auth(role: "test")
          }
          type Post {
            id: String
            title: String!
          }
          """,
          Potion.Schema,
          Absinthe.Schema.Notation.build_reference(__ENV__),
          []
        )

      blueprint =
        attrs
        |> List.insert_at(1, schema_def)
        |> Kernel.++([{:sdl, definitions}, :close])
        |> Absinthe.Blueprint.Schema.build()


      pipeline =
        Potion.Schema
        |> Absinthe.Pipeline.for_schema(
          prototype_schema: prototype_schema,
          persistent_term_name: :testing
        )
        |> Absinthe.Schema.apply_modifiers(Potion.Schema)

      blueprint
      |> Absinthe.Pipeline.run(pipeline)

      """
      query posts {
        posts {
          id
        }
      }
      """
      |> Absinthe.run(%{schema: Potion.Schema, persistent_term_name: :testing})
      |> IO.inspect(label: "result")
    end
  end
end
