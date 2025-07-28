# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 120,
  import_deps: [:ecto, :ecto_sql, :postgrex, :typed_struct]
]
