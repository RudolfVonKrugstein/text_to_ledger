//// Open an external text editor (`$EDITOR`, fallback `vi`) on a file path
//// and wait for it to exit. Used by the interactive `test-rules` command to
//// let the user write extra rules.

import dot_env/env

/// Open the user's editor on `file` and wait for it to exit.
///
/// The editor command is looked up in `$EDITOR` (falling back to `vi`).
pub fn edit(file: String) -> Result(Nil, String) {
  let editor_cmd = case env.get_string("EDITOR") {
    Ok("") -> "vi"
    Ok(e) -> e
    Error(_) -> "vi"
  }
  run_editor(editor_cmd, file)
}

@external(erlang, "editor_ffi", "run_editor")
fn run_editor(editor: String, file: String) -> Result(Nil, String)
