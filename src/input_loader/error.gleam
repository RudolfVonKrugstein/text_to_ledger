import paperless_api/error as api_error
import simplifile

pub type InputLoaderError {
  ReadDirectoryError(path: String, error: simplifile.FileError)
  PaperlessApiError(api_error.PaperlessApiError)
}
