import data/ledger
import filepath
import gleam/option
import gleam/result
import gleam/set.{type Set}
import simplifile

pub opaque type Writer {
  Writer(
    base_dir: String,
    main_file: String,
    update_type: UpdateType,
    all_files: Set(String),
  )
}

pub type UpdateType {
  /// Create new files, expect dir to be empty
  Create
  /// Append to files
  Append
  /// Delete directory content before writing
  Overwrite
}

pub type Error {
  OutDirNotEmpty(dir: String)
  FileError(simplifile.FileError)
}

/// Create a new output writer.
///
/// Dependening on `update_type`, this will:
/// - error, if `update_type` is `Create` and the directory is not empty.
/// - do no changes to the directory, if `update_file` is `Append`.
/// - delete all conents, if `update_file` is `Overwrite`.
pub fn new(base_dir: String, main_file: String, update_type: UpdateType) {
  // create the output directory, if it does not exist
  use _ <- result.try(
    simplifile.create_directory_all(base_dir) |> result.map_error(FileError),
  )
  // current files
  use files <- result.try(
    simplifile.read_directory(base_dir) |> result.map_error(FileError),
  )

  use _ <- result.try(case update_type {
    Create -> {
      // check that directory is empty
      case simplifile.get_files(base_dir) {
        Error(e) -> Error(FileError(e))
        Ok([]) -> Ok(Nil)
        Ok(_) -> Error(OutDirNotEmpty(base_dir))
      }
    }
    Append -> Ok(Nil)
    Overwrite ->
      // remove all files
      simplifile.delete_all(files) |> result.map_error(FileError)
  })

  Ok(Writer(base_dir:, main_file:, update_type:, all_files: set.new()))
}

/// Write out a ledger entry
pub fn write(writer: Writer, entry: ledger.LedgerEntry) {
  let file = entry.file |> option.unwrap(writer.main_file)
  let full_path = filepath.join(writer.base_dir, file)

  use _ <- result.try(
    simplifile.append(full_path, ledger.to_string(entry))
    |> result.map_error(FileError),
  )

  Ok(Writer(..writer, all_files: set.insert(writer.all_files, file)))
}

fn set_try_each(set: set.Set(a), fun: fn(a) -> Result(Nil, e)) -> Result(Nil, e) {
  set.fold(set, Ok(Nil), fn(acc, member) {
    case acc {
      Ok(_) -> fun(member)
      Error(e) -> Error(e)
    }
  })
}

/// Finish the writer, which writes all includes to main
pub fn finish(writer: Writer) {
  let main_file = filepath.join(writer.base_dir, writer.main_file)

  set_try_each(writer.all_files, fn(file) {
    simplifile.append(main_file, "\ninclude " <> file <> "\n")
  })
}
