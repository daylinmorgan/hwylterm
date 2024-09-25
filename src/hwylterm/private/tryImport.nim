template tryImport*(x, msg) =
  const importable = compiles: import x
  when not importable:
    {.fatal: msg}
  else:
    import x
