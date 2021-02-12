-- 111  Setting non-standard global variable
-- 112  Mutating non-standard global variable
-- 113  Accessing an undefined global variable.

ignore = { "112/vim", "113/vim" }
files["test/**/*.lua"] = {
  ignore = { "111/test.*" }
}
