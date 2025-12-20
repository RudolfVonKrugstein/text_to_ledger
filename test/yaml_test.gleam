import filepath
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleeunit/should
import simplifile
import temporary
import yaml/yaml

pub fn load_simple_yaml_test() {
  // Create output dir
  use out_dir <- temporary.create(temporary.directory())
  // Create a simple YAML content
  let yaml_content =
    "
name: test_document
version: 1
settings:
  enabled: true
  count: 42
"

  // Write YAML to a temporary file
  let temp_file = filepath.join(out_dir, "test.yaml")
  let assert Ok(_) = simplifile.write(temp_file, yaml_content)

  // Define a decoder for our expected structure
  let decoder = {
    use name <- decode.field("name", decode.string)
    use version <- decode.field("version", decode.int)
    use settings <- decode.field(
      "settings",
      decode.dict(decode.string, decode.dynamic),
    )
    decode.success(#(name, version, settings))
  }

  // Load and parse the YAML file
  let result = yaml.parse_file(temp_file, decoder)

  // Verify the result
  should.be_ok(result)
  let assert Ok([#(name, version, settings)]) = result

  should.equal(name, "test_document")
  should.equal(version, 1)

  // Check settings dict
  let assert Ok(enabled) = dict.get(settings, "enabled")
  let assert Ok(True) = decode.run(enabled, decode.bool)

  let assert Ok(count) = dict.get(settings, "count")
  let assert Ok(42) = decode.run(count, decode.int)
}

pub fn import_yaml_test() {
  // Create output dir
  use out_dir <- temporary.create(temporary.directory())

  // Create a base YAML file to be imported
  let base_yaml_content =
    "
base_setting: base_value
shared:
  timeout: 30
  retries: 3
"

  let base_file = filepath.join(out_dir, "base.yaml")
  let assert Ok(_) = simplifile.write(base_file, base_yaml_content)

  // Create main YAML file that imports the base file
  let main_yaml_content =
    "
name: main_document
version: 2
config:
    import!: base.yaml
additional:
  debug: true
"

  let main_file = filepath.join(out_dir, "main.yaml")
  let assert Ok(_) = simplifile.write(main_file, main_yaml_content)

  // Define decoder for the expected structure
  let decoder = {
    use name <- decode.field("name", decode.string)
    use version <- decode.field("version", decode.int)
    use config <- decode.field(
      "config",
      decode.dict(decode.string, decode.dynamic),
    )
    use additional <- decode.field(
      "additional",
      decode.dict(decode.string, decode.dynamic),
    )
    decode.success(#(name, version, config, additional))
  }

  // Load and parse the main YAML file (which should import base.yaml)
  let result = yaml.parse_file(main_file, decoder)

  // Verify the result
  should.be_ok(result)
  let assert Ok([#(name, version, config, additional)]) = result

  should.equal(name, "main_document")
  should.equal(version, 2)

  // Check that imported config contains base settings
  let assert Ok(base_setting) = dict.get(config, "base_setting")
  let assert Ok("base_value") = decode.run(base_setting, decode.string)

  let assert Ok(shared) = dict.get(config, "shared")
  let assert Ok(shared_dict) =
    decode.run(shared, decode.dict(decode.string, decode.dynamic))

  let assert Ok(timeout) = dict.get(shared_dict, "timeout")
  let assert Ok(30) = decode.run(timeout, decode.int)

  let assert Ok(retries) = dict.get(shared_dict, "retries")
  let assert Ok(3) = decode.run(retries, decode.int)

  // Check additional settings from main file
  let assert Ok(debug) = dict.get(additional, "debug")
  let assert Ok(True) = decode.run(debug, decode.bool)
}

pub fn import_loop_error_test() {
  // Create output dir
  use out_dir <- temporary.create(temporary.directory())

  // Create first YAML file that imports the second
  let file1_content =
    "
name: file1
config:
    import!: file2.yaml
"

  let file1 = filepath.join(out_dir, "file1.yaml")
  let assert Ok(_) = simplifile.write(file1, file1_content)

  // Create second YAML file that imports the first (creating a loop)
  let file2_content =
    "
name: file2
settings:
    import!: file1.yaml
"

  let file2 = filepath.join(out_dir, "file2.yaml")
  let assert Ok(_) = simplifile.write(file2, file2_content)

  // Define a simple decoder
  let decoder = decode.dict(decode.string, decode.dynamic)

  // Try to parse file1, which should detect the import loop
  let result = yaml.parse_file(file1, decoder)

  // Verify that we get an ImportLoop error
  should.be_error(result)
  let assert Error(yaml.ImportLoop(files)) = result

  // The files list should contain both files in the loop, and the original file
  should.equal(list.length(files), 3)
  should.equal(files, [file1, file2, file1])
}
